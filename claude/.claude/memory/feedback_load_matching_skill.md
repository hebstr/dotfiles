---
name: feedback_load_matching_skill
description: Load a matching installed skill before producing the artifact, not after; mirroring an existing file's conventions reproduces its blind spots
metadata:
  type: feedback
---

When a task matches an installed skill's trigger, load the skill **before** writing the artifact.
Mirroring the conventions of a neighbouring file in the repo is not a substitute: it reproduces whatever that file already misses.

## Why

2026-08-19, `~/dotfiles`: a bugfix on `sys-cleanup`'s `claude-versions` module needed bats tests.
I wrote them by copying the conventions of `_meta/tests/sys-cleanup.bats` (stub factory, `_run` helper, `FAKE_HOME`) without loading `bats-testing-patterns`, although "writing bats tests" and "TDD on a shell utility" are both in its trigger.

The tests asserted the removals but never the **reported status**, and the status was the entire bug: the module announced `skipped (no version dir)` while 632 MB of stale Claude Code versions accumulated.
A test suite that does not assert the status lets the exact regression it was written for pass unnoticed.

The user asked whether the skill had been invoked. Loading it afterwards surfaced the gap through its "test both success and failure paths" point, which added two cases: no `skipped` in the file layout, and a single-version directory where there is nothing to remove and `OK` is still correct.

The same pass over the other 20 suites found one more uncovered branch, in the `sweep-stale-consolidate-locks` hook, and a mutation test proved the six pre-existing cases all survived a broken guard.

It recurred on 2026-10-29, same repository and same skill, on the six prune tests of `_meta/tests/sys-update.bats`: written, gated and committed before the skill was loaded, and surfaced again by the user asking whether it had been.
The prek `shellcheck` hook caught the one defect the skill states outright (`run !` for a negative assertion, with its `bats_require_minimum_version 1.5.0`), which is why the first commit failed; loading the skill afterwards added the failure-path test the hook could not see.
The bats case is mechanized since that date: `inject-rules.sh` denies the session's first `Edit`, `Write` or `MultiEdit` on a `*.bats` path, its message naming the skill to call. Nothing else is, so the rule below still carries every other artifact type.

A user-invocable-only skill cannot be loaded at all, so what is owed is a ruling rather than a call.
On 2026-11-07 in `quarto-hebstr-doc`, asked to put the language icon on the `{{< script >}}` folded chip, the session measured the DOM, prototyped the selector and delivered its "what does done look like" list without once weighing a `/design` pass, although that feature had been designed, delivered, reopened on a defect of form and re-decided, all on that same day; it ruled only when the user asked whether it was confident and whether `/design` was warranted, and the ruling was yes.
`CLAUDE.md` carries the correction since that date, grafted onto the "what does done look like" bullet rather than added as a line of its own, the always-loaded set having had 175 of its 12,288 bytes free (`instructions-budget`, same day).
A deterministic carrier was weighed and none fits: the trigger, a user's implementation idea, and the tell, a proposal carrying no ruling, are both natural language, where the mechanized bats case above keys on a file extension and `ending-gate.sh` keys on fixed idioms.

## How to apply

- Check the available-skills list against the artifact about to be produced, before producing it. Tests, prose, diagrams, artifacts and reviews all have skills that carry checklists no neighbouring file encodes.
- When testing a bugfix, assert the observable the bug corrupted, not only the underlying effect. A wrong status, a wrong log line or a wrong exit code is what the user sees.
- Repo conventions tell you the shape of a test; a skill tells you what the test must cover. Both, in that order.

See [[feedback_verify_before_claiming]] for the neighbouring failure mode on factual claims.
