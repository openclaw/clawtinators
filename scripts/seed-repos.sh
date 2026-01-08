#!/usr/bin/env bash
set -euo pipefail

list_file="$1"
base_dir="$2"
auth_header=""

if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header="Authorization: Bearer ${GITHUB_TOKEN}"
fi

if [ ! -f "$list_file" ]; then
  echo "seed-repos: missing repo list: $list_file" >&2
  exit 1
fi

mkdir -p "$base_dir"

while IFS=$'\t' read -r name url branch; do
  [ -z "${name:-}" ] && continue
  [ -z "${url:-}" ] && continue

  dest="$base_dir/$name"
  if [ ! -d "$dest/.git" ]; then
    if [ -n "${auth_header}" ] && [[ "$url" == https://github.com/* ]]; then
      if [ -n "${branch:-}" ]; then
        git -c http.extraheader="$auth_header" clone --depth 1 --branch "$branch" "$url" "$dest"
      else
        git -c http.extraheader="$auth_header" clone --depth 1 "$url" "$dest"
      fi
    else
      if [ -n "${branch:-}" ]; then
        git clone --depth 1 --branch "$branch" "$url" "$dest"
      else
        git clone --depth 1 "$url" "$dest"
      fi
    fi
    continue
  fi

  origin_url="$(git -C "$dest" config --get remote.origin.url)"
  if [ -n "${auth_header}" ] && [[ "$origin_url" == https://github.com/* ]]; then
    git -C "$dest" -c safe.directory="$dest" -c http.extraheader="$auth_header" fetch --all --prune
  else
    git -C "$dest" -c safe.directory="$dest" fetch --all --prune
  fi
  if [ -n "${branch:-}" ]; then
    git -C "$dest" -c safe.directory="$dest" checkout "$branch"
    git -C "$dest" -c safe.directory="$dest" reset --hard "origin/$branch"
  else
    git -C "$dest" -c safe.directory="$dest" reset --hard "origin/HEAD"
  fi
done < "$list_file"
