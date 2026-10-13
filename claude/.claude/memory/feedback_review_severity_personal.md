---
name: Review severity for personal packages
description: "Calibrate code review severity down for personal/internal packages: skip defensive patterns appropriate for public CRAN libs, and reject by default any finding whose exploitation precondition is an already-compromised workstation or an already-malicious trusted binary"
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

**A finding whose exploitation precondition is an already-compromised environment is rejected by default.** When the condition that makes a threat real is "the workstation is already compromised" (`BASH_ENV`, a hostile `PATH`, a binary planted ahead in `~/.local/bin`) or "the trusted binary is already malicious" (filtering ANSI escapes out of the output of a program we are running anyway), mitigating it in the code changes nothing: the attacker already has what the mitigation protects. Reject these before proposing a fix, and say which precondition you rejected on. Migrated 2026-10-13 from the legacy calibration of the m2-dm3 statistics assignment, whose own subject (a short-lived `curl | bash` bootstrap) no longer exists in that project.

Two carve-outs this does **not** grant. A threat exploitable with no prior compromise stays in scope, as do the free measures (timeouts, retries, `set -Eeuo pipefail`, `curl -f`). And it does not reach the multi-user servers: there, per the threat model section of [[feedback_review_severity_shell_installers]], a security finding is never rejected on "personal machine, no attackers", because the blast radius is every user the script bootstraps for.
