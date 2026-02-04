# Ops Memory

Operational runbook notes and gotchas.

- Keep secrets in agenix; rekey when host SSH keys rotate.
- Use nixos-anywhere for first install, then self-update timer for upgrades.

Update with incidents, fixes, and operational lessons.

## 2026-01-29
- AMI: ami-0b6acad77477abc33 (clawdinators 063b573, nix-openclaw 8ff02aae; extensions packaged).
- Instance: i-0e6125bd57991c5cc (IP 3.75.198.206, DNS ec2-3-75-198-206.eu-central-1.compute.amazonaws.com).
- Discord plugin now loads via packaged extensions; config includes plugins.entries.discord.enabled.
- Note: Discord gateway logged intermittent code 1006 closes; `openclaw doctor` reports Discord ok.

## 2026-02-01
- AMI: ami-003e9e3a97f875f63 (t3.large rebuild; swap + git identity baked).
- Instance: i-077b9075e32a3b8f7 (IP 3.121.98.87, DNS ec2-3-121-98-87.eu-central-1.compute.amazonaws.com).

## 2026-02-02
- AMI: ami-047e0e6354df0f87e (pi coding agent + OpenAI API defaults).
- Instance: i-0d1b0e288dd70273b (IP 3.73.1.102, DNS ec2-3-73-1-102.eu-central-1.compute.amazonaws.com).

## 2026-02-03
- AMI: ami-027054fbbee8d71cc (multi-instance fleet).
- Instances:
  - clawdinator-1: i-0b6060699bb413d82 (IP 18.198.25.107, DNS ec2-18-198-25-107.eu-central-1.compute.amazonaws.com).
  - clawdinator-2: i-07bcba2bb924dfc93 (IP 3.66.165.141, DNS ec2-3-66-165-141.eu-central-1.compute.amazonaws.com).

## 2026-02-04
- clawdinator-2 booted without /etc/ec2-metadata/user-data, so amazon-init skipped user-data and clawdinator stayed inactive.
- Manual recovery: fetch IMDS user-data, rerun user-data script, set git safe.directory, set transient hostname.
- Fix: add fetch-ec2-metadata systemd unit to AMI config + git safe.directory in programs.git.
- AMI: ami-0ae43cb24200e1665 (user-data oneshot restart + wait loop).
- Instance: clawdinator-2: i-00fe5c0c6372baaf3 (IP 54.93.75.82, DNS ec2-54-93-75-82.eu-central-1.compute.amazonaws.com).
- Note: amazon-init completed; clawdinator active; transient hostname still clawdinator-1 (static clawdinator-2).
