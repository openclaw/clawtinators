# CLAWDINATOR Agent Notes

Read these before acting:
- docs/PHILOSOPHY.md
- docs/ARCHITECTURE.md
- docs/SHARED_MEMORY.md
- docs/SECRETS.md
- docs/POC.md

Memory references:
- For project goals, read memory/project.md
- For architecture decisions, read memory/architecture.md
- For ops runbook, read memory/ops.md
- For Discord context, also read memory/discord.md

Repo rule: no inline scripting languages (Python/Node/etc.) in Nix or shell blocks; put logic in script files and call them.

The Zen of ~~Python~~ Clawdbot, ~~by~~ shamelessly stolen from Tim Peters:
- Beautiful is better than ugly.
- Explicit is better than implicit.
- Simple is better than complex.
- Complex is better than complicated.
- Flat is better than nested.
- Sparse is better than dense.
- Readability counts.
- Special cases aren't special enough to break the rules.
- Although practicality beats purity.
- Errors should never pass silently.
- Unless explicitly silenced.
- In the face of ambiguity, refuse the temptation to guess.
- There should be one-- and preferably only one --obvious way to do it.
- Although that way may not be obvious at first unless you're Dutch.
- Now is better than never.
- Although never is often better than *right* now.
- If the implementation is hard to explain, it's a bad idea.
- If the implementation is easy to explain, it may be a good idea.
- Namespaces are one honking great idea -- let's do more of those!

Deploy flow (automation-first):
- Use `devenv.nix` for tooling (nixos-generators, awscli2).
- Build a bootstrap NixOS image with nixos-generators (amazon) and upload it to S3.
  - Use `nix/hosts/clawdinator-1-image.nix` for image builds.
- CI is preferred: `.github/workflows/image-build.yml` runs build → S3 upload → AMI import.
- Bootstrap S3 bucket + scoped IAM user + VM Import role with `infra/opentofu/aws` (use homelab-admin creds).
- Import the image into AWS as an AMI (`aws ec2 import-image`).
- Grab the host SSH key and add it to `../nix/nix-secrets/secrets.nix`; rekey secrets with agenix.
- Ensure required secrets exist: `clawdinator-github-app.pem`, `clawdinator-discord-token`, `clawdinator-anthropic-api-key`.
- Update `nix/hosts/<host>.nix` (Discord allowlist, GitHub App installationId, identity name).
- Ensure `/var/lib/clawd/repo` contains this repo (self-update requires it).
- Verify systemd services: `clawdinator`, `clawdinator-github-app-token`, `clawdinator-self-update`.
- Commit and push changes; repo is the source of truth.

Key principle: mental notes don’t survive restarts — write it to a file.

Cattle vs pets: hosts are disposable. Prefer re-provisioning from OpenTofu + NixOS configs over in-place manual fixes.
One way only: AWS AMI pipeline via S3 + VM Import. This is a greenfield repo. Do not reference alternate paths anywhere in code or docs.
