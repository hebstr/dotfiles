---
name: dotfiles install scripts deployment context
description: rv-install and quarto-update are stored in dotfiles but deployed on multi-user servers; affects threat model and portability requirements
type: project
---
`bin/.local/bin/rv-install` (rv R-package-manager installer wrapper) and `bin/.local/bin/quarto-update` (Quarto release updater) are stored in this dotfiles repo but are deployed and executed in practice on multi-user servers, single ad-hoc execution per host.

**Why:** the user works on shared servers (likely HPC or institutional infra) where these tools have to be bootstrapped or upgraded into system-level paths (e.g., `/usr/local/bin/rv-install`, `/opt/quarto`). The dotfiles location is just where the source lives, not where it runs.

**How to apply:**
- Threat model: assume multi-user host, unprivileged attackers (no root). Per-file permissions matter (`mktemp` mode `0600` blocks modification), but blast-radius arguments for upstream-trust issues (`curl | bash`, missing GPG verification) are *broader* than for a single-user laptop.
- Portability: do not assume amd64. Multi-user server fleets may include ARM (Graviton, Ampere) — install scripts must detect via `uname -m` rather than hardcode the architecture.
- Do not reject security findings on these scripts with "personal machine, no attackers" — that framing is wrong for this artifact class.
- Pinning installer URLs to a release tag (rather than `main` or `latest` without verification) is more valuable here than on a laptop: a single upstream compromise window affects every user the script bootstraps for.
