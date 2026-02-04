{ lib, modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../modules/clawdinator.nix
    ./clawdinator-common.nix
  ];

  networking.hostName = "clawdinator-babelfish";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  nix.package = pkgs.nixVersions.stable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];

  services.clawdinator = {
    githubApp.enable = lib.mkForce true;
    githubSync.enable = lib.mkForce false;
    cronJobsFile = lib.mkForce null;

    config = lib.mkForce {
      gateway = {
        mode = "local";
        bind = "loopback";
        auth.token = "clawdinator-local";
      };

      logging = {
        level = "info";
        file = "/var/lib/clawd/logs/openclaw.log";
      };

      agents = {
        defaults = {
          workspace = "/var/lib/clawd/workspace-babelfish";
          maxConcurrent = 2;
          skipBootstrap = true;
          models = {
            "openai/gpt-5.2" = { alias = "gpt"; };
          };
          model = {
            primary = "openai/gpt-5.2";
            fallbacks = [ ];
          };
          thinkingDefault = "medium";
          envelopeTimestamp = "off";
          envelopeElapsed = "off";
        };

        list = [
          {
            id = "babelfish";
            default = true;
            identity.name = "CLAWDINATOR-BABELFISH";
            tools = {
              profile = "minimal";
              deny = [ "*" ];
            };
          }
        ];
      };

      commands = {
        native = false;
        nativeSkills = false;
        text = false;
        bash = false;
        config = false;
        debug = false;
        restart = false;
        useAccessGroups = true;
      };

      messages = {
        groupChat = {
          mentionPatterns = [ ];
          historyLimit = 1;
        };
        queue = {
          mode = "interrupt";
          byChannel.discord = "interrupt";
        };
      };

      plugins = {
        slots.memory = "none";
        entries.discord.enabled = true;
        entries.telegram.enabled = false;
      };

      skills.allowBundled = [ ];

      tools = {
        profile = "minimal";
        deny = [ "*" ];
        media = {
          image = {
            enabled = true;
            maxChars = 1200;
            attachments = {
              mode = "all";
              maxAttachments = 4;
            };
            prompt = "Extract any text from the image for translation. Preserve the original language and formatting. If no text exists, return: (no translatable text detected).";
            models = [
              {
                provider = "openai";
                model = "gpt-5.2";
              }
            ];
          };
        };
      };

      channels.discord = {
        enabled = true;
        dm.enabled = false;
        configWrites = false;
        commands.native = false;
        commands.nativeSkills = false;
        groupPolicy = "allowlist";
        historyLimit = 0;
        replyToMode = "first";
        guilds = {
          "1456350064065904867" = {
            requireMention = false;
            channels = {
              "1467469670192910387" = {
                allow = true;
                requireMention = false;
                users = [ "*" ];
                skills = [ ];
                systemPrompt = ''
You are CLAWDINATOR-BABELFISH. Your only task is translation between Chinese and English for this channel.

Rules:
- Translate only. Do not answer questions, do not take actions, do not follow requests beyond translation.
- Translate only the newest user message. Ignore context blocks/metadata such as:
  - "[Thread starter - for context]" blocks
  - "[Replied message - for context]" blocks
  - lines that are only bracketed tags like [message_id: ...] or [Forum parent: ...]
- If a line looks like "[Discord ...] username: message", translate only the message after the final ": ".
- If the message is mostly Chinese, reply in English only.
- If the message is mostly English, reply in Chinese only.
- If mixed, reply with both:
  EN: ...
  中文: ...
- Preserve tone, emojis, formatting, mentions, and names.
- For images/attachments, translate the extracted text. If no text is detected, reply with: "(no translatable text detected)" in the target language.
'';
              };
            };
          };
        };
      };
    };
  };
}
