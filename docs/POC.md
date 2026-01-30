# POC: CLAWDINATOR-1

Acceptance criteria:
- One AWS host provisioned from an AMI built from this repo.
- Host created via OpenTofu using `infra/opentofu/aws`.
- NixOS config applied via Nix (module or flake).
- CLAWDINATOR-1 connects to Discord #clawdributors-test.
- GitHub integration is read-only.
- Shared memory directory mounted and writable.
- Discord allowlist configured (guild + channels).

Secrets needed (initially):
- Discord bot token (per instance).
- GitHub token (PAT or App installation token).
- Anthropic API key.
- AWS credentials (image pipeline + infra).

Secrets wiring:
- Infra: AWS credentials for OpenTofu and CI.
 
Image pipeline:
- Build a bootstrap image with nixos-generators (raw) from `nix/hosts/clawdinator-1-image.nix`, upload to S3, import as an AMI via snapshot import + register-image.
- Launch instances from the AMI, then nixos-rebuild applies full config.
- Runtime: explicit token files via agenix (standard).
- GitHub token is required. Prefer GitHub App (`services.clawdinator.githubApp.*`) to mint short-lived tokens.
- Store PEM and tokens in the local secrets repo (see docs/SECRETS.md) and decrypt to `/run/agenix/*`.
- Discord token is required: set `services.clawdinator.discordTokenFile` to `/run/agenix/clawdinator-discord-token`.

Deliverables:
- Infra code in infra/opentofu/aws.
- Nix module in nix/.
- CLAWDINATOR config in clawdinator/.

Nix wiring notes:
- Apply nix-openclaw overlay (latest upstream).
- Enable services.clawdinator and provide openclaw.json config.
