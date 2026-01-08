#!/usr/bin/env bash
# gh-sync.sh — Pure IO sync of GitHub state for clawdbot org
# ZFC-compliant: no reasoning, no scoring, no heuristics
# Writes raw data to memory/github/ for AI to reason about

set -euo pipefail

MEMORY_DIR="${MEMORY_DIR:-/memory}"
GITHUB_DIR="${MEMORY_DIR}/github"
ORG="${ORG:-clawdbot}"

mkdir -p "$GITHUB_DIR"

log() {
  echo "[gh-sync] $(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >&2
}

# Fetch all repos in org
log "Fetching repos for $ORG..."
repos=$(gh repo list "$ORG" --json nameWithOwner,name,description,isArchived --limit 500 -q '.[] | select(.isArchived == false) | .nameWithOwner')

if [ -z "$repos" ]; then
  log "ERROR: No repos found or gh auth failed"
  exit 1
fi

# Temporary files for atomic writes
prs_tmp=$(mktemp)
issues_tmp=$(mktemp)
trap 'rm -f "$prs_tmp" "$issues_tmp"' EXIT

# Header for PRs
cat > "$prs_tmp" << 'EOF'
# Open Pull Requests (clawdbot org)

Last synced: SYNC_TIME

EOF
sed -i.bak "s/SYNC_TIME/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$prs_tmp" && rm -f "${prs_tmp}.bak"

# Header for Issues
cat > "$issues_tmp" << 'EOF'
# Open Issues (clawdbot org)

Last synced: SYNC_TIME

EOF
sed -i.bak "s/SYNC_TIME/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$issues_tmp" && rm -f "${issues_tmp}.bak"

# Iterate repos
for repo in $repos; do
  repo_name="${repo#*/}"
  log "Processing $repo..."

  # Fetch open PRs (raw data, no filtering)
  prs_json=$(gh pr list -R "$repo" --state open --json number,title,author,createdAt,updatedAt,reviewDecision,labels,isDraft,mergeable,headRefName,url --limit 200 2>/dev/null || echo "[]")

  pr_count=$(echo "$prs_json" | jq 'length')
  if [ "$pr_count" -gt 0 ]; then
    echo "## $repo" >> "$prs_tmp"
    echo "" >> "$prs_tmp"
    echo "$prs_json" | jq -r '.[] | "- **#\(.number)** [\(.title)](\(.url))\n  - Author: @\(.author.login)\n  - Created: \(.createdAt)\n  - Updated: \(.updatedAt)\n  - Review: \(.reviewDecision // "PENDING")\n  - Draft: \(.isDraft)\n  - Labels: \((.labels // []) | map(.name) | join(", ") | if . == "" then "none" else . end)\n"' >> "$prs_tmp"
    echo "" >> "$prs_tmp"
  fi

  # Fetch open issues (excludes PRs)
  issues_json=$(gh issue list -R "$repo" --state open --json number,title,author,createdAt,updatedAt,labels,comments,url --limit 200 2>/dev/null || echo "[]")

  issue_count=$(echo "$issues_json" | jq 'length')
  if [ "$issue_count" -gt 0 ]; then
    echo "## $repo" >> "$issues_tmp"
    echo "" >> "$issues_tmp"
    echo "$issues_json" | jq -r '.[] | "- **#\(.number)** [\(.title)](\(.url))\n  - Author: @\(.author.login)\n  - Created: \(.createdAt)\n  - Updated: \(.updatedAt)\n  - Comments: \(.comments | length)\n  - Labels: \((.labels // []) | map(.name) | join(", ") | if . == "" then "none" else . end)\n"' >> "$issues_tmp"
    echo "" >> "$issues_tmp"
  fi
done

# Atomic move to final location (use memory-write if available)
if command -v memory-write &>/dev/null; then
  memory-write "$GITHUB_DIR/prs.md" < "$prs_tmp"
  memory-write "$GITHUB_DIR/issues.md" < "$issues_tmp"
else
  mv "$prs_tmp" "$GITHUB_DIR/prs.md"
  mv "$issues_tmp" "$GITHUB_DIR/issues.md"
fi

log "Sync complete. PRs: $GITHUB_DIR/prs.md, Issues: $GITHUB_DIR/issues.md"
