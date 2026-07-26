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
- Stub-fidelity coverage whose only consumer is the stub itself: teaching a stub to mutate a file the script never re-reads (e.g. an `npm` stub rewriting `package.json` devDependencies so a test can assert "the pin moved") asserts the test double's programmed behaviour, not the code. Same for sequential "run it twice" idempotency tests that reach a branch a fixture already covers. Both remedies are also circular: the second depends on the first, which exercises nothing
- Guards for a state only the stub can produce: when a stub writes less than the real tool does (e.g. `npm install <pkg>` reifies the whole tree from `package.json`, the stub writes only the named packages), the resulting anomaly in script output is a stub artefact, and hardening the script against it is defensive code for an unreachable condition

**Why:** the `snap-orphans.bats` walkthrough (2026-05-12) rejected 5 of 12 findings under this category. Patterns flagged were valid bats idioms or coverage-for-coverage-sake on bash builtin paths in single-user-workstation context.

**Env-hygiene findings need their detection direction verified empirically before acceptance.** A finding of the form "`setup()` exports a variable colliding with the script's internal name, which would mask a regression" can be exactly inverted: on `css-toolchain-update.bats` (2026-07-26), the exported `GATE_DIR` is what makes the "reads `CSS_GATE_DIR`, not the hardcoded default" test *fail* under a `GATE_DIR="${GATE_DIR:-…}"` regression, because it points at a directory that does hold a `package.json`. Removing the export creates the masking the finding claims to remove. Inject the hypothesised regression and run the suite both ways before accepting; hygiene alone does not justify losing a detector.

**Assertions whose expected value coincides with the requested input prove nothing about provenance.** A closing report asserting `✓ pkg <the version we just asked for>` cannot distinguish reading the installed tree from echoing the request or the pin. The fix is not to add more packages to the assertion list when their pin, latest, and tree version all coincide too: seed one package's tree version away from *both* its pin and its latest, so any implementation echoing either fails.

**How to apply:** when reviewing `.bats` files for scripts under `~/dotfiles/bin/.local/bin/`, drop the above categories before reporting. Real concerns that remain in scope: tests that pass for the wrong reason (no differential assertion), missing cross-validation, brittle substring matches that would match incidentally, hermeticity gaps (PATH/env leakage, silent symlink-loop degradation, stub writes escaping the sandbox), and bash bugs in the test code itself.

Related: [[feedback_review_severity_shell_installers]] (script-level calibration for the same scripts).
