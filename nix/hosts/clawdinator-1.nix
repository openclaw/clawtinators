{ modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../modules/clawdinator.nix
  ];

  networking.hostName = "clawdinator-1";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  nix.package = pkgs.nixVersions.stable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.firewall.allowedTCPPorts = [ 22 18789 ];

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets."clawdinator-github-app.pem" = {
    file = "/var/lib/clawd/nix-secrets/clawdinator-github-app.pem.age";
    owner = "clawdinator";
    group = "clawdinator";
  };
  age.secrets."clawdinator-anthropic-api-key" = {
    file = "/var/lib/clawd/nix-secrets/clawdinator-anthropic-api-key.age";
    owner = "clawdinator";
    group = "clawdinator";
  };
  age.secrets."clawdinator-discord-token" = {
    file = "/var/lib/clawd/nix-secrets/clawdinator-discord-token.age";
    owner = "clawdinator";
    group = "clawdinator";
  };

  services.clawdinator = {
    enable = true;
    instanceName = "CLAWDINATOR-1";
    memoryDir = "/var/lib/clawd/memory";

    config = {
      gateway.mode = "server";
      agent.workspace = "/var/lib/clawd/workspace";
      agent.maxConcurrent = 4;
      routing.queue = {
        mode = "interrupt";
        bySurface = {
          discord = "queue";
          telegram = "interrupt";
          whatsapp = "interrupt";
          webchat = "queue";
        };
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
      appId = "2607181";
      installationId = "102951645";
      privateKeyFile = "/run/agenix/clawdinator-github-app.pem";
      schedule = "hourly";
    };

    selfUpdate.enable = true;
    selfUpdate.flakePath = "/var/lib/clawd/repo";
    selfUpdate.flakeHost = "clawdinator-1";
  };
}
