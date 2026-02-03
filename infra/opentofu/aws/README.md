# OpenTofu (AWS Infra)

Goal: manage the CLAWDINATOR fleet infrastructure (S3 image bucket, VM import role, EFS, EC2 instances, and control-plane Lambda).

## Prereqs
- AWS credentials with permissions to manage IAM (use your homelab-admin key locally).
- Fleet registry: `nix/instances.json` (authoritative instance list).

## Usage

```sh
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=eu-central-1
export TF_VAR_aws_region=eu-central-1
export TF_VAR_ami_id=ami-...   # leave empty to skip instance creation
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"   # required when ami_id is set
```

### Remote state (S3 + Dynamo)

```sh
tofu init \
  -backend-config="bucket=clawdinator-images-eu1-20260107165216" \
  -backend-config="key=state/clawdinators.tfstate" \
  -backend-config="region=eu-central-1" \
  -backend-config="dynamodb_table=clawdinator-terraform-locks"
```

### Apply

```sh
tofu apply
```

## Control-plane API (optional)
Enable only when tokens are available:

```sh
export TF_VAR_control_api_enabled=true
export TF_VAR_control_api_token=...
export TF_VAR_github_token=...
```

## Outputs
- `bucket_name`
- `aws_region`
- `ci_user_name`
- `access_key_id`
- `secret_access_key`
- `instance_ids`
- `instance_public_ips`
- `instance_public_dns`
- `efs_file_system_id`
- `efs_security_group_id`
- `control_api_url`

## CI wiring
- Set GitHub Actions secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `S3_BUCKET`
  - `CLAWDINATOR_SSH_PUBLIC_KEY`
  - `CONTROL_API_TOKEN`
  - `GITHUB_WORKFLOW_TOKEN`

## Runtime bootstrap
- Instances get an IAM role with read access to `s3://${S3_BUCKET}/bootstrap/*` for secrets + repo seeds.
