#!/usr/bin/env bash
set -euo pipefail

out_dir="${OUT_DIR:-dist}"
image_path="${out_dir}/nixos.img"
if [ -f "${out_dir}/image-path" ]; then
  image_path="$(cat "${out_dir}/image-path")"
fi

if [ ! -f "${image_path}" ]; then
  echo "Expected image at ${image_path}" >&2
  exit 1
fi

bucket="${S3_BUCKET:?S3_BUCKET required}"
region="${AWS_REGION:?AWS_REGION required}"

timestamp="$(date -u +%Y%m%d%H%M%S)"
ext="${image_path##*.}"
ext="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
key="clawdinator-nixos-${timestamp}.${ext}"

aws s3 cp "${image_path}" "s3://${bucket}/${key}" \
  --region "${region}" \
  --only-show-errors

echo "${key}"
