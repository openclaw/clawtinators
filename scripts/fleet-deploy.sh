#!/usr/bin/env bash
set -euo pipefail

target="${TARGET:?TARGET required}"
ami_id="${AMI_ID:?AMI_ID required}"
aws_region="${AWS_REGION:?AWS_REGION required}"
ssh_public_key="${SSH_PUBLIC_KEY:?SSH_PUBLIC_KEY required}"

backend_bucket="${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET required}"
backend_key="${TF_BACKEND_KEY:?TF_BACKEND_KEY required}"
backend_region="${TF_BACKEND_REGION:-${aws_region}}"
backend_table="${TF_BACKEND_DYNAMO_TABLE:?TF_BACKEND_DYNAMO_TABLE required}"

cd infra/opentofu/aws

tofu init \
  -backend-config="bucket=${backend_bucket}" \
  -backend-config="key=${backend_key}" \
  -backend-config="region=${backend_region}" \
  -backend-config="dynamodb_table=${backend_table}"

export TF_VAR_aws_region="${aws_region}"
export TF_VAR_ami_id="${ami_id}"
export TF_VAR_ssh_public_key="${ssh_public_key}"

if [ "${target}" = "all" ]; then
  tofu apply -auto-approve
else
  tofu apply -auto-approve -replace "aws_instance.clawdinator[\"${target}\"]"
fi
