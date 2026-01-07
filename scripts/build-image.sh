#!/usr/bin/env bash
set -euo pipefail

config_path="${CONFIG_PATH:-nix/hosts/clawdinator-1-image.nix}"
out_dir="${OUT_DIR:-dist}"
format="${IMAGE_FORMAT:-amazon}"

if [ -e "${out_dir}" ]; then
  rm -rf "${out_dir}"
fi

nix run github:nix-community/nixos-generators -- -f "${format}" -c "${config_path}" -o "${out_dir}"

image_file="$(find "${out_dir}" -maxdepth 2 -type f \( -name "*.img" -o -name "*.vhd" -o -name "*.raw" -o -name "*.vmdk" \) | head -n 1)"
if [ -z "${image_file}" ]; then
  echo "No image found in ${out_dir} for format ${format}" >&2
  exit 1
fi

ext="${image_file##*.}"
ext="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
case "${ext}" in
  img|raw)
    aws_format="raw"
    ;;
  vhd)
    aws_format="vhd"
    ;;
  vmdk)
    aws_format="vmdk"
    ;;
  *)
    echo "Unsupported image extension: ${ext}" >&2
    exit 1
    ;;
esac

image_target="${out_dir}/nixos.${ext}"
cp -f "${image_file}" "${image_target}"
printf '%s' "${image_target}" > "${out_dir}/image-path"
printf '%s' "${aws_format}" > "${out_dir}/image-format"
