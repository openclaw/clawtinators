#!/usr/bin/env bash
set -euo pipefail

out_dir="${OUT_DIR:-dist}"
format="${IMAGE_FORMAT:-raw}"
flake_ref=".#clawdinator-1-image"

if [ -e "${out_dir}" ]; then
  rm -rf "${out_dir}"
fi

if [ -f nix/keys/clawdinator.agekey ]; then
  export CLAWDINATOR_AGE_KEY
  CLAWDINATOR_AGE_KEY="$(cat nix/keys/clawdinator.agekey)"
else
  echo "Missing nix/keys/clawdinator.agekey" >&2
  exit 1
fi

if [ -z "${CLAWDINATOR_SECRETS_DIR:-}" ]; then
  if [ -d nix/age-secrets ]; then
    export CLAWDINATOR_SECRETS_DIR
    CLAWDINATOR_SECRETS_DIR="$(pwd)/nix/age-secrets"
  else
    echo "Missing nix/age-secrets; set CLAWDINATOR_SECRETS_DIR" >&2
    exit 1
  fi
fi

if [ -z "${CLAWDINATOR_REPO_SEEDS_DIR:-}" ]; then
  if [ -d repo-seeds ]; then
    export CLAWDINATOR_REPO_SEEDS_DIR
    CLAWDINATOR_REPO_SEEDS_DIR="$(pwd)/repo-seeds"
  else
    echo "Missing repo-seeds; set CLAWDINATOR_REPO_SEEDS_DIR" >&2
    exit 1
  fi
fi

nix run --impure github:nix-community/nixos-generators -- --flake "${flake_ref}" -f "${format}" -o "${out_dir}"

out_real="${out_dir}"
if [ -L "${out_dir}" ]; then
  out_real="$(readlink -f "${out_dir}")"
  rm -f "${out_dir}"
  mkdir -p "${out_dir}"
fi

image_file="$(find "${out_real}" -maxdepth 2 -type f \( -name "*.img" -o -name "*.vhd" -o -name "*.raw" -o -name "*.vmdk" \) | head -n 1)"
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
