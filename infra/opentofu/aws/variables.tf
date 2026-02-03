variable "aws_region" {
  description = "AWS region for the image bucket."
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for image uploads."
  type        = string
  default     = "clawdinator-images-eu1-20260107165216"
}

variable "ci_user_name" {
  description = "IAM user used by CI."
  type        = string
  default     = "clawdinator-image-uploader"
}

variable "tags" {
  description = "Tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for CLAWDINATOR instances."
  type        = string
  default     = ""
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 40
}

variable "ssh_public_key" {
  description = "SSH public key for the CLAWDINATOR operator."
  type        = string
  default     = ""
  validation {
    condition     = var.ami_id == "" || length(var.ssh_public_key) > 0
    error_message = "ssh_public_key is required when ami_id is set."
  }
}

variable "allowed_cidrs" {
  description = "CIDR ranges allowed to SSH and the gateway."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "terraform_lock_table_name" {
  description = "DynamoDB table name for OpenTofu state locking."
  type        = string
  default     = "clawdinator-terraform-locks"
}

variable "control_api_enabled" {
  description = "Enable the control-plane API Lambda."
  type        = bool
  default     = false
}

variable "control_api_name" {
  description = "Name for the control-plane API Lambda."
  type        = string
  default     = "clawdinator-control-api"
}

variable "control_api_token" {
  description = "Bearer token required by the control-plane API."
  type        = string
  sensitive   = true
  default     = ""
  validation {
    condition     = !var.control_api_enabled || length(var.control_api_token) > 0
    error_message = "control_api_token is required when control_api_enabled is true."
  }
}

variable "github_token" {
  description = "GitHub token with workflow dispatch permissions."
  type        = string
  sensitive   = true
  default     = ""
  validation {
    condition     = !var.control_api_enabled || length(var.github_token) > 0
    error_message = "github_token is required when control_api_enabled is true."
  }
}

variable "github_repo" {
  description = "GitHub repo for workflow dispatch (owner/name)."
  type        = string
  default     = "openclaw/clawdinators"
}

variable "github_workflow" {
  description = "Workflow file name for fleet deploy."
  type        = string
  default     = "fleet-deploy.yml"
}

variable "github_ref" {
  description = "Git ref to deploy from."
  type        = string
  default     = "main"
}
