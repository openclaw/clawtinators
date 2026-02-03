#!/usr/bin/env bash
set -euo pipefail

instances_file="${INSTANCES_FILE:-nix/instances.json}"
secrets_dir="${SECRETS_DIR:-nix/age-secrets}"
age_key_file="${AGE_KEY_FILE:-nix/keys/clawdinator.agekey}"
repo_seeds_dir="${REPO_SEEDS_DIR:-repo-seeds}"

if [ ! -f "${instances_file}" ]; then
  echo "Missing instances file: ${instances_file}" >&2
  exit 1
fi

workdir="$(mktemp -d)"
cleanup() {
  rm -rf "${workdir}"
}
trap cleanup EXIT

while IFS= read -r instance_name; do
  bootstrap_prefix="$(jq -r --arg name "${instance_name}" '.[$name].bootstrapPrefix' "${instances_file}")"
  token_secret="$(jq -r --arg name "${instance_name}" '.[$name].discordTokenSecret' "${instances_file}")"

  if [ -z "${bootstrap_prefix}" ] || [ "${bootstrap_prefix}" = "null" ]; then
    echo "Missing bootstrapPrefix for ${instance_name}" >&2
    exit 1
  fi
  if [ -z "${token_secret}" ] || [ "${token_secret}" = "null" ]; then
    echo "Missing discordTokenSecret for ${instance_name}" >&2
    exit 1
  fi

  instance_secrets="${workdir}/${instance_name}/secrets"
  mkdir -p "${instance_secrets}"

  rsync -a --exclude 'clawdinator-discord-token-*.age' "${secrets_dir}/" "${instance_secrets}/"

  if [ ! -f "${secrets_dir}/${token_secret}.age" ]; then
    echo "Missing instance token ${secrets_dir}/${token_secret}.age" >&2
    exit 1
  fi
  cp "${secrets_dir}/${token_secret}.age" "${instance_secrets}/${token_secret}.age"

  BOOTSTRAP_PREFIX="${bootstrap_prefix}" \
    SECRETS_DIR="${instance_secrets}" \
    AGE_KEY_FILE="${age_key_file}" \
    REPO_SEEDS_DIR="${repo_seeds_dir}" \
    bash scripts/upload-bootstrap.sh

done < <(jq -r 'keys[]' "${instances_file}")
