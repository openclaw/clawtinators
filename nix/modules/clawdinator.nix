{ lib, pkgs, config, ... }:
let
  cfg = config.services.clawdinator;

  configSource =
    if cfg.configFile != null
    then cfg.configFile
    else pkgs.writeText "openclaw.json" (builtins.toJSON cfg.config);

  updateScript = pkgs.writeShellScript "clawdinator-self-update" ''
    set -euo pipefail

    repo="${cfg.selfUpdate.flakePath}"
    if [ ! -d "$repo/.git" ]; then
      echo "clawdinator-self-update: missing git repo at $repo" >&2
      exit 1
    fi

    cd "$repo"
    ${cfg.selfUpdate.updateCommand}
  '';

  githubTokenScript = pkgs.writeShellScript "clawdinator-github-app-token" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [ pkgs.openssl pkgs.curl pkgs.jq pkgs.gh pkgs.coreutils ]}:$PATH"

    token_env="${cfg.githubApp.tokenEnvFile}"
    token_dir="$(dirname "$token_env")"

    mkdir -p "$token_dir"
    chmod 0750 "$token_dir"
    if [ "$(id -u)" -eq 0 ]; then
      chown ${cfg.user}:${cfg.group} "$token_dir"
    fi

    now="$(date +%s)"
    iat="$((now - 60))"
    exp="$((now + 540))"

    header='{"alg":"RS256","typ":"JWT"}'
    payload="{\"iat\":$iat,\"exp\":$exp,\"iss\":\"${cfg.githubApp.appId}\"}"

    base64url() {
      openssl base64 -A | tr '+/' '-_' | tr -d '='
    }

    jwt_header="$(printf '%s' "$header" | base64url)"
    jwt_payload="$(printf '%s' "$payload" | base64url)"
    unsigned="''${jwt_header}.''${jwt_payload}"
    signature="$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "${cfg.githubApp.privateKeyFile}" | base64url)"
    jwt="''${unsigned}.''${signature}"

    resp="$(curl -sS -X POST \
      -H "Authorization: Bearer $jwt" \
      -H "Accept: application/vnd.github+json" \
      "${cfg.githubApp.apiUrl}/app/installations/${cfg.githubApp.installationId}/access_tokens")"

    token="$(printf '%s' "$resp" | jq -r '.token')"
    if [ -z "$token" ] || [ "$token" = "null" ]; then
      echo "clawdinator-github-app-token: failed to mint token" >&2
      echo "$resp" >&2
      exit 1
    fi

    umask 027
    printf 'GITHUB_APP_TOKEN=%s\nGITHUB_TOKEN=%s\nGH_TOKEN=%s\n' "$token" "$token" "$token" > "$token_env"
    if [ "$(id -u)" -eq 0 ]; then
      chown ${cfg.user}:${cfg.group} "$token_env"
    fi
    chmod 0640 "$token_env"

    gh_config_dir="${ghConfigDir}"
    mkdir -p "$gh_config_dir"
    chmod 0750 "$gh_config_dir"
    if [ "$(id -u)" -eq 0 ]; then
      chown ${cfg.user}:${cfg.group} "$gh_config_dir"
    fi
    printf '%s' "$token" | GH_CONFIG_DIR="$gh_config_dir" gh auth login --hostname github.com --with-token
    if [ "$(id -u)" -eq 0 ]; then
      chown -R ${cfg.user}:${cfg.group} "$gh_config_dir"
    fi
    chmod 0640 "$gh_config_dir/hosts.yml"
    if [ -f "$gh_config_dir/config.yml" ]; then
      chmod 0640 "$gh_config_dir/config.yml"
    fi
  '';

  defaultPackage =
    if pkgs ? openclaw-gateway
    then pkgs.openclaw-gateway
    else pkgs.openclaw;

  gatewayBin =
    if builtins.pathExists "${cfg.package}/bin/openclaw"
    then "${cfg.package}/bin/openclaw"
    else "${cfg.package}/bin/moltbot";

  configPath = "/etc/clawd/openclaw.json";
  workspaceDir = "${cfg.stateDir}/workspace";
  repoSeedBaseDir = cfg.repoSeedBaseDir;
  logDir = "${cfg.stateDir}/logs";
  ghConfigDir = "${cfg.stateDir}/gh";
  repoSeedsFile = pkgs.writeText "clawdinator-repos.tsv"
    (lib.concatMapStringsSep "\n"
      (repo:
        let
          branch = if repo.branch == null then "" else repo.branch;
        in
        "${repo.name}\t${repo.url}\t${branch}")
      cfg.repoSeeds);
  toolchain = import ../tools/clawdinator-tools.nix { inherit pkgs; };
  toolchainMd = lib.concatMapStringsSep "\n"
    (tool: "- **${tool.name}** — ${tool.description}")
    toolchain.docs;

  tokenWrapper =
    if cfg.anthropicApiKeyFile != null || cfg.discordTokenFile != null || cfg.githubPatFile != null || cfg.openaiApiKeyFile != null || cfg.telegramAllowFromFile != null then
      pkgs.writeShellScriptBin "clawdinator-gateway" ''
        set -euo pipefail

        read_token() {
          local names="$1"
          local path="$2"
          if [ -z "$path" ] || [ "$path" = "null" ]; then
            return 0
          fi
          if [ ! -f "$path" ]; then
            echo "clawdinator: token file not found: $path" >&2
            exit 1
          fi
          local value
          value="$(cat "$path")"
          if [ -z "$value" ]; then
            echo "clawdinator: token file is empty: $path" >&2
            exit 1
          fi
          for name in $names; do
            export "$name=$value"
          done
        }

        ${lib.optionalString (cfg.anthropicApiKeyFile != null) "read_token ANTHROPIC_API_KEY \"${cfg.anthropicApiKeyFile}\""}
        ${lib.optionalString (cfg.discordTokenFile != null) "read_token DISCORD_BOT_TOKEN \"${cfg.discordTokenFile}\""}
        ${lib.optionalString (cfg.githubPatFile != null) "read_token \"GITHUB_TOKEN GH_TOKEN\" \"${cfg.githubPatFile}\""}
        ${lib.optionalString (cfg.openaiApiKeyFile != null) "read_token \"OPENAI_API_KEY OPEN_AI_APIKEY\" \"${cfg.openaiApiKeyFile}\""}
        ${lib.optionalString (cfg.telegramAllowFromFile != null) "read_token CLAWDINATOR_TELEGRAM_ALLOW_FROM \"${cfg.telegramAllowFromFile}\""}

        exec "${gatewayBin}" gateway --port ${toString cfg.gatewayPort}
      ''
    else
      null;
in
{
  options.services.clawdinator = with lib; {
    enable = mkEnableOption "CLAWDINATOR (Clawbot gateway on NixOS)";

    instanceName = mkOption {
      type = types.str;
      default = "CLAWDINATOR-1";
      description = "Human-readable instance name (used in config examples).";
    };

    user = mkOption {
      type = types.str;
      default = "clawdinator";
      description = "System user for the gateway.";
    };

    group = mkOption {
      type = types.str;
      default = "clawdinator";
      description = "System group for the gateway.";
    };

    package = mkOption {
      type = types.package;
      default = defaultPackage;
      description = "Clawbot gateway package (from nix-openclaw overlay).";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/clawd";
      description = "Base state directory for CLAWDINATOR.";
    };

    memoryDir = mkOption {
      type = types.str;
      default = "/var/lib/clawd/memory";
      description = "Shared hive-mind memory directory.";
    };

    memoryEfs = {
      enable = mkEnableOption "EFS-backed shared memory mount";
      fileSystemId = mkOption {
        type = types.str;
        default = "";
        description = "EFS file system ID (fs-...).";
      };
      region = mkOption {
        type = types.str;
        default = "eu-central-1";
        description = "AWS region for the EFS DNS name.";
      };
      mountPoint = mkOption {
        type = types.str;
        default = "/memory";
        description = "Mount point for EFS shared memory.";
      };
    };

    repoSeedBaseDir = mkOption {
      type = types.str;
      default = "/var/lib/clawd/repos";
      description = "Base directory for seeded git repos.";
    };

    repoSeeds = mkOption {
      type = types.listOf (types.submodule ({ ... }: {
        options = {
          name = mkOption {
            type = types.str;
            description = "Repo directory name (under repoSeedBaseDir).";
          };
          url = mkOption {
            type = types.str;
            description = "Git clone URL.";
          };
          branch = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional branch to track.";
          };
        };
      }));
      default = [];
      description = "Repos to seed into repoSeedBaseDir on startup.";
    };

    repoSeedSnapshotDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional path to a preseeded repo snapshot (directory of repos). When set, no network cloning happens at boot.";
    };

    bootstrap = {
      enable = mkEnableOption "Bootstrap secrets + repo seeds from S3";

      s3Bucket = mkOption {
        type = types.str;
        description = "S3 bucket holding bootstrap artifacts.";
      };

      s3Prefix = mkOption {
        type = types.str;
        default = "bootstrap/${cfg.instanceName}";
        description = "S3 prefix for bootstrap artifacts (relative to bucket).";
      };

      region = mkOption {
        type = types.str;
        default = "eu-central-1";
        description = "AWS region for S3 bootstrap bucket.";
      };

      secretsArchive = mkOption {
        type = types.str;
        default = "secrets.tar.zst";
        description = "Secrets archive name inside the bootstrap prefix.";
      };

      repoSeedsArchive = mkOption {
        type = types.str;
        default = "repo-seeds.tar.zst";
        description = "Repo seeds archive name inside the bootstrap prefix.";
      };

      ageKeyPath = mkOption {
        type = types.str;
        default = "/etc/agenix/keys/clawdinator.agekey";
        description = "Destination path for the agenix identity key.";
      };

      secretsDir = mkOption {
        type = types.str;
        default = "/var/lib/clawd/nix-secrets";
        description = "Destination directory for encrypted age secrets.";
      };

      repoSeedsDir = mkOption {
        type = types.str;
        default = "/var/lib/clawd/repo-seeds";
        description = "Destination directory for repo seed snapshots.";
      };
    };

    workspaceTemplateDir = mkOption {
      type = types.path;
      default = ../../clawdinator/workspace;
      description = "Template directory for seeding the agent workspace.";
    };

    gatewayPort = mkOption {
      type = types.port;
      default = 18789;
      description = "Gateway port for Moltbot.";
    };

    config = mkOption {
      type = types.attrs;
      default = {};
      description = "Raw Clawbot config JSON (merged into openclaw.json).";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional path to an openclaw.json config file. Overrides config attr.";
    };

    cronJobsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional path to a cron jobs JSON file (deployed to /etc/clawd/cron-jobs.json).";
    };

    anthropicApiKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing Anthropic API key (plain text).";
    };

    openaiApiKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing OpenAI API key (plain text).";
    };

    discordTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing Discord bot token (plain text).";
    };

    telegramAllowFromFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing Telegram allowFrom entry (plain text).";
    };

    githubPatFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing GitHub PAT (read-only).";
    };

    selfUpdate = {
      enable = mkEnableOption "self-update (nix flake update + nixos-rebuild)";

      schedule = mkOption {
        type = types.str;
        default = "daily";
        description = "systemd OnCalendar schedule for self-update.";
      };

      flakePath = mkOption {
        type = types.str;
        default = "/var/lib/clawd/repo";
        description = "Path to this repo on the host (used for flake updates).";
      };

      flakeHost = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "NixOS configuration name for nixos-rebuild.";
      };

      updateCommand = mkOption {
        type = types.str;
        default = ''
          nix flake update
          nixos-rebuild switch --flake "${cfg.selfUpdate.flakePath}#${cfg.selfUpdate.flakeHost}"
        '';
        description = "Command run by the self-update timer.";
      };
    };

    githubApp = {
      enable = mkEnableOption "GitHub App token minting (short-lived access tokens)";

      appId = mkOption {
        type = types.str;
        default = "";
        description = "GitHub App ID (issuer for JWT).";
      };

      installationId = mkOption {
        type = types.str;
        default = "";
        description = "GitHub App installation ID.";
      };

      privateKeyFile = mkOption {
        type = types.str;
        default = "/etc/clawd/github-app.pem";
        description = "Path to GitHub App private key (PEM).";
      };

      tokenEnvFile = mkOption {
        type = types.str;
        default = "/run/clawd/github-app.env";
        description = "Environment file containing GITHUB_APP_TOKEN.";
      };

      apiUrl = mkOption {
        type = types.str;
        default = "https://api.github.com";
        description = "GitHub API base URL.";
      };

      schedule = mkOption {
        type = types.str;
        default = "hourly";
        description = "systemd OnCalendar schedule to refresh installation token.";
      };
    };

    githubSync = {
      enable = mkEnableOption "GitHub org sync (PRs and issues to memory)";

      schedule = mkOption {
        type = types.str;
        default = "*:0/15";
        description = "systemd OnCalendar schedule for GitHub sync (default: every 15 min).";
      };

      org = mkOption {
        type = types.str;
        default = "openclaw";
        description = "GitHub org to sync.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.substituters = lib.mkAfter [
      "https://cache.garnix.io"
    ];
    nix.settings.trusted-public-keys = lib.mkAfter [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];

    assertions = [
      {
        assertion = (pkgs ? openclaw-gateway) || (pkgs ? openclaw);
        message = "services.clawdinator requires nix-openclaw overlay (pkgs.openclaw-gateway).";
      }
      {
        assertion = cfg.githubApp.enable || cfg.githubPatFile != null;
        message = "services.clawdinator requires a GitHub token (enable githubApp or set githubPatFile).";
      }
      {
        assertion = (!cfg.githubApp.enable) || (cfg.githubApp.appId != "" && cfg.githubApp.installationId != "");
        message = "services.clawdinator.githubApp requires appId and installationId.";
      }
      {
        assertion = (!cfg.memoryEfs.enable) || (cfg.memoryEfs.fileSystemId != "");
        message = "services.clawdinator.memoryEfs requires fileSystemId.";
      }
    ];

    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.stateDir;
      createHome = true;
      shell = pkgs.bashInteractive;
    };

    programs.git = {
      enable = true;
      config = {
        user = {
          name = "CLAWDINATOR Bot";
          email = "clawdinator[bot]@users.noreply.github.com";
        };
      };
    };

    environment.systemPackages =
      [ cfg.package ]
      ++ toolchain.packages
      ++ [
        (pkgs.writeShellScriptBin "memory-read" ''exec /etc/clawdinator/bin/memory-read "$@"'')
        (pkgs.writeShellScriptBin "memory-write" ''exec /etc/clawdinator/bin/memory-write "$@"'')
        (pkgs.writeShellScriptBin "memory-edit" ''exec /etc/clawdinator/bin/memory-edit "$@"'')
        (pkgs.writeShellScriptBin "clawdinator-gh-refresh" ''exec ${githubTokenScript}'')
      ];

    environment.etc."clawd/openclaw.json".source = configSource;
    environment.etc."clawd/cron-jobs.json" = lib.mkIf (cfg.cronJobsFile != null) {
      source = cfg.cronJobsFile;
      mode = "0644";
    };
    environment.etc."clawdinator/bin/memory-read" = {
      source = ../../scripts/memory-read.sh;
      mode = "0755";
    };
    environment.etc."clawdinator/bin/memory-write" = {
      source = ../../scripts/memory-write.sh;
      mode = "0755";
    };
    environment.etc."clawdinator/bin/memory-edit" = {
      source = ../../scripts/memory-edit.sh;
      mode = "0755";
    };
    environment.etc."clawdinator/tools.md" = {
      mode = "0644";
      text = ''
        ## Installed Toolchain (Nix)

        ${toolchainMd}

        ## Local scripts (installed by Nix)
        - **memory-read** — shared-lock read from `/memory`.
        - **memory-write** — exclusive-lock write to `/memory`.
        - **memory-edit** — exclusive-lock in-place edit for `/memory`.
        - **clawdinator-gh-refresh** — mint GitHub App token + refresh GH auth (no sudo).
      '';
    };
    environment.etc."clawdinator/pi-settings.json" = {
      mode = "0644";
      source = ../../clawdinator/pi-settings.json;
    };
    environment.etc."stunnel/efs.conf" = lib.mkIf cfg.memoryEfs.enable {
      mode = "0644";
      text = ''
        foreground = yes
        pid = /run/stunnel-efs.pid
        client = yes

        [efs]
        accept = 127.0.0.1:2049
        connect = ${cfg.memoryEfs.fileSystemId}.efs.${cfg.memoryEfs.region}.amazonaws.com:2049
        verifyChain = yes
        CAfile = ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      '';
    };

    system.activationScripts.agenixInstall.text = lib.mkIf cfg.bootstrap.enable (
      let
        secrets = lib.attrValues config.age.secrets;
        secretFiles = lib.concatMapStringsSep " " (secret: "\"${secret.file}\"") secrets;
        chownLines = lib.concatMapStringsSep "\n"
          (secret:
            let
              path = secret.path;
              owner = if secret.owner == null then "root" else secret.owner;
              group = if secret.group == null then "root" else secret.group;
            in
            lib.optionalString (path != null) ''
              if [ -e "${path}" ]; then
                chown ${owner}:${group} "${path}"
              fi
            '')
          secrets;
      in
      lib.mkMerge [
        (lib.mkBefore ''
          found=0
          for file in ${secretFiles}; do
            if [ -f "$file" ]; then
              found=1
              break
            fi
          done
          if [ "$found" -eq 0 ]; then
            echo "[agenix] no encrypted secrets present; skipping install"
          else
        '')
        (lib.mkAfter ''
          fi
          ${chownLines}
        '')
      ]
    );

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.stateDir}/.pi 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.stateDir}/.pi/agent 0750 ${cfg.user} ${cfg.group} - -"
      "L+ ${cfg.stateDir}/.pi/agent/settings.json - - - - /etc/clawdinator/pi-settings.json"
      "d ${workspaceDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${logDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${ghConfigDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d /run/clawd 0750 ${cfg.user} ${cfg.group} - -"
      "z /run/clawd 0750 ${cfg.user} ${cfg.group} - -"
      "f /run/clawd/github-app.env 0640 ${cfg.user} ${cfg.group} - -"
      "z /run/clawd/github-app.env 0640 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.memoryDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${repoSeedBaseDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d /usr/local/bin 0755 root root - -"
      "L+ /usr/local/bin/memory-read - - - - /etc/clawdinator/bin/memory-read"
      "L+ /usr/local/bin/memory-write - - - - /etc/clawdinator/bin/memory-write"
      "L+ /usr/local/bin/memory-edit - - - - /etc/clawdinator/bin/memory-edit"
    ];

    fileSystems = lib.mkIf cfg.memoryEfs.enable {
      "${cfg.memoryEfs.mountPoint}" = {
        device = "127.0.0.1:/";
        fsType = "nfs4";
        options = [
          "nfsvers=4.1"
          "rsize=1048576"
          "wsize=1048576"
          "hard"
          "timeo=600"
          "retrans=2"
          "noresvport"
          "x-systemd.requires=clawdinator-efs-stunnel.service"
          "x-systemd.after=clawdinator-efs-stunnel.service"
        ];
      };
    };

    systemd.services.clawdinator = {
      description = "CLAWDINATOR (Moltbot gateway)";
      wantedBy = [ "multi-user.target" ];
      after =
        [ "network.target" ]
        ++ lib.optional cfg.bootstrap.enable "clawdinator-bootstrap.service"
        ++ lib.optional cfg.bootstrap.enable "clawdinator-agenix.service"
        ++ lib.optional cfg.githubApp.enable "clawdinator-github-app-token.service"
        ++ lib.optional (cfg.repoSeedSnapshotDir != null) "clawdinator-repo-seed.service"
        ++ lib.optional (cfg.openaiApiKeyFile != null && cfg.anthropicApiKeyFile != null) "clawdinator-pi-auth.service";
      wants =
        lib.optional cfg.bootstrap.enable "clawdinator-bootstrap.service"
        ++ lib.optional cfg.bootstrap.enable "clawdinator-agenix.service"
        ++ lib.optional cfg.githubApp.enable "clawdinator-github-app-token.service"
        ++ lib.optional (cfg.repoSeedSnapshotDir != null) "clawdinator-repo-seed.service"
        ++ lib.optional (cfg.openaiApiKeyFile != null && cfg.anthropicApiKeyFile != null) "clawdinator-pi-auth.service";

      environment = {
        CLAWDBOT_CONFIG_PATH = configPath;
        CLAWDBOT_STATE_DIR = cfg.stateDir;
        CLAWDBOT_WORKSPACE_DIR = workspaceDir;
        CLAWDBOT_LOG_DIR = logDir;
        GH_CONFIG_DIR = ghConfigDir;

        # Backward-compatible env names used by some builds.
        CLAWDIS_CONFIG_PATH = configPath;
        CLAWDIS_STATE_DIR = cfg.stateDir;
      };

      path = [ pkgs.coreutils pkgs.git pkgs.rsync ] ++ toolchain.packages;
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStartPre =
          lib.optionals (cfg.repoSeedSnapshotDir == null) [
            "${pkgs.bash}/bin/bash ${../../scripts/seed-repos.sh} ${repoSeedsFile} ${repoSeedBaseDir}"
          ]
          ++ [
            "${pkgs.bash}/bin/bash ${../../scripts/seed-workspace.sh} ${cfg.workspaceTemplateDir} ${workspaceDir}"
          ];
        ExecStart =
          if tokenWrapper != null
          then "${tokenWrapper}/bin/clawdinator-gateway"
          else "${gatewayBin} gateway --port ${toString cfg.gatewayPort}";
        Restart = "always";
        RestartSec = 2;
        StandardOutput = "append:${logDir}/gateway.log";
        StandardError = "append:${logDir}/gateway.log";
      };
    };

    systemd.services.clawdinator-repo-seed = lib.mkIf (cfg.repoSeedSnapshotDir != null) {
      description = "CLAWDINATOR repo seed (snapshot copy)";
      wantedBy = [ "multi-user.target" ];
      before = [ "clawdinator.service" ];
      after =
        [ "local-fs.target" ]
        ++ lib.optional cfg.bootstrap.enable "clawdinator-bootstrap.service";
      requires = lib.optional cfg.bootstrap.enable "clawdinator-bootstrap.service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.rsync pkgs.coreutils ];
      script = "${pkgs.bash}/bin/bash ${../../scripts/seed-repos-from-snapshot.sh} ${cfg.repoSeedSnapshotDir} ${repoSeedBaseDir} ${cfg.user} ${cfg.group}";
    };

    systemd.services.clawdinator-bootstrap = lib.mkIf cfg.bootstrap.enable {
      description = "CLAWDINATOR bootstrap (S3 secrets + repo seeds)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "amazon-init.service" ];
      wants = [ "network-online.target" "amazon-init.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment = {
        AWS_REGION = cfg.bootstrap.region;
        AWS_DEFAULT_REGION = cfg.bootstrap.region;
      };
      path = [ pkgs.awscli2 pkgs.coreutils pkgs.gnutar pkgs.zstd ];
      script = "${pkgs.bash}/bin/bash ${../../scripts/bootstrap-runtime.sh} ${cfg.bootstrap.s3Bucket} ${cfg.bootstrap.s3Prefix} ${cfg.bootstrap.secretsDir} ${cfg.bootstrap.repoSeedsDir} ${cfg.bootstrap.ageKeyPath} ${cfg.bootstrap.secretsArchive} ${cfg.bootstrap.repoSeedsArchive}";
    };

    systemd.services.clawdinator-agenix = lib.mkIf cfg.bootstrap.enable {
      description = "CLAWDINATOR agenix (post-bootstrap activation)";
      wantedBy = [ "multi-user.target" ];
      after = [ "clawdinator-bootstrap.service" ];
      wants = [ "clawdinator-bootstrap.service" ];
      unitConfig = {
        ConditionPathExists = "!/run/agenix";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/run/current-system/bin/switch-to-configuration switch";
      };
    };

    systemd.services.agenix = lib.mkIf cfg.bootstrap.enable {
      requires = [ "clawdinator-bootstrap.service" ];
      after = [ "clawdinator-bootstrap.service" ];
    };

    systemd.services.clawdinator-efs-stunnel = lib.mkIf cfg.memoryEfs.enable {
      description = "CLAWDINATOR EFS TLS tunnel";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.stunnel}/bin/stunnel /etc/stunnel/efs.conf";
        Restart = "always";
      };
    };

    systemd.services.clawdinator-memory-init = lib.mkIf cfg.memoryEfs.enable {
      description = "CLAWDINATOR memory directory init";
      wantedBy = [ "multi-user.target" ];
      after = [ "remote-fs.target" ];
      wants = [ "remote-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${../../scripts/init-memory.sh} ${cfg.memoryEfs.mountPoint} ${cfg.user} ${cfg.group}";
      };
    };

    systemd.services.clawdinator-self-update = lib.mkIf cfg.selfUpdate.enable {
      description = "CLAWDINATOR self-update (flake update + rebuild)";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.git pkgs.nix pkgs.coreutils ];
      script = "${updateScript}";
    };

    systemd.timers.clawdinator-self-update = lib.mkIf cfg.selfUpdate.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.selfUpdate.schedule;
        Persistent = true;
      };
    };

    systemd.services.clawdinator-github-app-token = lib.mkIf cfg.githubApp.enable {
      description = "CLAWDINATOR GitHub App token refresh";
      wantedBy = [ "multi-user.target" ];
      before = [ "clawdinator.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
      };
      path = [ pkgs.openssl pkgs.curl pkgs.jq pkgs.coreutils pkgs.gh ];
      script = "${githubTokenScript}";
    };

    systemd.services.clawdinator-pi-auth = lib.mkIf (cfg.openaiApiKeyFile != null && cfg.anthropicApiKeyFile != null) {
      description = "CLAWDINATOR Pi auth.json seed";
      wantedBy = [ "multi-user.target" ];
      after = [ "clawdinator-agenix.service" ];
      wants = [ "clawdinator-agenix.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart =
          let
            outputPath = "${cfg.stateDir}/.pi/agent/auth.json";
            openaiKey = cfg.openaiApiKeyFile;
            anthropicKey = cfg.anthropicApiKeyFile;
          in
          "${pkgs.bash}/bin/bash ${../../scripts/pi-auth.sh} ${lib.escapeShellArg outputPath} ${lib.escapeShellArg openaiKey} ${lib.escapeShellArg anthropicKey}";
      };
      path = [ pkgs.coreutils pkgs.jq ];
    };

    systemd.timers.clawdinator-github-app-token = lib.mkIf cfg.githubApp.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.githubApp.schedule;
        Persistent = true;
      };
    };

    systemd.services.clawdinator-github-sync = lib.mkIf cfg.githubSync.enable {
      description = "CLAWDINATOR GitHub org sync (PRs/issues to memory)";
      after =
        [ "network-online.target" ]
        ++ lib.optional cfg.githubApp.enable "clawdinator-github-app-token.service"
        ++ lib.optional cfg.memoryEfs.enable "remote-fs.target"
        ++ lib.optional cfg.memoryEfs.enable "clawdinator-memory-init.service";
      wants =
        [ "network-online.target" ]
        ++ lib.optional cfg.memoryEfs.enable "remote-fs.target";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        EnvironmentFile = lib.optional cfg.githubApp.enable "-${cfg.githubApp.tokenEnvFile}";
      };
      path = [ pkgs.bash pkgs.gh pkgs.jq pkgs.coreutils pkgs.gnused ];
      environment = {
        MEMORY_DIR = cfg.memoryDir;
        ORG = cfg.githubSync.org;
      };
      script = ''
        exec ${../../scripts/gh-sync.sh}
      '';
    };

    systemd.timers.clawdinator-github-sync = lib.mkIf cfg.githubSync.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.githubSync.schedule;
        Persistent = true;
      };
    };
  };
}
