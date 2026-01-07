#!/usr/bin/env bash
set -euo pipefail

out_dir="${OUT_DIR:-dist}"
image_path="${out_dir}/nixos.img"

if [ ! -f "${image_path}" ]; then
  echo "Expected image at ${image_path}" >&2
  exit 1
fi

bucket="${S3_BUCKET:?S3_BUCKET required}"
region="${AWS_REGION:?AWS_REGION required}"
prefix="${S3_PREFIX:-}"

timestamp="$(date -u +%Y%m%d%H%M%S)"
key_prefix="${prefix%/}"
if [ -n "${key_prefix}" ]; then
  key_prefix="${key_prefix}/"
fi
key="${key_prefix}clawdinator-nixos-${timestamp}.img"

aws s3 cp "${image_path}" "s3://${bucket}/${key}" \
  --region "${region}" \
  --only-show-errors

echo "${key}"
