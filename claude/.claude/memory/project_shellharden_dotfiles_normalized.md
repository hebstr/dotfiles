---
name: shellharden normalization of the dotfiles scripts
description: "Since 2026-09-12 the dotfiles' bin/.local/bin/, claude/.claude/hooks/ and bash/ are shellharden-clean: the `$VAR` / `[ \"$x\" != \"\" ]` style there is tool output, never to be reverted or raised as a finding"
metadata:
  type: project
---

In `~/dotfiles`, running `shellharden --replace` was twice declined on diff-size grounds, because its rewrites on already-quoted code are style preferences: `${VAR}` collapsed to `$VAR`, `[ -n "$x" ]` turned into `[ "$x" != "" ]`.
The user reversed that on 2026-09-12, and `shellharden --check` is now clean across `bin/.local/bin/` and `claude/.claude/hooks/`.

**Why:** the earlier decision cost more than it saved. `rules/shell.md` puts `shellharden --replace` first in the mandatory gate, so every edit to a dirty file replayed the full rewrite and the unrelated hunks had to be reverted by hand each time. Normalizing once ends the recurrence.

**How to apply:** do not revert that style in these files, and do not raise it as a finding; it is shellharden's output, not a hand choice.
The `bash/` package joined that scope on 2026-09-19 (`.bashrc`, `.profile`, `.bash_logout`, also run through `shfmt -w -i 2`), so its style and 2-space indentation are tool output too.
A local `shellharden --check` prek hook blocks the drift at commit; its mechanics (report-only, exit 2 with no output, the `\.bats$` exclusion by choice, extensionless scripts caught at commit rather than at edit time) are in `~/dotfiles/claude/.claude/rules/shell.md` § "Pre-commit hook (prek)".
See [[feedback_review_severity_shell_installers]] for what else not to raise on these scripts.
