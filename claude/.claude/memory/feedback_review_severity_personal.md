---
name: Review severity for personal packages
description: "Calibrate code review severity down for personal/internal packages and single-author project repositories: skip defensive patterns appropriate for public CRAN libs, skip missing shared-repo infrastructure that a documented manual gate already covers, and reject by default any finding whose exploitation precondition is an already-compromised workstation or an already-malicious trusted binary"
metadata:
  type: feedback
---

For personal utility packages (not public CRAN libraries), calibrate review severity accordingly. Do not suggest overly defensive patterns that are appropriate for public-facing code.

**Why:** Reviews of hebstr and edstr both had 60-70% of findings rejected as disproportionate. Patterns flagged as bugs were valid R idioms or acceptable shortcuts for internal tooling.

**How to apply:**
- Do not suggest input validation on internal function arguments when downstream errors are already clear
- Do not suggest tryCatch wrapping when a fallback path already exists
- Do not flag variable name shadowing when R's scoping rules resolve it unambiguously
- Do not flag missing namespace prefixes for functions already in NAMESPACE imports
- Do not flag testthat test isolation as "missing mutualisation" (self-sufficient tests are the recommended testthat 3 pattern)
- Do not file missing repository infrastructure (a `prek.toml` or `.pre-commit-config.yaml`, a CI workflow) as a finding on a single-author project whose gate is documented and run by hand. Measured 2026-10-17 on `~/admin/pro-cv`: no project under `~/admin` carries a `prek.toml`, and the "set in all three" of `rules/typst.md` names where the typstyle width is configured across the toolchain, not a per-project install, that same file recording a repo that deliberately has no typstyle hook. The scaffold is adapted per project, never owed by one: see [[feedback_review_severity_profiles_scaffolds]]

**A finding whose exploitation precondition is an already-compromised environment is rejected by default.** When the condition that makes a threat real is "the workstation is already compromised" (`BASH_ENV`, a hostile `PATH`, a binary planted ahead in `~/.local/bin`) or "the trusted binary is already malicious" (filtering ANSI escapes out of the output of a program we are running anyway), mitigating it in the code changes nothing: the attacker already has what the mitigation protects. Reject these before proposing a fix, and say which precondition you rejected on. Migrated 2026-10-13 from the legacy calibration of the m2-dm3 statistics assignment, whose own subject (a short-lived `curl | bash` bootstrap) no longer exists in that project.

Two carve-outs this does **not** grant. A threat exploitable with no prior compromise stays in scope, as do the free measures (timeouts, retries, `set -Eeuo pipefail`, `curl -f`). And it does not reach the multi-user servers: there, per the threat model section of [[feedback_review_severity_shell_installers]], a security finding is never rejected on "personal machine, no attackers", because the blast radius is every user the script bootstraps for.
