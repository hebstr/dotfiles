---
name: shellharden normalization of the dotfiles scripts
description: Decision reversed 2026-09-12: `bin/.local/bin/`, `claude/.claude/hooks/` and (since 2026-09-19) `bash/` are shellharden-clean, the `$VAR` / `[ "$x" != "" ]` style there is shellharden's output and must not be reverted; a `shellharden --check` prek hook blocks the drift at commit
metadata:
  type: project
---

In `~/dotfiles`, running `shellharden --replace` was twice declined on diff-size grounds (recorded in `.claude/PLAN-TOOL-UPDATERS.md` step 6 and `.claude/PLAN-UPDATER-HYGIENE.md`), because its rewrites on already-quoted code are style preferences: `${VAR}` collapsed to `$VAR`, `[ -n "$x" ]` turned into `[ "$x" != "" ]`.
The user reversed that on 2026-09-12 and it ran on the seven files still dirty: `rv-update`, `quarto-update`, `duckdb-update`, `gnome-config`, `positron-update`, `st-add-folder`, `syncthing-update`.
`shellharden --check` is now clean across `bin/.local/bin/` and `claude/.claude/hooks/`.

**Why:** the earlier decision cost more than it saved. `rules/shell.md` puts `shellharden --replace` first in the mandatory gate, so every edit to a dirty file replayed the full rewrite and the unrelated hunks had to be reverted by hand each time. Normalizing once ends the recurrence.

**How to apply:** do not revert that style in these files, and do not raise it as a finding; it is shellharden's output, not a hand choice.
A local `shellharden` hook was added the same day to `prek.toml` and to `_meta/profiles/prek.toml`, the template other projects are scaffolded from (`--check`, report-only, `types = ["shell"]`, excluding `\.bats$`), so the drift is blocked at commit in both.
The `bash/` package joined that scope on 2026-09-19: `.bashrc`, `.profile` and `.bash_logout` were run through `shellharden --replace` and `shfmt -w -i 2`, so their `[ "$x" != "" ]` and 2-space indentation are tool output too.
Two mechanics behind that hook are worth keeping: `shellharden --check` exits 2 with no output whenever it would change a file, which is why the fix command lives in the hook's `name`. The `.bats` exclusion does not rest on a parse failure, as first recorded: measured 2026-09-22, shellharden parses `@test` and would only restyle 22 of the 42 test files (`"${STUBS}"` to `"$STUBS"`, `[ -z "$x" ]` to `[ "$x" = "" ]`), so the tests are simply not normalized yet (rationale in `rules/shell.md`, section "Pre-commit hook (prek)"); and `format-on-edit.sh` dispatches on `*.sh | *.bash` only, so the extensionless scripts under `bin/.local/bin/` reach no edit-time gate and are covered at commit instead (prek types them shell by shebang).
See [[feedback_review_severity_shell_installers]] for what else not to raise on these scripts.
