{ modulesPath, config, ... }: {
  imports = [
    (modulesPath + "/virtualisation/ec2-data.nix")
    (modulesPath + "/virtualisation/amazon-init.nix")
    ../modules/clawdinator.nix
    ./clawdinator-1-common.nix
  ];

  networking.hostName = "clawdinator-1";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  boot.initrd.availableKernelModules = [ "nvme" ];
  boot.initrd.kernelModules = [ "xen-blkfront" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.ena ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.useDHCP = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  assertions = [
    {
      assertion = (builtins.getEnv "CLAWDINATOR_AGE_KEY") != "";
      message = "CLAWDINATOR_AGE_KEY must be set when building the image.";
    }
    {
      assertion = (builtins.getEnv "CLAWDINATOR_SECRETS_DIR") != "";
      message = "CLAWDINATOR_SECRETS_DIR must point at encrypted age secrets.";
    }
    {
      assertion = (builtins.getEnv "CLAWDINATOR_REPO_SEEDS_DIR") != "";
      message = "CLAWDINATOR_REPO_SEEDS_DIR must point at preseeded repos.";
    }
  ];

  environment.etc."agenix/keys/clawdinator.agekey" = {
    text = builtins.getEnv "CLAWDINATOR_AGE_KEY";
    mode = "0400";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  clawdinator.secretsPath = toString (builtins.path {
    path = builtins.toPath (builtins.getEnv "CLAWDINATOR_SECRETS_DIR");
    name = "clawdinator-age-secrets";
  });

  services.clawdinator.repoSeedSnapshotDir =
    let
      seedsDir = builtins.getEnv "CLAWDINATOR_REPO_SEEDS_DIR";
    in
    if seedsDir == ""
    then null
    else builtins.path {
      path = builtins.toPath seedsDir;
      name = "clawdinator-repo-seeds";
    };
}
