{ lib, modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../modules/clawdinator.nix
    ./clawdinator-common.nix
  ];

  networking.hostName = "clawdinator-2";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  nix.package = pkgs.nixVersions.stable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];
}
