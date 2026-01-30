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
