#!/usr/bin/env bash
set -euo pipefail

app_id="${GITHUB_APP_ID:-}"
installation_id="${GITHUB_APP_INSTALLATION_ID:-}"
pem_file="${GITHUB_APP_PEM_FILE:-}"

if [ -z "$app_id" ] || [ -z "$installation_id" ] || [ -z "$pem_file" ]; then
  echo "mint-github-app-token: set GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PEM_FILE" >&2
  exit 1
fi

if [ ! -f "$pem_file" ]; then
  echo "mint-github-app-token: PEM file not found: $pem_file" >&2
  exit 1
fi

now="$(date +%s)"
iat="$((now - 60))"
exp="$((now + 540))"

header='{"alg":"RS256","typ":"JWT"}'
payload="{\"iat\":$iat,\"exp\":$exp,\"iss\":\"${app_id}\"}"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

jwt_header="$(printf '%s' "$header" | base64url)"
jwt_payload="$(printf '%s' "$payload" | base64url)"
unsigned="${jwt_header}.${jwt_payload}"
signature="$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$pem_file" | base64url)"
jwt="${unsigned}.${signature}"

resp="$(curl -sS -X POST \
  -H "Authorization: Bearer $jwt" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${installation_id}/access_tokens")"

token="$(printf '%s' "$resp" | jq -r '.token')"
if [ -z "$token" ] || [ "$token" = "null" ]; then
  echo "mint-github-app-token: failed to mint token" >&2
  echo "$resp" >&2
  exit 1
fi

printf '%s' "$token"
