provider "aws" {
  region = var.aws_region
}

locals {
  suffix = var.bucket_suffix != "" ? var.bucket_suffix : random_id.bucket_suffix.hex
  name   = "${var.bucket_name}-${local.suffix}"
  tags   = merge(var.tags, { "app" = "clawdinator" })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "image_bucket" {
  bucket = local.name
  tags   = local.tags
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

resource "aws_iam_user" "ami_importer" {
  name = "clawdinator-ami-importer"
  tags = local.tags
}

resource "aws_iam_access_key" "ami_importer" {
  user = aws_iam_user.ami_importer.name
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
      "ec2:DescribeImportImageTasks",
      "ec2:DescribeImages",
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
  user   = aws_iam_user.ami_importer.name
  policy = data.aws_iam_policy_document.ami_importer.json
}
