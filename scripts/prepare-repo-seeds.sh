#!/usr/bin/env bash
set -euo pipefail

dest="${1:-repo-seeds}"
list_file="${2:-clawdinator/repos.tsv}"

if [ ! -f "$list_file" ]; then
  echo "prepare-repo-seeds: missing repo list: $list_file" >&2
  exit 1
fi

mkdir -p "$dest"
rm -rf "${dest:?}/"*

auth_header=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
  basic_auth="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')"
  auth_header="Authorization: Basic ${basic_auth}"
fi

while IFS=$'\t' read -r name url branch; do
  [ -z "${name:-}" ] && continue
  [ -z "${url:-}" ] && continue

  target="${dest}/${name}"
  if [ -n "${auth_header}" ] && [[ "$url" == https://github.com/* ]]; then
    if [ -n "${branch:-}" ]; then
      git -c http.extraheader="$auth_header" clone --depth 1 --branch "$branch" "$url" "$target"
    else
      git -c http.extraheader="$auth_header" clone --depth 1 "$url" "$target"
    fi
  else
    if [ -n "${branch:-}" ]; then
      git clone --depth 1 --branch "$branch" "$url" "$target"
    else
      git clone --depth 1 "$url" "$target"
    fi
  fi
done < "$list_file"
