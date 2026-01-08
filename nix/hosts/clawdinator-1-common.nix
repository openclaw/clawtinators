{ lib, config, ... }:
let
  secretsPath = config.clawdinator.secretsPath;
  repoSeedsFile = ../../clawdinator/repos.tsv;
  repoSeedLines =
    lib.filter
      (line: line != "" && !lib.hasPrefix "#" line)
      (map lib.strings.trim (lib.splitString "\n" (lib.fileContents repoSeedsFile)));
  parseRepoSeed = line:
    let
      parts = lib.splitString "\t" line;
      name = lib.elemAt parts 0;
      url = lib.elemAt parts 1;
      branch =
        if (lib.length parts) > 2 && (lib.elemAt parts 2) != ""
        then lib.elemAt parts 2
        else null;
    in
    { inherit name url branch; };
  repoSeeds = map parseRepoSeed repoSeedLines;
in
{
  options.clawdinator.secretsPath = lib.mkOption {
    type = lib.types.str;
    description = "Path to encrypted age secrets for CLAWDINATOR.";
  };

  config = {
    age.identityPaths = [ "/etc/agenix/keys/clawdinator.agekey" ];
    age.secrets."clawdinator-github-app.pem" = {
      file = "${secretsPath}/clawdinator-github-app.pem.age";
      owner = "clawdinator";
      group = "clawdinator";
    };
    age.secrets."clawdinator-anthropic-api-key" = {
      file = "${secretsPath}/clawdinator-anthropic-api-key.age";
      owner = "clawdinator";
      group = "clawdinator";
    };
    age.secrets."clawdinator-discord-token" = {
      file = "${secretsPath}/clawdinator-discord-token.age";
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
      repoSeeds = repoSeeds;

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

      githubSync.enable = true;
    };
  };
}
