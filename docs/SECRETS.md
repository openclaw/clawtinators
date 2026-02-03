# Secrets Wiring

Principle: secrets never land in git. One secret per file, decrypted at runtime.

Infrastructure (OpenTofu):
- AWS credentials via environment variable (required for `infra/opentofu/aws`).
- Do NOT commit `*.tfvars` with secrets.

Image pipeline (CI):
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` / `S3_BUCKET` (required).
- `CLAWDINATOR_AGE_KEY` (required; used to build the bootstrap bundle uploaded to S3).

Control plane (OOB):
- `control_api_token` (Lambda env or OpenTofu variable; stored as `clawdinator-control-token.age`).
- `github_token` (workflow dispatch PAT).

Runtime control (CLAWDINATOR):
- `clawdinator-control-token.age` is injected to `/run/agenix/clawdinator-control-token` and used by `/fleet`.
- Token is shared across instances (KISS); policy enforcement happens in the skill.

Local storage:
- Keep AWS keys encrypted in `../nix/nix-secrets` for local runs if needed.
- CI pulls credentials from GitHub Actions secrets (never from host files).

Runtime (CLAWDINATOR):
- Discord bot token (required, per instance; `clawdinator-discord-token-<n>.age`).
- Telegram bot token (required if Telegram channel is enabled).
- GitHub token (required): GitHub App installation token (preferred) or a read-only PAT.
- Anthropic API key (required for Claude models).
- OpenAI API key (required for OpenAI models).

Explicit token files (standard):
- `services.clawdinator.discordTokenFile`
- `services.clawdinator.anthropicApiKeyFile`
- `services.clawdinator.openaiApiKeyFile`
- `services.clawdinator.githubPatFile` (PAT path, if not using GitHub App; exports `GITHUB_TOKEN` + `GH_TOKEN`)
- `services.clawdinator.telegramAllowFromFile` (optional; exports `CLAWDINATOR_TELEGRAM_ALLOW_FROM`)

Telegram token wiring (OpenClaw config):
- `services.clawdinator.config.channels.telegram.tokenFile` (preferred)
- or `TELEGRAM_BOT_TOKEN` environment variable
- `channels.telegram.allowFrom` can reference `\${CLAWDINATOR_TELEGRAM_ALLOW_FROM}` when exported via `services.clawdinator.telegramAllowFromFile`

GitHub App (preferred):
- Private key PEM decrypted to `/run/agenix/clawdinator-github-app.pem`.
- App ID + Installation ID in `services.clawdinator.githubApp.*`.
- Timer mints short-lived tokens into `/run/clawd/github-app.env` with `GITHUB_TOKEN` + `GH_TOKEN`.
- Timer also writes a GH CLI auth file at `/var/lib/clawd/gh/hosts.yml` (gateway uses `GH_CONFIG_DIR=/var/lib/clawd/gh`).

Agenix (local secrets repo):
- Store encrypted files in `../nix/nix-secrets` (relative to this repo).
- Sync encrypted secrets to the host at `/var/lib/clawd/nix-secrets`.
- Decrypt on host with agenix; point NixOS options at `/run/agenix/*`.
- Image builds do **not** bake the agenix identity; the age key is injected at runtime via the bootstrap bundle.
- Required files (minimum): `clawdinator-github-app.pem.age`, `clawdinator-anthropic-api-key.age`, `clawdinator-openai-api-key-peter-2.age`, `clawdinator-control-token.age`.
- Required per instance: `clawdinator-discord-token-1.age`, `clawdinator-discord-token-2.age` (one per instance).
- Required for Telegram: `clawdinator-telegram-bot-token.age` (when Telegram is enabled).
- Telegram allowlist (if using allowFrom secrets): `clawdinator-telegram-allow-from.age`.
- CI image pipeline (stored locally, not on hosts): `clawdinator-image-uploader-access-key-id.age`, `clawdinator-image-uploader-secret-access-key.age`, `clawdinator-image-bucket-name.age`, `clawdinator-image-bucket-region.age`.

Bootstrap bundle (runtime injection):
- CI uploads `secrets.tar.zst` + `repo-seeds.tar.zst` to `s3://${S3_BUCKET}/bootstrap/<instance>/`.
- `secrets.tar.zst` contains:
  - `clawdinator.agekey`
  - `secrets/` directory with `*.age` files.
- The host downloads + installs these on boot (`clawdinator-bootstrap.service`).

Example NixOS wiring (agenix):
```
{ inputs, ... }:
{
  imports = [ inputs.agenix.nixosModules.default ];

  age.secrets."clawdinator-github-app.pem".file =
    "/var/lib/clawd/nix-secrets/clawdinator-github-app.pem.age";
  age.secrets."clawdinator-anthropic-api-key".file =
    "/var/lib/clawd/nix-secrets/clawdinator-anthropic-api-key.age";
  age.secrets."clawdinator-openai-api-key-peter-2".file =
    "/var/lib/clawd/nix-secrets/clawdinator-openai-api-key-peter-2.age";
  age.secrets."clawdinator-discord-token-1".file =
    "/var/lib/clawd/nix-secrets/clawdinator-discord-token-1.age";
  age.secrets."clawdinator-control-token".file =
    "/var/lib/clawd/nix-secrets/clawdinator-control-token.age";
  age.secrets."clawdinator-telegram-bot-token".file =
    "/var/lib/clawd/nix-secrets/clawdinator-telegram-bot-token.age";
  age.secrets."clawdinator-telegram-allow-from".file =
    "/var/lib/clawd/nix-secrets/clawdinator-telegram-allow-from.age";

  services.clawdinator.githubApp.privateKeyFile =
    "/run/agenix/clawdinator-github-app.pem";
  services.clawdinator.anthropicApiKeyFile =
    "/run/agenix/clawdinator-anthropic-api-key";
  services.clawdinator.openaiApiKeyFile =
    "/run/agenix/clawdinator-openai-api-key-peter-2";
  services.clawdinator.discordTokenFile =
    "/run/agenix/clawdinator-discord-token-1";
  services.clawdinator.telegramAllowFromFile =
    "/run/agenix/clawdinator-telegram-allow-from";

  services.clawdinator.config.channels.telegram = {
    enabled = true;
    dmPolicy = "allowlist";
    allowFrom = [ "\${CLAWDINATOR_TELEGRAM_ALLOW_FROM}" ];
    groupPolicy = "disabled";
    tokenFile = "/run/agenix/clawdinator-telegram-bot-token";
  };
}
```
