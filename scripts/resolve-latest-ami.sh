#!/usr/bin/env bash
set -euo pipefail

region="${AWS_REGION:?AWS_REGION required}"

ami_id="$(aws ec2 describe-images \
  --region "${region}" \
  --owners self \
  --filters "Name=tag:clawdinator,Values=true" \
  --query 'Images | sort_by(@,&CreationDate)[-1].ImageId' \
  --output text)"

if [ -z "${ami_id}" ] || [ "${ami_id}" = "None" ]; then
  echo "No AMI found with tag clawdinator=true" >&2
  exit 1
fi

echo "${ami_id}"
