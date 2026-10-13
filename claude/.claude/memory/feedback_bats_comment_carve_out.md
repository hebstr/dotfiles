---
name: feedback_bats_comment_carve_out
description: Why the bats comment debt is closed won't-fix: the measurement and the rejected alternative
metadata:
  type: feedback
---

The `.bats` carve-out of `rules/code.md` closed a standing comment debt as won't-fix on 2026-10-12, the user ruling.
Do not reopen the 41 suites of `~/dotfiles/_meta/tests/` to normalise them, and do not re-measure the surface: both are settled below.

**Why:** the accounting that carried the debt was wrong in a way that changed the decision.
The filter in use excluded `# ───` section separators but not their ASCII twin `# -----`, and `rules/code.md` already permits section headers, so the claimed 819 lines are really 693 over 41 of the 57 suites.
Reproduce with `^\s*#` minus `#!`, `# ───`, `shellcheck`, and a line that is only ASCII dashes or equals signs; a looser filter cutting `# ---` anywhere gives 688, so quoting a count without its filter is what let the figure drift.
Classifying each block by the first non-blank line under it: 309 lines document a stub helper's contract directly above it, which is the only docstring form shell has, 139 sit above an `@test` and 62 of those 90 blocks are a one-line group label, 79 are a harness preamble, 166 are inline in a test body.
The residual rationale is therefore about 320 lines, and most of it speaks about the harness rather than the script under test: a harness exists only in the file that holds it, so no tracking note can hold its WHY.
Spot-checked both ways: `rules/sql.md` already holds the SQLFluff exit-2 rationale that `format-on-edit.bats` repeats, while nothing in the notes of `~/dotfiles/.claude/` holds `libreoffice-update.bats`'s harness facts (`keys.openpgp.org` stripping UIDs so `recv-keys` exits 0 on nothing, TDF tarballs named by marketing version and extracting to the build version, `</dev/null` turning an unexpected `read` into a named failure instead of a hang).
A subject-based carve-out was weighed and rejected as the narrower option: it buys about 60 lines and charges a harness-versus-subject classification on every future comment.

**How to apply:** the rule sits in `rules/code.md` rather than `rules/shell.md` because `code.md` is the only rules file whose `paths:` matches `**/*.bats`, so a shell-test rule written into `shell.md` would never load on a suite edit.
See [[feedback_review_severity_bats_tests]] for how hard to press on a bats suite at review, and [[feedback_line_number_cross_refs]] for citing a test by its `@test` title.
