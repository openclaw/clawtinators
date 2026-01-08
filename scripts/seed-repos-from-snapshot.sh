#!/usr/bin/env bash
set -euo pipefail

src="$1"
dst="$2"
owner="${3:-}"
group="${4:-}"

if [ ! -d "$src" ]; then
  echo "seed-repos-from-snapshot: missing source dir: $src" >&2
  exit 1
fi

mkdir -p "$dst"

rsync -a --delete "$src/" "$dst/"

if [ -n "$owner" ] && [ -n "$group" ]; then
  chown -R "$owner:$group" "$dst"
fi
