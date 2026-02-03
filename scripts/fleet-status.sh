#!/usr/bin/env bash
set -euo pipefail

region="${AWS_REGION:?AWS_REGION required}"

instances_json="$(aws ec2 describe-instances \
  --region "${region}" \
  --filters "Name=tag:app,Values=clawdinator" \
  --query 'Reservations[].Instances[]' \
  --output json)"

if [ "${instances_json}" = "[]" ]; then
  echo "No CLAWDINATOR instances found."
  exit 0
fi

echo "CLAWDINATOR Fleet"
echo "Name | InstanceId | State | AMI | Public IP"

echo "${instances_json}" | jq -r '.[] | {
  name: (.Tags[]? | select(.Key=="Name").Value) // "unknown",
  id: .InstanceId,
  state: .State.Name,
  ami: .ImageId,
  ip: (.PublicIpAddress // "n/a")
} | "\(.name) | \(.id) | \(.state) | \(.ami) | \(.ip)"'
