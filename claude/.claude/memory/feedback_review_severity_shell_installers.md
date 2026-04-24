---
name: Review severity for personal shell installers
description: Calibration rules for code reviews of shell scripts in ~/dotfiles/bin/.local/bin/ — installers and personal CLI tooling on a single-user workstation
type: feedback
---

When reviewing personal shell installers (e.g. `quarto-update`, `positron-update`) under `~/dotfiles/bin/.local/bin/`, do NOT raise the following finding patterns:

- Defensive branching to distinguish "first install" / "parse failure" / "normal" cases on a single-user workstation where the tool is already installed
- Multi-arch portability concerns (`ARCH` variable abstraction, x64→arm64 lookup) when the host is fixed-arch
- Supply-chain concerns about checksums served from the same origin as the binary, when the upstream vendor publishes no detached signature
- Non-TTY safety (progress bar control characters, log redirection) for installers that are interactive-only by design and have no cron/systemd usage
- `sudo -v` ticket expiration during long downloads — reprompt is acceptable UX, not a bug
- Cosmetic header tweaks (e.g. adding `Accept: application/vnd.github+json`) when the existing API call already returns the expected payload

**Why:** these scripts run interactively on a single-user machine. Calibration `personal` explicitly excludes portability for non-target platforms, defensive coding for impossible conditions, and supply-chain attacks not involving same-UID actors.

**How to apply:** when reviewing files matching `~/dotfiles/bin/.local/bin/*-update` or similar single-user installers, drop these finding categories before reporting. Real bugs (parsing fragility, swallowed exit codes, misleading user-facing messages, missing rollback paths) remain in scope.
