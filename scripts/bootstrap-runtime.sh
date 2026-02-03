#!/usr/bin/env bash
set -euo pipefail

bucket="${1:?S3 bucket required}"
prefix="${2:?S3 prefix required}"
secrets_dir="${3:?Secrets dir required}"

override_file="${BOOTSTRAP_PREFIX_FILE:-/etc/clawdinator/bootstrap-prefix}"
if [ -f "${override_file}" ]; then
  override_prefix="$(cat "${override_file}")"
  if [ -n "${override_prefix}" ]; then
    prefix="${override_prefix}"
  fi
fi
repo_seeds_dir="${4:?Repo seeds dir required}"
age_key_path="${5:?Age key path required}"
secrets_archive="${6:-secrets.tar.zst}"
repo_seeds_archive="${7:-repo-seeds.tar.zst}"

sentinel="${secrets_dir}/.bootstrap-ok"
if [ -f "${sentinel}" ]; then
  echo "clawdinator-bootstrap: already initialized"
  exit 0
fi

s3_base="s3://${bucket}/${prefix}"
workdir="$(mktemp -d)"
cleanup() {
  rm -rf "${workdir}"
}
trap cleanup EXIT

mkdir -p "${secrets_dir}" "${repo_seeds_dir}" "$(dirname "${age_key_path}")"

aws s3 cp "${s3_base}/${secrets_archive}" "${workdir}/secrets.tar.zst" --only-show-errors
aws s3 cp "${s3_base}/${repo_seeds_archive}" "${workdir}/repo-seeds.tar.zst" --only-show-errors

tmp_secrets="${workdir}/secrets"
mkdir -p "${tmp_secrets}"
tar --zstd -xf "${workdir}/secrets.tar.zst" -C "${tmp_secrets}"

if [ ! -f "${tmp_secrets}/clawdinator.agekey" ]; then
  echo "clawdinator-bootstrap: missing clawdinator.agekey in secrets archive" >&2
  exit 1
fi

install -m 0400 "${tmp_secrets}/clawdinator.agekey" "${age_key_path}"

if [ ! -d "${tmp_secrets}/secrets" ]; then
  echo "clawdinator-bootstrap: missing secrets/ directory in secrets archive" >&2
  exit 1
fi

cp -a "${tmp_secrets}/secrets/." "${secrets_dir}/"
chmod -R u=rw,go= "${secrets_dir}" || true

tar --zstd -xf "${workdir}/repo-seeds.tar.zst" -C "${repo_seeds_dir}"

touch "${sentinel}"
echo "clawdinator-bootstrap: done"
