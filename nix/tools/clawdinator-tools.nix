{ pkgs }:
{
  packages = [
    pkgs.gh
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.python3
    pkgs.ffmpeg
    pkgs.ripgrep
    pkgs.nodejs_22
    pkgs.pnpm_10
    pkgs.util-linux
    pkgs.nfs-utils
    pkgs.stunnel
  ];

  docs = [
    { name = "gh"; description = "GitHub CLI for repo + PR inventory."; }
    { name = "clawdbot-gateway"; description = "CLAWDINATOR runtime (Clawdbot gateway)."; }
    { name = "git"; description = "Repo sync + ops."; }
    { name = "curl"; description = "HTTP requests."; }
    { name = "jq"; description = "JSON processing."; }
    { name = "python3"; description = "Clawdbot dev chain dependency."; }
    { name = "ffmpeg"; description = "Media processing."; }
    { name = "ripgrep"; description = "Fast file search."; }
    { name = "nodejs_22"; description = "Clawdbot dev chain runtime."; }
    { name = "pnpm_10"; description = "Clawdbot dev chain package manager."; }
    { name = "util-linux"; description = "Provides flock used by memory wrappers."; }
    { name = "nfs-utils"; description = "NFS client utilities for EFS."; }
    { name = "stunnel"; description = "TLS tunnel for EFS in transit."; }
  ];
}
