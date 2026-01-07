{ pkgs, ... }:
{
  packages = [
    pkgs.nixos-generators
    pkgs.awscli2
    pkgs.curl
  ];
}
