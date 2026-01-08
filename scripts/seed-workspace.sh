#!/usr/bin/env bash
set -euo pipefail

src="$1"
dst="$2"

if [ ! -d "$src" ]; then
  echo "seed-workspace: missing template dir: $src" >&2
  exit 1
fi

mkdir -p "$dst"

rsync -a --delete --exclude 'BOOTSTRAP.md' "$src/" "$dst/"

if [ -f "/etc/clawdinator/tools.md" ]; then
  printf '\n%s\n' "$(cat /etc/clawdinator/tools.md)" >> "$dst/TOOLS.md"
fi
