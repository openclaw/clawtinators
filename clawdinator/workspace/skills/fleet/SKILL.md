---
name: fleet
description: Control CLAWDINATOR fleet lifecycle via the control API. Use for /fleet deploy or /fleet status.
user-invocable: true
---

# Fleet Control

Use this skill to manage CLAWDINATOR instances (deploy/replace) and fetch fleet status.

## Safety + Scope
- **Always require an explicit target** for deploy: `all` or `clawdinator-<n>`.
- **Never self-deploy**: if target == your instance, refuse.
- **No AWS creds**: all actions go through the control API.

## Commands
- `/fleet status`
- `/fleet deploy <all|clawdinator-2>`
- Optional rollback: `/fleet deploy <target> <ami_id>`

## Execution
Call the control script and return its output:

```
/var/lib/clawd/repos/clawdinators/scripts/fleet-control.sh <action> [target]
```

If the user asks for deploy without a target, ask for the target.
