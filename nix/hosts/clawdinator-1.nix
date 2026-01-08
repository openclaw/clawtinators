{ lib, modulesPath, pkgs, ... }:
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

  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  networking.firewall.allowedTCPPorts = [ 22 18789 ];

  age.identityPaths = [ "/etc/agenix/keys/clawdinator.agekey" ];
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
    memoryDir = "/memory";
    memoryEfs = {
      enable = true;
      fileSystemId = "fs-0e7920726c2965a88";
      region = "eu-central-1";
      mountPoint = "/memory";
    };
    repoSeeds = [
      {
        name = "clawdbot";
        url = "https://github.com/clawdbot/clawdbot.git";
      }
      {
        name = "nix-clawdbot";
        url = "https://github.com/clawdbot/nix-clawdbot.git";
      }
      {
        name = "clawdhub";
        url = "https://github.com/clawdbot/clawdhub.git";
      }
      {
        name = "nix-steipete-tools";
        url = "https://github.com/clawdbot/nix-steipete-tools.git";
      }
    ];

    config = {
      gateway.mode = "local";
      agent.workspace = "/var/lib/clawd/workspace";
      agent.maxConcurrent = 4;
      agent.skipBootstrap = true;
      logging = {
        level = "info";
        file = "/var/lib/clawd/logs/clawdbot.log";
      };
      session.sendPolicy = {
        default = "allow";
        rules = [
          {
            action = "deny";
            match.keyPrefix = "agent:main:discord:channel:1458138963067011176";
          }
          {
            action = "deny";
            match.keyPrefix = "agent:main:discord:channel:1458141495701012561";
          }
        ];
      };
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
          "1456350064065904867" = {
            requireMention = false;
            channels = {
              # #clawdinators-test
              "1458426982579830908" = {
                allow = true;
                requireMention = false;
                autoReply = true;
              };
              # #clawdributors-test (lurk only; replies denied via sendPolicy)
              "1458138963067011176" = {
                allow = true;
                requireMention = false;
              };
              # #clawdributors (lurk only; replies denied via sendPolicy)
              "1458141495701012561" = {
                allow = true;
                requireMention = false;
              };
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
