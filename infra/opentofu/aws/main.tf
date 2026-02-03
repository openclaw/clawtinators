terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = merge(var.tags, { "app" = "clawdinator" })
  instances = jsondecode(file("${path.module}/../../../nix/instances.json"))
  instance_enabled = var.ami_id != "" && length(local.instances) > 0
}

resource "aws_s3_bucket" "image_bucket" {
  bucket = var.bucket_name
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "image_bucket" {
  bucket                  = aws_s3_bucket.image_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.terraform_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  tags         = local.tags

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_iam_policy_document" "vmimport_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vmie.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vmimport" {
  name               = "vmimport"
  assume_role_policy = data.aws_iam_policy_document.vmimport_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "vmimport" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.image_bucket.arn,
      "${aws_s3_bucket.image_bucket.arn}/*"
    ]
  }

  statement {
    actions = [
      "ec2:ModifySnapshotAttribute",
      "ec2:CopySnapshot",
      "ec2:RegisterImage",
      "ec2:Describe*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "vmimport" {
  name   = "clawdinator-vmimport"
  role   = aws_iam_role.vmimport.id
  policy = data.aws_iam_policy_document.vmimport.json
}

resource "aws_iam_user" "ci_user" {
  name = var.ci_user_name
  tags = local.tags
}

resource "aws_iam_access_key" "ci_user" {
  user = aws_iam_user.ci_user.name
}

data "aws_iam_policy_document" "ami_importer" {
  statement {
    sid = "ListBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.image_bucket.arn]
  }

  statement {
    sid = "ObjectReadWrite"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.image_bucket.arn}/*"]
  }

  statement {
    sid = "ImportImage"
    actions = [
      "ec2:ImportImage",
      "ec2:ImportSnapshot",
      "ec2:DescribeImportSnapshotTasks",
      "ec2:DescribeImportImageTasks",
      "ec2:DescribeImages",
      "ec2:DescribeSnapshots",
      "ec2:RegisterImage",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }

  statement {
    sid = "PassVmImportRole"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.vmimport.arn]
  }
}

resource "aws_iam_user_policy" "ami_importer" {
  name   = "clawdinator-ami-importer"
  user   = aws_iam_user.ci_user.name
  policy = data.aws_iam_policy_document.ami_importer.json
}

data "aws_iam_policy_document" "instance_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "clawdinator-instance"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "instance_bootstrap" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectAttributes"
    ]
    resources = [
      "${aws_s3_bucket.image_bucket.arn}/bootstrap/*",
      "${aws_s3_bucket.image_bucket.arn}/age-secrets/*"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      "${aws_s3_bucket.image_bucket.arn}/bootstrap/*"
    ]
  }

  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.image_bucket.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["bootstrap/*", "age-secrets/*"]
    }
  }
}

resource "aws_iam_role_policy" "instance_bootstrap" {
  name   = "clawdinator-bootstrap"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance_bootstrap.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "clawdinator-instance"
  role = aws_iam_role.instance.name
  tags = local.tags
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_key_pair" "operator" {
  count      = local.instance_enabled ? 1 : 0
  key_name   = "clawdinator-operator"
  public_key = var.ssh_public_key
  tags       = local.tags
}

resource "aws_security_group" "clawdinator" {
  count       = local.instance_enabled ? 1 : 0
  name        = "clawdinator"
  description = "CLAWDINATOR access"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.tags
}

resource "aws_security_group" "efs" {
  name        = "clawdinator-efs"
  description = "CLAWDINATOR EFS access"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.tags
}

resource "aws_security_group_rule" "ssh_ingress" {
  count             = local.instance_enabled ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.clawdinator[0].id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
}

resource "aws_security_group_rule" "egress" {
  count             = local.instance_enabled ? 1 : 0
  type              = "egress"
  security_group_id = aws_security_group.clawdinator[0].id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "efs_ingress_nfs" {
  count                    = local.instance_enabled ? 1 : 0
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clawdinator[0].id
}

resource "aws_security_group_rule" "efs_egress" {
  type              = "egress"
  security_group_id = aws_security_group.efs.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_efs_file_system" "memory" {
  encrypted = false
  tags      = local.tags
}

resource "aws_efs_mount_target" "memory" {
  for_each       = toset(data.aws_subnets.default.ids)
  file_system_id = aws_efs_file_system.memory.id
  subnet_id      = each.key
  security_groups = [
    aws_security_group.efs.id
  ]
}

resource "aws_instance" "clawdinator" {
  for_each                    = local.instance_enabled ? local.instances : {}
  ami                         = var.ami_id
  instance_type               = each.value.instanceType
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [aws_security_group.clawdinator[0].id]
  key_name                    = aws_key_pair.operator[0].key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user-data.sh.tmpl", {
    instance_name    = each.value.host
    bootstrap_prefix = each.value.bootstrapPrefix
    flake_host       = each.value.host
    control_api_url  = var.control_api_enabled ? aws_lambda_function_url.control[0].function_url : ""
  })

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  tags = merge(local.tags, {
    Name = each.value.host
  })
}

data "archive_file" "control_lambda" {
  count       = var.control_api_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../../control/api"
  output_path = "${path.module}/.terraform/control-api.zip"
}

data "aws_iam_policy_document" "control_lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "control_lambda" {
  count              = var.control_api_enabled ? 1 : 0
  name               = var.control_api_name
  assume_role_policy = data.aws_iam_policy_document.control_lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "control_lambda_basic" {
  count      = var.control_api_enabled ? 1 : 0
  role       = aws_iam_role.control_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "control_lambda_ec2" {
  count  = var.control_api_enabled ? 1 : 0
  name   = "clawdinator-control-ec2"
  role   = aws_iam_role.control_lambda[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "control" {
  count            = var.control_api_enabled ? 1 : 0
  function_name    = var.control_api_name
  role             = aws_iam_role.control_lambda[0].arn
  runtime          = "nodejs20.x"
  handler          = "handler.handler"
  filename         = data.archive_file.control_lambda[0].output_path
  source_code_hash = data.archive_file.control_lambda[0].output_base64sha256
  timeout          = 10
  memory_size      = 256
  tags             = local.tags

  environment {
    variables = {
      CONTROL_API_TOKEN = var.control_api_token
      GITHUB_TOKEN      = var.github_token
      GITHUB_REPO       = var.github_repo
      GITHUB_WORKFLOW   = var.github_workflow
      GITHUB_REF        = var.github_ref
    }
  }
}

resource "aws_lambda_function_url" "control" {
  count              = var.control_api_enabled ? 1 : 0
  function_name      = aws_lambda_function.control[0].function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "control_url" {
  count                   = var.control_api_enabled ? 1 : 0
  statement_id            = "AllowFunctionUrl"
  action                  = "lambda:InvokeFunctionUrl"
  function_name           = aws_lambda_function.control[0].function_name
  principal               = "*"
  function_url_auth_type  = "NONE"
}

resource "aws_iam_user" "control_invoker" {
  count = var.control_api_enabled ? 1 : 0
  name  = var.control_invoker_user_name
  tags  = local.tags
}

resource "aws_iam_access_key" "control_invoker" {
  count = var.control_api_enabled ? 1 : 0
  user  = aws_iam_user.control_invoker[0].name
}

data "aws_iam_policy_document" "control_invoker" {
  count = var.control_api_enabled ? 1 : 0
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.control[0].arn]
  }

  statement {
    actions = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "control_invoker" {
  count  = var.control_api_enabled ? 1 : 0
  name   = "clawdinator-control-invoke"
  user   = aws_iam_user.control_invoker[0].name
  policy = data.aws_iam_policy_document.control_invoker[0].json
}
