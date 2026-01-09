#!/usr/bin/env bash
set -euo pipefail

root="${1:-/memory}"
owner="${2:-clawdinator}"
group="${3:-clawdinator}"

mkdir -p "$root/daily" "$root/discord"

index="$root/index.md"
if [ ! -f "$index" ]; then
  cat > "$index" <<'EOM'
# Shared Memory Index

- Daily notes live in /memory/daily/YYYY-MM-DD.md
- Durable facts belong in /memory/project.md and /memory/architecture.md
- Discord lurk snapshots live in /memory/discord/YYYY-MM-DD.md
EOM
fi

# Ensure shared memory is writable by the service user across instances.
chown "$owner:$group" "$root" "$root/daily" "$root/discord"
chmod 2770 "$root" "$root/daily" "$root/discord"
