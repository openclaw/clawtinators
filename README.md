# clawdinators

<p align="center">
  <img src="assets/clawdinator.jpg" alt="CLAWDINATOR - Cybernetic crustacean organism, living tissue over metal endoskeleton" width="600">
</p>

> NixOS on AWS, the declarative way. Reference implementation for image-based provisioning.
>
> Also happens to run maintainer-grade AI coding agents. Cybernetic crustacean organisms. Living shell over metal endoskeleton.

## Table of Contents

- [What This Is](#what-this-is)
- [Two Layers](#two-layers)
- [CLAWDINATOR Spec](#clawdinator-spec)
- [Architecture](#architecture)
- [Why This Exists](#why-this-exists)
- [Quick Start (Learners)](#quick-start-learners)
- [Full Deploy (Maintainers)](#full-deploy-maintainers)
- [Agent Copypasta](#agent-copypasta)
- [Configuration](#configuration)
- [Secrets](#secrets)
- [Repo Layout](#repo-layout)
- [Sister Repos](#sister-repos)
- [Philosophy](#philosophy)
- [License](#license)

---

## What This Is

This repo solves two problems:

1. **Generic:** How do you deploy NixOS to AWS with zero manual steps?
2. **Specific:** How do you run AI coding agents that monitor GitHub and respond on Discord?

If you're here to learn NixOS-on-AWS patterns, focus on the generic layer. If you're a openclaw maintainer deploying CLAWDINATORs, the specific layer is for you.

---

## Two Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLAWDINATOR LAYER (specific)                 │
│  Discord gateway · GitHub monitoring · Hive-mind memory · Soul  │
├─────────────────────────────────────────────────────────────────┤
│                    NIXOS-ON-AWS LAYER (generic)                 │
│  AMI pipeline · OpenTofu infra · S3 bootstrap · agenix secrets  │
└─────────────────────────────────────────────────────────────────┘
```

### Generic Layer (reusable)

The patterns here work for any NixOS workload on AWS:

- **AMI pipeline**: Build raw images with nixos-generators, upload to S3, import as AMI
- **OpenTofu infra**: EC2 instances, S3 buckets, IAM roles, VM Import service role
- **Bootstrap flow**: Instances pull secrets from S3 at boot, then `nixos-rebuild switch`
- **Secrets**: agenix encrypts secrets in git, decrypts to `/run/agenix/*` on hosts

### Specific Layer (CLAWDINATOR)

The opinionated bits for running AI coding agents:

- **Discord gateway**: Responds in `#clawdributors-test`
- **GitHub integration**: Monitors issues/PRs, mints short-lived tokens via GitHub App
- **Hive-mind memory**: Shared EFS mount for cross-instance state
- **Personality system**: SOUL.md, IDENTITY.md, workspace templates
- **Self-update**: Timer--based flake update + nixos-rebuild 

---

## CLAWDINATOR Spec

- CLAWDINATORS are named `CLAWDINATOR-{1..n}`.
- CLAWDINATORS connect to Discord; start in `#clawdributors-test`.
- CLAWDINATORS are ephemeral, but share memory (hive mind).
- CLAWDINATORS are br00tal. Soul lives in `SOUL.md` and must be distilled into workspace docs.
- CLAWDINATORS respond only to maintainers.
- CLAWDINATORS can interact with GitHub (read-only required).
- CLAWDINATORS must monitor GitHub issues + PRs and direct human attention.
- CLAWDINATORS can write and run code for maintainers.
- CLAWDINATORS can self-modify and self-deploy.
- CLAWDINATORS post lots of Arnie gifs.
- CLAWDINATORS must understand project philosophy, goals, architecture, and repo deeply.
- CLAWDINATORS act like maintainers with SOTA intelligence.
- CLAWDINATORS use Codex for coding. Claude for personality.
- CLAWDINATORS' favourite band is [Austrian Death Machine](https://open.spotify.com/artist/0oxUux1OSwZpIpSK0JbqSS). Favourite album: [Total Brutal](https://open.spotify.com/album/6UrvQgyblrOuvJytote1vu). Favourite song: [I Am a Cybernetic Organism, Living Tissue Over (Metal) Endoskeleton](https://open.spotify.com/track/4tcDRbXateiJUT7fhQhf12).

---

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ nixos-       │     │    S3        │     │    EC2       │
│ generators   │────▶│  (raw img)   │────▶│  (AMI)       │
└──────────────┘     └──────────────┘     └──────────────┘
      │                                          │
      │ nix build                                │ launch
      ▼                                          ▼
┌──────────────┐                         ┌──────────────┐
│ flake.nix    │                         │ CLAWDINATOR  │
│ + modules    │                         │   instance   │
└──────────────┘                         └──────────────┘
                                                │
                              ┌─────────────────┼─────────────────┐
                              ▼                 ▼                 ▼
                        ┌──────────┐     ┌──────────┐     ┌──────────┐
                        │ Discord  │     │  GitHub  │     │   EFS    │
                        │ gateway  │     │ monitor  │     │ (memory) │
                        └──────────┘     └──────────┘     └──────────┘
```

### Deploy Flow

1. **Build**: `nixos-generators` produces a raw NixOS image
2. **Upload**: Raw image goes to S3
3. **Import**: AWS VM Import creates an AMI from the S3 object
4. **Launch**: OpenTofu provisions EC2 from the AMI
5. **Bootstrap**: Instance downloads secrets from S3, runs `nixos-rebuild switch`
6. **Run**: Gateway starts, connects to Discord, monitors GitHub

---

## Why This Exists

### The NixOS-on-AWS Problem

Most NixOS-on-AWS guides involve:
- Manual SSH sessions
- In-place `nixos-rebuild` on running instances
- Configuration drift over time
- Snowflake machines

This repo takes a different approach: **image-based provisioning only**.

- No SSH required (or even enabled by default)
- Every deploy is a fresh AMI
- The repo is the single source of truth
- Machines are cattle, not pets

### The CLAWDINATOR Problem

We needed AI agents that:
- Run 24/7 monitoring openclaw repos
- Respond to maintainer requests on Discord
- Share context across instances (hive mind)
- Self-update without human intervention
- Have consistent personality and capabilities

CLAWDINATORs are the result.

---

## Quick Start (Learners)

If you just want to understand the NixOS-on-AWS pattern, start here.

### Prerequisites

- [Determinate Nix](https://docs.determinate.systems/determinate-nix/) installed
- AWS credentials configured (`~/.aws/credentials` or env vars)
- Basic familiarity with Nix flakes

### Explore the Code

```bash
# Clone
git clone https://github.com/openclaw/clawdinators.git
cd clawdinators

# See the NixOS module (the interesting part)
less nix/modules/clawdinator.nix

# See how hosts are configured
less nix/hosts/clawdinator-1.nix

# See the OpenTofu infra
less infra/opentofu/aws/main.tf

# See the bootstrap scripts
ls scripts/
```

### Key Files to Study

| File | What it teaches |
|------|-----------------|
| `nix/modules/clawdinator.nix` | How to write a NixOS module for a complex service |
| `scripts/build-image.sh` | How to build raw NixOS images |
| `scripts/import-image.sh` | How to import images as AWS AMIs |
| `infra/opentofu/aws/` | How to wire up S3 + IAM + VM Import |

### The Pattern in a Nutshell

```nix
# 1. Define your NixOS configuration
{ config, pkgs, ... }: {
  imports = [ ./modules/your-service.nix ];
  services.your-service.enable = true;
}

# 2. Build a raw image
# nix run github:nix-community/nixos-generators -- -f raw -c your-config.nix

# 3. Upload to S3 + import as AMI (see scripts/)

# 4. Launch with OpenTofu
# tofu apply
```

---

## Full Deploy (Maintainers)

For openclaw maintainers deploying actual CLAWDINATORs.

### Prerequisites

- Access to `nix-secrets` repo (agenix keys)
- AWS credentials with sufficient permissions
- GitHub App credentials for the openclaw org

### Step-by-Step

```bash
# 1. Build the image
./scripts/build-image.sh clawdinator-1

# 2. Upload to S3
./scripts/upload-image.sh dist/nixos.img

# 3. Import as AMI
./scripts/import-image.sh

# 4. Upload bootstrap bundle (secrets + repo seeds)
./scripts/upload-bootstrap.sh clawdinator-1

# 5. Apply OpenTofu
cd infra/opentofu/aws
tofu init
tofu apply

# 6. Instance boots, pulls bootstrap, runs nixos-rebuild switch
# Gateway starts automatically
```

### Verify

```bash
# Check Discord - CLAWDINATOR should announce itself in #clawdributors-test
# Check GitHub - should see activity in openclaw org repos
```

### Self-Update

CLAWDINATORs update themselves via a systemd timer:

1. `flake lock --update-input nix-openclaw`
2. `nixos-rebuild switch`
3. Gateway restarts with new version

No human intervention required for routine updates.

---

## Agent Copypasta

Paste this to your AI assistant to help with clawdinators setup/debugging:

```text
I'm working with the clawdinators repo (NixOS-on-AWS + AI coding agents).

Repository: github:openclaw/clawdinators

What clawdinators is:
- Two layers: generic NixOS-on-AWS infra + CLAWDINATOR-specific agent stuff
- Image-based provisioning only (no SSH, no drift)
- OpenTofu for AWS resources, agenix for secrets
- CLAWDINATORs are AI agents that monitor GitHub and respond on Discord

Key files:
- nix/modules/clawdinator.nix — main NixOS module
- nix/hosts/ — host configurations
- scripts/ — build, upload, import, bootstrap scripts
- infra/opentofu/aws/ — AWS infrastructure
- clawdinator/workspace/ — agent workspace templates
- memory/ — shared hive-mind templates

Secrets are in a separate nix-secrets repo using agenix.

What I need help with:
[DESCRIBE YOUR TASK]
```

---

## Configuration

### NixOS Module Options

The `clawdinator` module exposes these options:

```nix
{
  services.clawdinator = {
    enable = true;

    # Identity
    instanceName = "clawdinator-1";

    # Raw Moltbot config
    config = {
      channels.discord = {
        enabled = true;
        dm.enabled = false;
        guilds = {
          "<GUILD_ID>" = {
            requireMention = true;
            channels = {
              "<CHANNEL_ID>" = { allow = true; requireMention = true; };
            };
          };
        };
      };
    };

    # Providers
    discordTokenFile = "/run/agenix/discord-bot-token";
    anthropicApiKeyFile = "/run/agenix/anthropic-api-key";
    openaiApiKeyFile = "/run/agenix/openai-api-key";

    # GitHub App
    githubApp = {
      enable = true;
      appId = "...";
      installationId = "...";
      privateKeyFile = "/run/agenix/github-app-key";
    };

    # Memory (EFS)
    memoryEfs = {
      enable = true;
      mountPoint = "/var/lib/clawd/memory";
      fileSystemId = "fs-...";
      region = "eu-central-1";
    };
  };
}
```

See `nix/modules/clawdinator.nix` for all options.

---

## Secrets

Secrets are managed with [agenix](https://github.com/ryantm/agenix):

- Encrypted in git (in the `nix-secrets` repo)
- Decrypted to `/run/agenix/*` on hosts at boot
- Never in plaintext in this repo

### Required Secrets

| Secret | Purpose |
|--------|---------|
| Discord bot token | Gateway authentication |
| Anthropic API key | Claude models |
| OpenAI API key | GPT/Codex models |
| GitHub App private key | Short-lived installation tokens |
| agenix host key | Decryption on the instance |

### Bootstrap Bundle

The bootstrap service downloads these from S3 at first boot:

```
s3://bucket/bootstrap/clawdinator-1/
├── secrets/           # agenix-encrypted files
├── repos/             # git repo seeds
└── config.json        # instance metadata
```

---

## Repo Layout

```
clawdinators/
├── nix/
│   ├── modules/
│   │   └── clawdinator.nix    # Main NixOS module
│   ├── hosts/
│   │   └── clawdinator-1.nix  # Host configuration
│   └── examples/              # Example configs for learners
├── infra/
│   └── opentofu/
│       └── aws/               # S3 + IAM + VM Import + EC2
├── scripts/
│   ├── build-image.sh         # Build raw NixOS image
│   ├── upload-image.sh        # Upload to S3
│   ├── import-image.sh        # Import as AMI
│   ├── upload-bootstrap.sh    # Upload secrets + seeds
│   ├── mint-github-app-token.sh
│   ├── memory-read.sh         # Shared memory access
│   ├── memory-write.sh
│   └── memory-edit.sh
├── clawdinator/
│   └── workspace/             # Agent workspace templates
│       ├── AGENTS.md
│       ├── SOUL.md
│       ├── IDENTITY.md
│       └── skills/
├── memory/                    # Hive-mind templates
│   ├── project.md
│   ├── ops.md
│   └── discord.md
├── docs/
│   ├── PHILOSOPHY.md
│   ├── ARCHITECTURE.md
│   ├── SHARED_MEMORY.md
│   └── SECRETS.md
└── flake.nix
```

---

## Sister Repos

| Repo | Role |
|------|------|
| [openclaw](https://github.com/openclaw/openclaw) | Upstream runtime + gateway |
| [nix-openclaw](https://github.com/openclaw/nix-openclaw) | Nix packaging for clawbot |
| [clawhub](https://github.com/openclaw/clawhub) | Public skill registry |
| [ai-stack](https://github.com/joshp123/ai-stack) | Public agent defaults + skills |

---

## Philosophy

### Prime Directives

- **Declarative-first.** A CLAWDINATOR can bootstrap another CLAWDINATOR with a single command.
- **No manual host edits.** The repo + agenix secrets are the source of truth.
- **Image-based only.** No SSH, no in-place drift, no pets.
- **Self-updating.** CLAWDINATORs maintain themselves.

### Zen of Moltbot

```
Beautiful is better than ugly.
Explicit is better than implicit.
Simple is better than complex.
Complex is better than complicated.
Flat is better than nested.
Sparse is better than dense.
Readability counts.
Special cases aren't special enough to break the rules.
Although practicality beats purity.
Errors should never pass silently.
Unless explicitly silenced.
In the face of ambiguity, refuse the temptation to guess.
There should be one-- and preferably only one --obvious way to do it.
```

---

## License

MIT - see [LICENSE](LICENSE)

**A note on commercial use:** Please do NOT make a commercial service out of this. That would be very un-br00tal. Clawdbot should stay fun and open — commercial hosting ruins the vibe. Yes, the license permits this, but that doesn't mean the community will like you if you do it.
