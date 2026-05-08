---
name: Review severity for personal shell installers
description: Calibration rules for code reviews of shell scripts in ~/dotfiles/bin/.local/bin/ — installers and personal CLI tooling on a single-user workstation
type: feedback
---

When reviewing personal shell installers (e.g. `quarto-update`, `positron-update`, `rv-update`) under `~/dotfiles/bin/.local/bin/`, do NOT raise the following finding patterns:

- Defensive branching to distinguish "first install" / "parse failure" / "normal" cases on a single-user workstation where the tool is already installed
- Supply-chain concerns about checksums served from the same origin as the binary, when the upstream vendor publishes no detached signature (TLS is the only available trust root — note as informational only, no code change possible)
- Non-TTY safety (progress bar control characters, log redirection) for installers that are interactive-only by design and have no cron/systemd usage
- `sudo -v` ticket expiration during long downloads — sudo default timeout (15 min) >> typical download time, reprompt is acceptable UX even if it fired
- Cosmetic header tweaks (e.g. adding `Accept: application/vnd.github+json`) when the existing API call already returns the expected payload
- Implicit dependency prechecks for tools already provisioned in the deployment baseline (`curl`, `jq`, coreutils) — confirmed present on both workstation and target servers
- GitHub API unauthenticated-rate-limit concerns for manually-invoked scripts (a few invocations/month per user, 60 req/h is never approached)
- TOCTOU between checksum verify and `sudo dpkg -i` when the work directory is `mktemp -d` (mode 0700, user-owned) — no cross-user attack surface
- Vendor-CDN URL-structure fragility (e.g. `${CDN}/deb/${arch}/...` path assumption) when `curl -f` already produces a loud 404 on schema change — fail-bruyant is acceptable
- Fail-fast ordering preferences (e.g. "move the arch check before the network call") when the reviewer themselves acknowledge no correctness consequence — cosmetic fail-order is not a required fix
- Redundant explicit error handling (`|| { echo ...; exit 1; }`) for commands already covered by `set -euo pipefail` — the pipeline failure mode is already handled; the explicit handler adds noise, not safety

**Why:** these scripts target a known deployment surface (the user's workstation + multi-user servers running the same dotfiles). Threat model excludes cross-UID attackers on the work directory, and operational reality excludes high-frequency automated invocation. Real concerns are functional bugs, not theoretical hardening.

**How to apply:** when reviewing files matching `~/dotfiles/bin/.local/bin/*-update` or similar shell installers, drop these finding categories before reporting. **Multi-arch portability IS in scope** — these scripts are deployed on multi-user servers per `project_rv_install_deployment.md`, so `amd64`-only assumptions are real bugs. Real bugs that remain in scope: parsing fragility, swallowed exit codes (e.g. trap losing `$?` on cleanup failure), misleading user-facing messages, missing rollback paths, hardcoded arch on a multi-arch deployment surface.
