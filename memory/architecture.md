# Architecture Memory

Canonical architecture decisions and invariants for CLAWDINATOR.

- Infra: OpenTofu + AWS AMI pipeline for host provisioning.
- Config: NixOS modules/flake, tracking latest nix-clawdbot.
- Runtime: Clawdbot gateway + CLAWDINATOR service.
- Memory: shared filesystem under /var/lib/clawd/memory.

Update this when architecture decisions change.
