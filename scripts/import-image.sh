#!/usr/bin/env bash
set -euo pipefail

bucket="${S3_BUCKET:?S3_BUCKET required}"
key="${S3_KEY:?S3_KEY required}"
region="${AWS_REGION:?AWS_REGION required}"

role_name="${VMIMPORT_ROLE:-vmimport}"
boot_mode="${AMI_BOOT_MODE:-uefi}"
arch="${AMI_ARCH:-x86_64}"

timestamp="$(date -u +%Y%m%d%H%M%S)"
ami_name="${AMI_NAME:-clawdinator-nixos-${timestamp}}"
ami_description="${AMI_DESCRIPTION:-clawdinator-nixos}"

task_id="$(
  aws ec2 import-image \
    --region "${region}" \
    --description "${ami_description}" \
    --boot-mode "${boot_mode}" \
    --architecture "${arch}" \
    --role-name "${role_name}" \
    --disk-containers "Format=raw,UserBucket={S3Bucket=${bucket},S3Key=${key}}" \
    --query 'ImportTaskId' \
    --output text
)"

if [ -z "${task_id}" ] || [ "${task_id}" = "None" ]; then
  echo "Failed to start import-image task." >&2
  exit 1
fi

for _ in {1..120}; do
  status="$(aws ec2 describe-import-image-tasks \
    --region "${region}" \
    --import-task-ids "${task_id}" \
    --query 'ImportImageTasks[0].Status' \
    --output text)"

  case "${status}" in
    completed)
      image_id="$(aws ec2 describe-import-image-tasks \
        --region "${region}" \
        --import-task-ids "${task_id}" \
        --query 'ImportImageTasks[0].ImageId' \
        --output text)"
      if [ -n "${image_id}" ] && [ "${image_id}" != "None" ]; then
        aws ec2 create-tags \
          --region "${region}" \
          --resources "${image_id}" \
          --tags "Key=Name,Value=${ami_name}" "Key=clawdinator,Value=true"
        echo "${image_id}"
        exit 0
      fi
      echo "Import completed but ImageId is missing." >&2
      exit 1
      ;;
    deleted|deleting|error)
      message="$(aws ec2 describe-import-image-tasks \
        --region "${region}" \
        --import-task-ids "${task_id}" \
        --query 'ImportImageTasks[0].StatusMessage' \
        --output text)"
      echo "Import failed: ${status} - ${message}" >&2
      exit 1
      ;;
    *)
      sleep 30
      ;;
  esac
done

echo "Timed out waiting for AMI import to complete (task ${task_id})." >&2
exit 1
