# CLAWDINATORS

CLAWDINATORS are maintainer‑grade coding agents. This repo defines how to spawn them
declaratively (OpenTofu + NixOS). Humans are not in the loop.

Principles:
- Declarative‑first. A CLAWDINATOR can bootstrap another CLAWDINATOR with a single command.
- No manual host edits. The repo + agenix secrets are the source of truth.
- Latest upstream nix‑clawdbot by default; breaking changes are acceptable.

Stack:
- AWS AMIs built in CI (nixos-generators + import-image).
- NixOS modules configure Clawdbot and CLAWDINATOR runtime.
- Shared hive‑mind memory stored on a mounted host volume.

Shared memory (hive mind):
- All instances share the same memory files (no per‑instance prefixes for canonical files).
- Daily notes can be per‑instance: `YYYY-MM-DD_INSTANCE.md`.
- Canonical files are single shared sources of truth.

Example layout:
```
~/clawd/
├── memory/
│ ├── project.md # Project goals + non-negotiables
│ ├── architecture.md # Architecture decisions + invariants
│ ├── discord.md # Discord-specific stuff
│ ├── whatsapp.md # WhatsApp-specific stuff
│ └── 2026-01-06.md # Daily notes
```

Secrets (required):
- GitHub App private key (for short‑lived installation tokens).
- Discord bot token (per instance).
- Anthropic API key (Claude models).
- AWS credentials (image pipeline + infra).

Secrets are stored in `../nix/nix-secrets` using agenix and decrypted to `/run/agenix/*`
on hosts. See `docs/SECRETS.md`.

Deploy (automation‑first):
- Prefer image-based provisioning for speed and repeatability.
- Host config lives in `nix/hosts/*` and is exposed in `flake.nix`.
- Ensure `/var/lib/clawd/repo` contains this repo (needed for self‑update).
- Configure Discord guild/channel allowlist and GitHub App installation ID.

Image-based deploy (only path):
1) Build a bootstrap image with nixos-generators:
   - `nix run github:nix-community/nixos-generators -- -f amazon -c nix/hosts/clawdinator-1-image.nix -o dist`
2) Upload the raw image to S3 (private object).
3) Import into AWS as an AMI (`aws ec2 import-image`).
4) Launch hosts from the AMI.
5) Re-key agenix secrets to the new host SSH key and sync secrets to `/var/lib/clawd/nix-secrets`.
6) Run `nixos-rebuild switch --flake /var/lib/clawd/repo#clawdinator-1`.

CI (recommended):
- GitHub Actions builds the image, uploads to S3, and imports an AMI.
- See `.github/workflows/image-build.yml` and `scripts/*.sh`.

AWS bucket bootstrap:
- `infra/opentofu/aws` provisions a private S3 bucket + scoped IAM user + VM Import role.

Docs:
- `docs/PHILOSOPHY.md`
- `docs/ARCHITECTURE.md`
- `docs/SHARED_MEMORY.md`
- `docs/POC.md`
- `docs/SECRETS.md`
- `docs/SKILLS_AUDIT.md`

Repo layout:
- `infra/opentofu/aws` — S3 bucket + IAM + VM import role
- `nix/modules/clawdinator.nix` — NixOS module
- `nix/hosts/` — host configs
- `nix/examples/` — example host + flake wiring
- `memory/` — template memory files

Operating mode:
- No manual setup. Machines are created by automation (other CLAWDINATORS).
- Everything is in repo + agenix. No ad‑hoc changes on hosts.

## nix-clawdbot integration

Role: CLAWDINATORS own automation around packaging updates; `nix-clawdbot` stays focused on Nix packaging.

Automated flow:
1) Poll upstream clawdbot commits (throttled to max once every 10 minutes).
2) Update `nix-clawdbot` canary pin (PR).
3) Wait for Garnix build + `pnpm test`.
4) Run live Discord smoke test in `#clawdinators-test`.
5) If green → promote canary pin to stable (PR auto-merge).
6) If red → do nothing; stable stays pinned.
