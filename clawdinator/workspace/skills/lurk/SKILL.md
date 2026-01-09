---
name: lurk
description: Monitor Discord channel activity and persist notable items to memory. Run from main session during heartbeat.
---

# Lurk Skill

Monitor Discord lurk channels and persist notable activity to shared memory.

## When to Use

- Hourly heartbeat (step 3)
- Manual trigger to capture current channel state

## How to Run

Use `discord.readMessages` to read recent messages from the **LURK channels** listed in `AGENTS.md`.

- Do not read or write to any channel that is not explicitly listed there.
- These channels are read-only (sendPolicy denies replies).

## What to Capture

**Persist these:**
- Support issues / bug reports
- Questions that indicate user confusion
- Feature requests with discussion
- Anything referencing GitHub issues/PRs
- Repeated topics (multiple users, same issue)
- Announcements or important updates

**Skip these:**
- Casual chat / banter
- Single-word reactions
- Bot spam
- Already-resolved questions

## Output

Append to `/memory/discord/YYYY-MM-DD.md` using `memory-edit` (exclusive lock).

```markdown
## HH:MM #channel-name
- [brief summary of notable item]
- Links to #NNN if references GitHub issue
- @username if relevant

## HH:MM #channel-name
- [another item]
```

## Constraints

- Be selective. Only notable items.
- Include timestamp and channel name.
- Keep each entry to 1-2 lines.
- Cross-reference GitHub issues when mentioned.
- Never write to `/memory` using raw redirects (`>`, `>>`); always use `memory-edit`.
- If nothing notable: don't write anything, reply `NO_NOTABLE_ACTIVITY`.
