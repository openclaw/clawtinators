output "bucket_name" {
  value = aws_s3_bucket.image_bucket.bucket
}

output "aws_region" {
  value = var.aws_region
}

output "ci_user_name" {
  value       = aws_iam_user.ci_user.name
  description = "IAM user expected to be wired in CI."
}

output "access_key_id" {
  value       = aws_iam_access_key.ci_user.id
  sensitive   = true
  description = "Use in CI as AWS_ACCESS_KEY_ID."
}

output "secret_access_key" {
  value       = aws_iam_access_key.ci_user.secret
  sensitive   = true
  description = "Use in CI as AWS_SECRET_ACCESS_KEY."
}

output "instance_ids" {
  value       = { for name, inst in aws_instance.clawdinator : name => inst.id }
  description = "CLAWDINATOR instance IDs by name."
}

output "instance_public_ips" {
  value       = { for name, inst in aws_instance.clawdinator : name => inst.public_ip }
  description = "CLAWDINATOR public IPs by name."
}

output "instance_public_dns" {
  value       = { for name, inst in aws_instance.clawdinator : name => inst.public_dns }
  description = "CLAWDINATOR public DNS by name."
}

output "efs_file_system_id" {
  value       = aws_efs_file_system.memory.id
  description = "EFS file system ID for shared memory."
}

output "efs_security_group_id" {
  value       = aws_security_group.efs.id
  description = "Security group ID for EFS."
}

output "control_api_url" {
  value       = var.control_api_enabled ? aws_lambda_function_url.control[0].function_url : null
  description = "Control-plane API Lambda URL."
}
