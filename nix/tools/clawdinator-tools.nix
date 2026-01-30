{ pkgs }:
{
  packages = [
    pkgs.bash
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
    pkgs.awscli2
    pkgs.zstd
  ];

  docs = [
    { name = "bash"; description = "Shell runtime for CLAWDINATOR scripts."; }
    { name = "gh"; description = "GitHub CLI for repo + PR inventory."; }
    { name = "openclaw-gateway"; description = "CLAWDINATOR runtime (Clawbot gateway)."; }
    { name = "git"; description = "Repo sync + ops."; }
    { name = "curl"; description = "HTTP requests."; }
    { name = "jq"; description = "JSON processing."; }
    { name = "python3"; description = "Moltbot dev chain dependency."; }
    { name = "ffmpeg"; description = "Media processing."; }
    { name = "ripgrep"; description = "Fast file search."; }
    { name = "nodejs_22"; description = "Moltbot dev chain runtime."; }
    { name = "pnpm_10"; description = "Moltbot dev chain package manager."; }
    { name = "util-linux"; description = "Provides flock used by memory wrappers."; }
    { name = "nfs-utils"; description = "NFS client utilities for EFS."; }
    { name = "stunnel"; description = "TLS tunnel for EFS in transit."; }
    { name = "awscli2"; description = "AWS CLI for bootstrap S3 pulls."; }
    { name = "zstd"; description = "Compression tool for bootstrap archives."; }
  ];
}
