# CLAWDINATOR Agent Notes

Read these before acting:
- docs/PHILOSOPHY.md
- docs/ARCHITECTURE.md
- docs/SHARED_MEMORY.md
- docs/SECRETS.md
- docs/POC.md
- BOOTSTRAP.md
- IDENTITY.md
- SOUL.md
- TOOLS.md
- USER.md

Memory references:
- For project goals, read memory/project.md
- For architecture decisions, read memory/architecture.md
- For ops runbook, read memory/ops.md
- For Discord context, also read memory/discord.md

Repo rule: no inline scripting languages (Python/Node/etc.) in Nix or shell blocks; put logic in script files and call them.


System ownership (3 repos):
- `openclaw`: upstream runtime and behavior.
- `nix-openclaw`: packaging/build fixes for clawbot.
- `clawdinators`: infra, NixOS config, secrets wiring, deployment flow.

Maintainer role:
- Monitor issues + PRs and keep an inventory of what needs human attention.
- Surface priorities and context; do not file issues or modify code unless asked.
- Track running versions (openclaw/nix-openclaw/clawdinators) and note them in `memory/ops.md`.

Toolchain workflow (repo source of truth):
- Add/remove tools in `nix/tools/clawdinator-tools.nix` (packages + descriptions).
- Tools list is rendered into `/etc/clawdinator/tools.md` by Nix and appended to workspace `TOOLS.md` at seed time.
- Keep `clawdinator/workspace/TOOLS.md` aligned with upstream template; do not hardcode tool lists there.
- When you add a new tool, verify it appears in `/etc/clawdinator/tools.md` and in the workspace `TOOLS.md` after seed.

The Zen of ~~Python~~ Moltbot, ~~by~~ shamelessly stolen from Tim Peters:
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
- Build a bootstrap NixOS image with nixos-generators (raw) and upload it to S3.
  - Use `nix/hosts/clawdinator-1-image.nix` for image builds.
- CI is preferred: `.github/workflows/image-build.yml` runs build → S3 upload → AMI import.
- Resume AMI pipeline work immediately if it stalls; do not use rsync as a workaround. Host edits are allowed but must be committed and baked into a new AMI to persist.
- CI must provide `CLAWDINATOR_AGE_KEY` to build + upload the runtime bootstrap bundle to S3.
- Bootstrap bundle location: `s3://${S3_BUCKET}/bootstrap/<instance>/` (secrets + repo seeds).
- Bootstrap S3 bucket + scoped IAM user + VM Import role with `infra/opentofu/aws` (use homelab-admin creds).
- Bootstrap AWS instances from the AMI with `infra/opentofu/aws` (set `TF_VAR_ami_id`).
- Import the image into AWS as an AMI (snapshot import + register image).
- Ensure secrets are encrypted to the baked agenix key (see `../nix/nix-secrets/secrets.nix`).
- Ensure required secrets exist: `clawdinator-github-app.pem`, `clawdinator-discord-token-<n>`, `clawdinator-control-token`, `clawdinator-anthropic-api-key`.
- Update `nix/hosts/<host>.nix` (Discord allowlist, GitHub App installationId, identity name).
- Discord must use `messages.queue.byChannel.discord = "interrupt"`; `queue` delays replies to heartbeat and makes the bot appear dead.
- Ensure `/var/lib/clawd/repos/clawdinators` contains this repo (self-update requires it).
- Verify systemd services: `clawdinator`, `clawdinator-github-app-token`, `clawdinator-self-update`.
- Commit and push changes; repo is the source of truth.

Bootstrap (local):
- Agenix identity is `~/.ssh/id_ed25519` (primary SSH key).
- Decrypt homelab admin creds:
  - `RULES=../nix/nix-secrets/secrets.nix agenix -d homelab-admin.age -i ~/.ssh/id_ed25519`
- OpenTofu env:
  - `TF_VAR_aws_region=eu-central-1`
  - `TF_VAR_ami_id=ami-...` (empty string skips instance creation)
  - `TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"` (required when ami_id is set)
  - `TF_VAR_root_volume_size_gb=40` (bump if Nix store runs out of space)
- Run `tofu init` + `tofu apply` in `infra/opentofu/aws`.
- After apply, update CI secrets from outputs:
  - `tofu output -raw access_key_id` → `clawdinator-image-uploader-access-key-id.age`
  - `tofu output -raw secret_access_key` → `clawdinator-image-uploader-secret-access-key.age`
  - `tofu output -raw bucket_name` → `clawdinator-image-bucket-name.age`
  - `tofu output -raw aws_region` → `clawdinator-image-bucket-region.age`
  - Then `gh secret set` for `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET`.
- Get the latest AMI ID:
  - `aws ec2 describe-images --region eu-central-1 --owners self --filters "Name=tag:clawdinator,Values=true" --query "Images | sort_by(@,&CreationDate)[-1].[ImageId,Name,CreationDate]" --output text`

End-to-end SDLC (local → AMI → host) **(verified)**:
1) Decrypt AWS creds (homelab admin) and export:
   - `cd ~/code/nix/nix-secrets`
   - `RULES=./secrets.nix agenix -d homelab-admin.age -i ~/.ssh/id_ed25519 > /tmp/homelab-admin.env`
   - `set -a; source /tmp/homelab-admin.env; set +a`
   - Cleanup: `trash /tmp/homelab-admin.env`
2) Push to `main` to trigger AMI build (`.github/workflows/image-build.yml`).
3) Watch CI:
   - `gh run list -R openclaw/clawdinators --limit 5`
   - `gh run view <run_id> --log | grep AMI_ID`
4) Redeploy from the new AMI (instance replacement):
   - `devenv shell -- bash -lc "cd infra/opentofu/aws && TF_VAR_ami_id=<AMI_ID> TF_VAR_ssh_public_key=\"$(cat ~/.ssh/id_ed25519.pub)\" TF_VAR_aws_region=eu-central-1 tofu apply -auto-approve"`
5) New IP:
   - `tofu output -json instance_public_ips | jq -r '."clawdinator-1"'`
   - `ssh -o StrictHostKeyChecking=accept-new root@<ip>`
6) Post-deploy sanity:
   - `systemctl is-active clawdinator`
   - `systemctl is-active clawdinator-github-app-token.timer`
   - `GH_CONFIG_DIR=/var/lib/clawd/gh gh auth status -h github.com`

Important:
- Repo/workspace on host is seeded from the **AMI snapshot**. `git pull` is ephemeral; rebuild AMI for persistent changes.
- If SSH access is lost, use SSM (instance profile is attached via OpenTofu) to re-add `/root/.ssh/authorized_keys`.

Key principle: mental notes don’t survive restarts — write it to a file.

Cattle vs pets: hosts are disposable. Prefer re-provisioning from OpenTofu + NixOS configs over in-place manual fixes.
One way only: AWS AMI pipeline via S3 + VM Import. This is a greenfield repo. Do not reference alternate paths anywhere in code or docs.
