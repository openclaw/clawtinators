#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
target="${2:-}"
ami_override="${3:-}"

if [ -z "${action}" ]; then
  echo "Usage: fleet-control.sh <deploy|status> [target] [ami_override]" >&2
  exit 1
fi

api_url_file="/etc/clawdinator/control-api-url"
token_file="/run/agenix/clawdinator-control-token"
caller_file="/etc/clawdinator/instance-name"

if [ ! -f "${api_url_file}" ]; then
  echo "Missing control API URL: ${api_url_file}" >&2
  exit 1
fi
if [ ! -f "${token_file}" ]; then
  echo "Missing control API token: ${token_file}" >&2
  exit 1
fi
if [ ! -f "${caller_file}" ]; then
  echo "Missing instance name: ${caller_file}" >&2
  exit 1
fi

api_url="$(cat "${api_url_file}")"
control_token="$(cat "${token_file}")"
caller="$(cat "${caller_file}")"

if [ "${action}" = "deploy" ]; then
  if [ -z "${target}" ]; then
    echo "Target required. Usage: fleet-control.sh deploy <all|clawdinator-2>" >&2
    exit 1
  fi

  if [ "${target}" = "${caller}" ]; then
    echo "Refusing self-deploy for ${caller}." >&2
    exit 1
  fi
fi

payload="$(jq -n \
  --arg action "${action}" \
  --arg target "${target}" \
  --arg caller "${caller}" \
  --arg ami_override "${ami_override}" \
  '{action: $action, target: $target, caller: $caller, ami_override: $ami_override}')"

response="$(curl -sS -X POST \
  -H "Authorization: Bearer ${control_token}" \
  -H "Content-Type: application/json" \
  -d "${payload}" \
  "${api_url}")"

if [ "${action}" = "status" ]; then
  ok="$(printf '%s' "${response}" | jq -r '.ok')"
  if [ "${ok}" != "true" ]; then
    echo "${response}" >&2
    exit 1
  fi
  echo "Name | InstanceId | State | AMI | Public IP"
  printf '%s' "${response}" | jq -r '.instances[] | "\(.name) | \(.id) | \(.state) | \(.ami) | \(.ip)"'
  exit 0
fi

echo "${response}"
