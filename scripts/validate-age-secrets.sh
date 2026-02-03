#!/usr/bin/env bash
set -euo pipefail

instances_file="${INSTANCES_FILE:-nix/instances.json}"
secrets_dir="${SECRETS_DIR:-nix/age-secrets}"

required_common=(
  "clawdinator-github-app.pem.age"
  "clawdinator-anthropic-api-key.age"
  "clawdinator-openai-api-key-peter-2.age"
  "clawdinator-control-token.age"
  "clawdinator-telegram-bot-token.age"
  "clawdinator-telegram-allow-from.age"
)

for secret_file in "${required_common[@]}"; do
  if [ ! -f "${secrets_dir}/${secret_file}" ]; then
    echo "Missing required secret: ${secrets_dir}/${secret_file}" >&2
    exit 1
  fi
done

if [ ! -f "${instances_file}" ]; then
  echo "Missing instances file: ${instances_file}" >&2
  exit 1
fi

while IFS= read -r token_secret; do
  if [ -z "${token_secret}" ] || [ "${token_secret}" = "null" ]; then
    echo "Missing discordTokenSecret in ${instances_file}" >&2
    exit 1
  fi
  if [ ! -f "${secrets_dir}/${token_secret}.age" ]; then
    echo "Missing instance discord token: ${secrets_dir}/${token_secret}.age" >&2
    exit 1
  fi
done < <(jq -r 'to_entries[].value.discordTokenSecret' "${instances_file}")
