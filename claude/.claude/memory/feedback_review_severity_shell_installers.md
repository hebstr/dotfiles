---
name: Review severity for personal shell installers
description: Calibration rules for code reviews of shell scripts in ~/dotfiles/bin/.local/bin/ (installers and personal CLI tooling on a single-user workstation)
type: feedback
---

When reviewing personal shell installers (e.g. `quarto-update`, `positron-update`, `rv-update`) under `~/dotfiles/bin/.local/bin/`, do NOT raise the following finding patterns:

- Defensive branching to distinguish "first install" / "parse failure" / "normal" cases on a single-user workstation where the tool is already installed
- Supply-chain concerns about checksums served from the same origin as the binary, when the upstream vendor publishes no detached signature (TLS is the only available trust root, note as informational only, no code change possible)
- Non-TTY safety (progress bar control characters, log redirection) for installers that are interactive-only by design and have no cron/systemd usage
- `sudo -v` ticket expiration during long downloads; sudo default timeout (15 min) >> typical download time, reprompt is acceptable UX even if it fired
- Cosmetic header tweaks (e.g. adding `Accept: application/vnd.github+json`) when the existing API call already returns the expected payload
- Implicit dependency prechecks for tools already provisioned in the deployment baseline (`curl`, `jq`, coreutils): confirmed present on both workstation and target servers
- GitHub API unauthenticated-rate-limit concerns for manually-invoked scripts (a few invocations/month per user, 60 req/h is never approached)
- TOCTOU between checksum verify and `sudo dpkg -i` when the work directory is `mktemp -d` (mode 0700, user-owned): no cross-user attack surface
- Vendor-CDN URL-structure fragility (e.g. `${CDN}/deb/${arch}/...` path assumption) when `curl -f` already produces a loud 404 on schema change; fail-bruyant is acceptable
- Fail-fast ordering preferences (e.g. "move the arch check before the network call") when the reviewer themselves acknowledge no correctness consequence; cosmetic fail-order is not a required fix
- Redundant explicit error handling (`|| { echo ...; exit 1; }`) for commands already covered by `set -euo pipefail` (the pipeline failure mode is already handled; the explicit handler adds noise, not safety)
- Sudo credential keepalive loops to prevent mid-run re-prompts (rare-case mitigation; one extra prompt is acceptable UX)
- Cross-distro fallback guards (e.g. `command -v apt-get` on a script that is Ubuntu-targeted and tested as such); bats tests asserting the absence of a guard are tested intent, not a bug
- Speculative parent-process / self-replace concerns (e.g. "what if `claude update` is invoked from inside `claude`") with no concrete trigger or reproducer
- Cosmetic future-proofing (column widths, separator alignment) where the failure mode is *visible misalignment* on the next run: the author sees it and fixes it in place, no silent corruption
- Stylistic refactors with no behavioral change (associative-array idioms vs. nested loops on n≤20, table-driven dispatch vs. 17 explicit handlers, status-string enums on fields with no programmatic consumer)

**Why:** these scripts target a known deployment surface (the user's workstation + multi-user servers running the same dotfiles). Threat model excludes cross-UID attackers on the work directory, and operational reality excludes high-frequency automated invocation. Real concerns are functional bugs, not theoretical hardening. The `sys-update` walkthrough (2026-05-10) clarified that for personal wrappers with bats tests, "future-proofing" against hypothetical larger inputs or alternative consumers is not a real concern: the only consumer is the author, who refactors when the need arises.

**How to apply:** when reviewing files matching `~/dotfiles/bin/.local/bin/*-update` or similar shell installers, drop these finding categories before reporting. **Multi-arch portability IS in scope**: these scripts are deployed on multi-user servers per `project_rv_install_deployment.md`, so `amd64`-only assumptions are real bugs. Real bugs that remain in scope: parsing fragility, swallowed exit codes (e.g. trap losing `$?` on cleanup failure), misleading user-facing messages, missing rollback paths, hardcoded arch on a multi-arch deployment surface.

---

For thin install-wrapper scripts in `~/dotfiles/bin/` (e.g. `sysinstall`, `rv-install`, `sys-update`), also do not raise:

- Version pinning / reproducibility (using `latest` URLs is by design; these wrappers are not configuration management tools)
- Cosmetic locale concerns (Unicode glyphs like `→` `✓` in stderr; modern Linux targets default to UTF-8)
- Privilege-model nudges toward user-local default when the script's name signals system-wide intent (e.g. `sysinstall`)
- IFS-join robustness on arrays whose contents are statically constrained to validated keys
- `jq` stream deduplication guards (`| first`, `limit(1;.)`) on config fields whose structure is statically constrained to a single value
- Production-grade output semantics on hand-run interactive utilities with no documented automation consumer (meaningful partial-failure exit codes, stdout/stderr separation of diagnostic vs. action lines, pre-flight input validation when the underlying tool's own error message is informative). Surface WARN to stderr is sufficient; `exit 0` at end is acceptable.
- Existence guards (`if [ ! -f "$X" ]`) framed as "config drift invisible" bugs on bootstrap wrappers; the contract of these scripts is "bootstrap files if absent + run the actual update step", not "reconcile generated config on every run". Existence guards intentionally preserve local overrides for paths the user may have edited.
- Config patterns that mirror the upstream's own published recommendation (e.g. `Pin: origin <repo>` taken verbatim from `apt.syncthing.net`'s troubleshooting block); diverging from upstream's documented form adds maintenance debt with no real security gain.

Excluded: this section does **not** disable findings on integrity verification before `sudo sh` execution; those remain in scope (coupled to the pinning decision).

---

For Claude Code hook scripts in `~/dotfiles/claude/.claude/hooks/` (e.g. `inject-project-context.sh`), do not raise:

- `set -euo pipefail` suggestions; hooks in this repo are best-effort context injectors. `set -e` would abort the script on any failed `grep` (exit 1 when no match), leaving Claude with no context rather than partial context
- Quoting / word-splitting findings already cleared by `shellcheck`; shellcheck is the authoritative reference. If it passes, the finding is a false positive
- Portability concerns (GNU sed `\s`, etc.); target is Ubuntu 24.04 with GNU tools

**Why hook scripts:** walkthrough on `claude/.claude/hooks/inject-project-context.sh` (2026-05-08): 5 of 7 findings rejected. The hook's design is deliberately best-effort; fail-fast patterns are counterproductive here.

**How to apply (hook scripts):** flag actual logic bugs (wrong exit-code semantics, incorrect grep anchors, empty-output when non-empty expected). Do not propose defensive patterns that conflict with best-effort output intent.
