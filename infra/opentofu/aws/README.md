# OpenTofu (AWS S3 Image Bucket)

Goal: create a private S3 bucket for CLAWDINATOR images, a scoped IAM user for CI, and the VM Import role.

Prereqs:
- AWS credentials with permissions to create S3 + IAM (use your homelab-admin key locally).

Usage:
- export AWS_ACCESS_KEY_ID=...
- export AWS_SECRET_ACCESS_KEY=...
- export AWS_REGION=us-east-1
- tofu init
- tofu apply

Outputs:
- `bucket_name`
- `aws_region`
- `access_key_id`
- `secret_access_key`
- `vmimport_role`

CI wiring:
- Set GitHub Actions secrets:
  - `AWS_ACCESS_KEY_ID` = output `access_key_id`
  - `AWS_SECRET_ACCESS_KEY` = output `secret_access_key`
  - `AWS_REGION` = output `aws_region`
  - `S3_BUCKET` = output `bucket_name`
  - `VMIMPORT_ROLE` = output `vmimport_role`
