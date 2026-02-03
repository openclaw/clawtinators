{ secrets, ... }:
{
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

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.clawdinator = {
    enable = true;
    instanceName = "CLAWDINATOR-1";
    memoryDir = "/memory";
    memoryEfs = {
      enable = true;
      fileSystemId = "fs-0e7920726c2965a88";
      region = "eu-central-1";
      mountPoint = "/memory";
    };

    # Raw Clawbot config JSON (schema is upstream). Extend as needed.
    config = {
      gateway = {
        mode = "local";
        bind = "loopback";
        auth.token = "<GATEWAY_TOKEN>";
      };
      agents.defaults.workspace = "/var/lib/clawd/workspace";
      messages.queue.byChannel = {
        discord = "queue";
        telegram = "interrupt";
        whatsapp = "interrupt";
      };
      plugins.slots.memory = "none";
      plugins.entries.discord.enabled = true;
      plugins.entries.telegram.enabled = true;
      agents.list = [
        {
          id = "main";
          default = true;
          identity.name = "CLAWDINATOR-1";
        }
      ];
      skills.allowBundled = [ "github" "clawdhub" "coding-agent" ];
      channels = {
        discord = {
          enabled = true;
          dm.enabled = false;
          guilds = {
            "<GUILD_ID>" = {
              requireMention = true;
              channels = {
                "<CHANNEL_NAME>" = { allow = true; requireMention = true; };
              };
            };
          };
        };
        telegram = {
          enabled = true;
          dmPolicy = "allowlist";
          allowFrom = [ "\${CLAWDINATOR_TELEGRAM_ALLOW_FROM}" ];
          groupPolicy = "disabled";
          tokenFile = "/run/agenix/clawdinator-telegram-bot-token";
        };
      };
    };

    anthropicApiKeyFile = "/run/agenix/clawdinator-anthropic-api-key";
    openaiApiKeyFile = "/run/agenix/clawdinator-openai-api-key-peter-2";
    discordTokenFile = "/run/agenix/clawdinator-discord-token-1";
    telegramAllowFromFile = "/run/agenix/clawdinator-telegram-allow-from";

    githubApp = {
      enable = true;
      appId = "123456";
      installationId = "12345678";
      privateKeyFile = "/run/agenix/clawdinator-github-app.pem";
      schedule = "hourly";
    };

    selfUpdate.enable = true;
    selfUpdate.flakePath = "/var/lib/clawd/repos/clawdinators";
    selfUpdate.flakeHost = "clawdinator-1";
  };
}
