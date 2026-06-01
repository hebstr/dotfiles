---
name: Review severity for personal bats test files
description: Calibration rules for code reviews of bats test files covering personal shell tooling (single-user workstation context)
metadata:
  type: feedback
---

When reviewing bats `.bats` test files for personal shell tooling (e.g. `_meta/tests/*.bats` covering scripts under `~/dotfiles/bin/.local/bin/`), do NOT raise the following finding patterns:

- Failure-injection coverage for `cmd || warn …` bash idioms where the error branch is a one-liner printf-to-stderr: testing this exercises bash's `||` operator, not application logic
- Non-dry-run mutating-path coverage when the script gates the path behind `sudo` re-exec and `EUID != 0` checks: adding coverage requires either running tests as root or building fake-EUID infrastructure, disproportionate for personal Ubuntu tooling whose author always inspects with `--dry-run` first
- Pinning known script-level bugs as test expectations during a test-file walkthrough: that obstructs a future fix; out of scope for a test-file review
- Cosmetic `${VAR:-}` defaults or `rm -rf --` in setup/teardown when the current code is correct under bash quoting rules and the unsafe-input scenario (paths starting with `-`, or unset variables triggering `set -u` paths) cannot occur (`mktemp -d` never produces leading-dash paths, and `rm -rf ""` is a no-op)
- Per-function narrowing of file-level `# shellcheck disable=SC2030,SC2031`: file-level disable is the standard bats idiom because each `@test` runs in a subshell, triggering these warnings on variables legitimately set in `setup()`
- "Production-grade error handling" for `run` wrappers and interactive `read -r -p` prompts whose only realistic regression class would require bash itself to break

**Why:** the `snap-orphans.bats` walkthrough (2026-05-12) rejected 5 of 12 findings under this category. Patterns flagged were valid bats idioms or coverage-for-coverage-sake on bash builtin paths in single-user-workstation context.

**How to apply:** when reviewing `.bats` files for scripts under `~/dotfiles/bin/.local/bin/`, drop the above categories before reporting. Real concerns that remain in scope: tests that pass for the wrong reason (no differential assertion), missing cross-validation, brittle substring matches that would match incidentally, hermeticity gaps (PATH/env leakage, silent symlink-loop degradation), and bash bugs in the test code itself.

Related: [[feedback_review_severity_shell_installers]] (script-level calibration for the same scripts).
