---
name: Checking whether an env var is set without printing it
description: "`${VAR:-fallback}` and `${VAR:+x}${VAR:-y}` print the secret; test presence with `[ -n \"$VAR\" ]` or `${VAR:+set}` alone"
metadata:
  type: feedback
---

To report whether an env var holding a credential is set, never build the answer out of `${VAR:-...}`.
`${VAR:+set}${VAR:-unset}` looks like a two-branch expression but is two substitutions concatenated: when `VAR` is set, the second one expands to **the value itself**, so the secret lands in stdout, in the transcript and in the `~/.claude/projects/` jsonl.
Measured on `OPENROUTER_API_KEY`, 2026-09-02, which had to be rotated.

**Why:** `:-` substitutes the value when the variable is set and non-empty; the fallback only appears when it is unset. It is the opposite of a guard.

**How to apply:** use `[ -n "$VAR" ] && echo set || echo unset`, or `${VAR:+set}` alone (empty output means unset). Same for a length check: `${#VAR}` prints a number, never the value.
Applies to any variable that might hold a credential, and the cost of using the safe form unconditionally is zero.

See [[feedback_review_severity_personal]] for the wider personal-tooling calibration; the file-side rules live in `rules/secrets.md`.
