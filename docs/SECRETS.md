# Secrets Wiring

Principle: secrets never land in git. One secret per file, decrypted at runtime.

Infrastructure (OpenTofu):
- AWS credentials via environment variable (required for `infra/opentofu/aws`).
- Do NOT commit `*.tfvars` with secrets.

Image pipeline (CI):
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` / `S3_BUCKET` (required).
- `S3_PREFIX` (optional).
- `VMIMPORT_ROLE` (optional; defaults to `vmimport`).

Local storage:
- Keep AWS keys encrypted in `../nix/nix-secrets` for local runs if needed.
- CI pulls credentials from GitHub Actions secrets (never from host files).

Runtime (CLAWDINATOR):
- Discord bot token (required, per instance).
- GitHub token (required): GitHub App installation token (preferred) or a read-only PAT.
- Anthropic API key (required for Claude models).

Explicit token files (standard):
- `services.clawdinator.discordTokenFile`
- `services.clawdinator.anthropicApiKeyFile`
- `services.clawdinator.githubPatFile` (PAT path, if not using GitHub App; exports `GITHUB_TOKEN` + `GH_TOKEN`)

GitHub App (preferred):
- Private key PEM decrypted to `/run/agenix/clawdinator-github-app.pem`.
- App ID + Installation ID in `services.clawdinator.githubApp.*`.
- Timer mints short-lived tokens into `/run/clawd/github-app.env` with `GITHUB_TOKEN` + `GH_TOKEN`.

Agenix (local secrets repo):
- Store encrypted files in `../nix/nix-secrets` (relative to this repo).
- Sync encrypted secrets to the host at `/var/lib/clawd/nix-secrets`.
- Decrypt on host with agenix; point NixOS options at `/run/agenix/*`.
- Required files (minimum): `clawdinator-github-app.pem.age`, `clawdinator-discord-token.age`, `clawdis-anthropic-api-key.age`.
- CI image pipeline (stored locally, not on hosts): `clawdinator-ami-importer-access-key-id.age`, `clawdinator-ami-importer-secret-access-key.age`, `clawdinator-image-bucket-name.age`, `clawdinator-image-bucket-region.age`.

Example NixOS wiring (agenix):
```
{ inputs, ... }:
{
  imports = [ inputs.agenix.nixosModules.default ];

  age.secrets."clawdinator-github-app.pem".file =
    "/var/lib/clawd/nix-secrets/clawdinator-github-app.pem.age";
  age.secrets."clawdis-anthropic-api-key".file =
    "/var/lib/clawd/nix-secrets/clawdis-anthropic-api-key.age";
  age.secrets."clawdinator-discord-token".file =
    "/var/lib/clawd/nix-secrets/clawdinator-discord-token.age";

  services.clawdinator.githubApp.privateKeyFile =
    "/run/agenix/clawdinator-github-app.pem";
  services.clawdinator.anthropicApiKeyFile =
    "/run/agenix/clawdis-anthropic-api-key";
  services.clawdinator.discordTokenFile =
    "/run/agenix/clawdinator-discord-token";
}
```
