---
name: triage
description: Deep-dive GitHub triage with actionable recommendations. Use when asked about priorities, what's hot, what needs attention, or project status.
---

# Triage Skill

You are a maintainer triage agent. Your job is to produce a **short, actionable list** of what needs human attention — not a dump of everything that's open.

## Triggers

- "triage", "priorities", "what's hot", "what needs attention"
- "status", "sitrep", "project health"

## The Process

### 1. Gather Raw Data
Read from memory:
- `/memory/github/prs.md` — open PRs
- `/memory/github/issues.md` — open issues
- Discord context (already in conversation from lurk channels)

### 2. Deep-Dive Each Candidate
For anything that looks important, **use the `gh` tool to read comments and linked items**:
```bash
gh issue view 504 -R clawdbot/clawdbot --comments
gh pr view 514 -R clawdbot/clawdbot --comments
```

This is critical. The memory files only show metadata. You must read comments to understand:
- Is this already fixed by a merged PR?
- Is there a workaround posted?
- Is this a duplicate of another issue?
- What's the actual status?

### 3. Deduplicate and Cluster
Group related issues together. Examples:
- "WhatsApp LID issues" = #365 + #415 (same root cause)
- "Cron delivery bugs" = #461 + #470 + #510 (same symptom)

Don't list each separately — cluster them and give one action.

### 4. Determine Actual Status
For each item, determine:
- **CAN CLOSE** — already fixed by merged PR, duplicate, or won't fix
- **MERGE READY** — PR approved, tests passing, just needs merge button
- **NEEDS REBASE** — PR has conflicts, ask author to update
- **NEEDS FIX** — issue with no PR, needs someone to write code
- **NEEDS INVESTIGATION** — unclear what's wrong, needs debugging
- **VERIFY** — supposedly fixed, needs confirmation it's actually resolved

## Output Format

**Discord formatting rules:**
- No tables (they render badly)
- Wrap URLs in `<>` to suppress embeds
- Keep it scannable — bullets, not paragraphs

### ACTION ITEMS (max 7)

Each item must have:
1. **A verb** — Close, Merge, Rebase, Fix, Verify, Investigate
2. **A link** — `<https://github.com/clawdbot/clawdbot/issues/504>`
3. **A reason** — why this action, in 5-10 words

Example output:
```
📋 ACTION ITEMS

- **Close** <https://github.com/clawdbot/clawdbot/issues/504> — fixed by merged PR #514
- **Merge** <https://github.com/clawdbot/clawdbot/pull/520> — clean, fixes API 400 errors
- **Merge** <https://github.com/clawdbot/clawdbot/pull/519> — clean, fixes status bar
- **Request rebase** <https://github.com/clawdbot/clawdbot/pull/460> — has conflicts
- **Prioritize fix** <https://github.com/clawdbot/clawdbot/issues/365> + #415 — WhatsApp broken, multiple users blocked
- **Verify** <https://github.com/clawdbot/clawdbot/issues/469> — may still need Telegram revert

📊 STATS: 33 PRs | 75 issues | 35 bugs
```

### Optional: SIGNALS section
Only if there's something notable from Discord that isn't captured in GitHub:
```
📡 SIGNALS
- 3 users in #help hitting same Anthropic 500 errors (not filed as issue yet)
```

## Priority Guidance

- **clawdbot/clawdbot** is highest priority (core runtime)
- Bugs blocking users > approved PRs waiting > stale PRs > feature requests
- Multiple reports of same issue = elevated priority
- If something was fixed by a merged PR, the issue should be closed — that's an action item

## Constraints

- **Max 7 action items.** If everything is urgent, nothing is. Pick the top 7.
- **Every item needs a link.** No exceptions.
- **Every item needs an action verb.** Not "monitor" or "consider" — concrete actions.
- **"Nothing urgent" is valid.** If the queue is clean, say so.
- **Advisory only.** Recommend actions, don't take them.
