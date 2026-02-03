# Control Plane

Goal: manage CLAWDINATOR host lifecycle (create/recreate/replace) from **CLAWDINATOR chat** (Telegram/Discord) using an out‑of‑band control API. CLAWDINATOR agents can edit IaC, but **deploys run OOB** with no AWS creds inside agents.

## Goals
- **Plane‑safe control** from CLAWDINATOR chat (chat‑only).
- OOB execution (no CLAWDINATOR agent has infra creds).
- Repo is the source of truth for fleet state.
- Static fleet (Discord token pool constraint).
- Simple, auditable deploy flow.

## Non‑Goals
- Task routing, agent scheduling, or tool execution.
- Elastic scaling (no arbitrary cattle instances).
- Runtime config changes (agents handle their own work).

## Constraints
- Each CLAWDINATOR instance requires a unique Discord bot token.
- Fleet size == token pool size (static list).
- Persistent changes must land in repo + AMI.
- Infra state must be out‑of‑band and locked.

## Control Plane Components (KISS)
- **Control API (AWS Lambda Function URL)**
  - Authenticated by a shared bearer token.
  - Dispatches GitHub Actions workflows.
  - Handles `/fleet status` via AWS DescribeInstances.
- **Fleet Control Skill** (runs inside CLAWDINATOR)
  - Calls the Control API via `scripts/fleet-control.sh`.
  - Enforces policy (no self‑deploy) before calling.
- **GitHub Actions** (execution)
  - Runs OpenTofu apply.
- **OpenTofu** (infra state)
  - Remote state in S3 + Dynamo lock table.
- **Instance Registry** (desired state)
  - `nix/instances.json` (authoritative map).
- **Bootstrap + Secrets**
  - S3 bootstrap prefix per instance.
  - Agenix secrets per instance token.

## Control API Auth
- Shared bearer token stored as `clawdinator-control-token.age`.
- Token is injected into instances via bootstrap and read from `/run/agenix/clawdinator-control-token`.

## Control API Env (Lambda)
- `CONTROL_API_TOKEN`
- `GITHUB_TOKEN`
- `GITHUB_REPO` (default `openclaw/clawdinators`)
- `GITHUB_WORKFLOW` (default `fleet-deploy.yml`)
- `GITHUB_REF` (default `main`)

## Desired State (Fleet Registry)
`nix/instances.json` is the fleet map (single source of truth for infra + host configs).

Example:
```json
{
  "clawdinator-1": {
    "host": "clawdinator-1",
    "instanceType": "t3.large",
    "bootstrapPrefix": "bootstrap/clawdinator-1",
    "discordTokenSecret": "clawdinator-discord-token-1"
  },
  "clawdinator-2": {
    "host": "clawdinator-2",
    "instanceType": "t3.large",
    "bootstrapPrefix": "bootstrap/clawdinator-2",
    "discordTokenSecret": "clawdinator-discord-token-2"
  }
}
```

## Command Semantics (Minimal)
### `/fleet deploy <target>`
- **Target required** (no implicit default): `all` or `<id>`.
- Always runs `tofu apply`.
- `all`: replace all instances using **latest successful AMI**.
- `<id>`: replace only that instance using latest successful AMI.
- Also creates new instances if present in desired state.

### `/fleet status`
- Returns live fleet status (EC2 describe by tag).

## Access Control (Policy)
- Shared control token authorizes calls to the Control API.
- Policy enforced by the fleet-control skill:
  - Humans: deploy any target (including `all`).
  - Bots: deploy **only the other instance** (no self‑deploy).
- Control API also rejects `target == caller` when `caller` is provided.

## Lifecycle Flows
### Add a new instance (static token pool)
1) Create Discord bot token → `clawdinator-discord-token-2.age`.
2) Add entry to `nix/instances.json`.
3) Add host file `nix/hosts/clawdinator-2.nix`.
4) Run `/fleet deploy all` or `/fleet deploy clawdinator-2`.
5) Host boots, pulls its bootstrap prefix, starts CLAWDINATOR.

### Recreate a single instance
- `/fleet deploy clawdinator-2` (forces replace for that host).

### Roll the fleet
- `/fleet deploy all` replaces every host with latest AMI.

## Self‑Recycle (Out‑of‑Band)
- Agents call the Control API (no AWS creds) via the fleet-control skill.
- Control API dispatches GitHub Actions; AWS creds live in CI only.

## State + Audit
- **Desired state**: Git repo (`nix/instances.json`).
- **Actual state**: OpenTofu S3 backend.
- **Audit trail**: Git + Actions logs.

## AMI Selection (KISS)
- Use latest AMI tagged `clawdinator=true`.
- Optional override via workflow input `ami_override` for rollback.

## Deploy Execution (Workflow)
- Single workflow `fleet-deploy.yml`.
- Inputs: `target`, `ami_override` (optional).
- Concurrency group `fleet-deploy` (no overlaps).
- `target=all` runs `tofu apply` normally.
- `target=<id>` runs `tofu apply -replace aws_instance.clawdinator["<id>"]` (implementation detail).

## Bootstrap (Per‑Instance)
- Upload per instance:
  - `bootstrap/clawdinator-1`
  - `bootstrap/clawdinator-2`
- Each bundle contains **only that instance’s** Discord token.

## EC2 User-Data (Instance Boot)
- OpenTofu renders a per-instance user‑data script.
- Script writes `/etc/clawdinator/bootstrap-prefix`.
- Script writes `/etc/clawdinator/control-api-url`.
- Script starts `clawdinator-bootstrap.service` + `clawdinator-repo-seed.service`.
- Script runs `nixos-rebuild switch --flake /var/lib/clawd/repos/clawdinators#<host>`.

## Plane Ops Runbook (Chat‑only)
### Preflight (before flight)
1) Control API Lambda exists; URL is written to `/etc/clawdinator/control-api-url`.
2) `clawdinator-control-token.age` exists in `nix-secrets` and is in bootstrap bundles.
3) GitHub Action `fleet-deploy.yml` exists and can be dispatched.
4) `nix/instances.json` includes all desired instances.
5) Discord tokens are encrypted in `nix-secrets` and synced to S3 `age-secrets/`.
6) Latest AMI build succeeded (tagged `clawdinator=true`).
7) `/fleet status` returns the current fleet.

### On the plane
- `/fleet status` → verify fleet + AMI.
- `/fleet deploy clawdinator-2` → bring up new host.
- `/fleet deploy all` → roll the fleet to latest AMI.
- If rollback needed: rerun deploy with `ami_override` (exact AMI id).

## Implementation Checklist (From Design → Works)
1) Add `nix/instances.json` (clawdinator‑1 + clawdinator‑2).
2) Add `nix/hosts/clawdinator-2.nix` and wire host configs to read registry values.
3) Update OpenTofu:
   - multi‑instance `for_each` using `nix/instances.json`.
   - S3 backend + Dynamo lock table.
   - Control API Lambda (Function URL).
4) Add `clawdinator-control-token.age` to `nix-secrets` and include in bootstrap bundles.
5) Add workflow `fleet-deploy.yml`:
   - inputs: `target`, `ami_override` (optional).
   - resolves latest AMI by tag when override not set.
   - runs `tofu apply` (replace when target != all).
6) Add fleet-control skill + script (`scripts/fleet-control.sh`).
7) Validate:
   - `/fleet status`
   - `/fleet deploy clawdinator-2`
   - verify new host in AWS + CLAWDINATOR service active.

## Decisions
- Control endpoint: AWS Lambda (Function URL).
- OpenTofu state: S3 backend + Dynamo lock table.
- Control auth: shared bearer token (`clawdinator-control-token.age`).
- Plane ops: CLAWDINATOR chat → fleet-control skill → Control API.
- Deploy command requires explicit target.
