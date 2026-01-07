# Shared Memory (Hive Mind)

All CLAWDINATORs share the same memory files. There is no per-instance prefix for shared memory.

POC recommendation:
- Use a shared host volume mounted at /var/lib/clawd on 1–5 hosts.
- Memory lives at /var/lib/clawd/memory.

File patterns:
- Daily notes can be per instance: YYYY-MM-DD_INSTANCE.md (merge later).
- Canonical knowledge (single shared files):
  - project.md (goals + non-negotiables)
  - architecture.md
  - ops.md
  - discord.md
  - whatsapp.md (if relevant)

Example layout:
```
~/clawd/
├── memory/
│ ├── project.md
│ ├── architecture.md
│ ├── discord.md
│ ├── whatsapp.md
│ └── 2026-01-06.md
```

AGENTS.md should reference key memory files explicitly (e.g., “For Discord context, also read memory/discord.md”).

Multi-host requirement:
- Use a shared filesystem or object storage sync with file locking.
- Keep canonical files authoritative; merge per-instance notes periodically.
