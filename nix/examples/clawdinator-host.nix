{ secrets, ... }:
{
  age.secrets."clawdinator-github-app.pem".file =
    "/var/lib/clawd/nix-secrets/clawdinator-github-app.pem.age";
  age.secrets."clawdinator-anthropic-api-key".file =
    "/var/lib/clawd/nix-secrets/clawdinator-anthropic-api-key.age";
  age.secrets."clawdinator-discord-token".file =
    "/var/lib/clawd/nix-secrets/clawdinator-discord-token.age";

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 18789 ];

  services.clawdinator = {
    enable = true;
    instanceName = "CLAWDINATOR-1";
    memoryDir = "/var/lib/clawd/memory";

    # Raw Clawdbot config JSON (schema is upstream). Extend as needed.
    config = {
      gateway.mode = "server";
      agent.workspace = "/var/lib/clawd/workspace";
      routing.queue.bySurface = {
        discord = "queue";
        telegram = "interrupt";
        whatsapp = "interrupt";
      };
      identity.name = "CLAWDINATOR-1";
      skills.allowBundled = [ "github" "clawdhub" ];
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
    };

    anthropicApiKeyFile = "/run/agenix/clawdinator-anthropic-api-key";
    discordTokenFile = "/run/agenix/clawdinator-discord-token";

    githubApp = {
      enable = true;
      appId = "123456";
      installationId = "12345678";
      privateKeyFile = "/run/agenix/clawdinator-github-app.pem";
      schedule = "hourly";
    };

    selfUpdate.enable = true;
    selfUpdate.flakePath = "/var/lib/clawd/repo";
    selfUpdate.flakeHost = "clawdinator-1";
  };
}
