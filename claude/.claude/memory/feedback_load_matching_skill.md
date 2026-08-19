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

## How to apply

- Check the available-skills list against the artifact about to be produced, before producing it. Tests, prose, diagrams, artifacts and reviews all have skills that carry checklists no neighbouring file encodes.
- When testing a bugfix, assert the observable the bug corrupted, not only the underlying effect. A wrong status, a wrong log line or a wrong exit code is what the user sees.
- Repo conventions tell you the shape of a test; a skill tells you what the test must cover. Both, in that order.

See [[feedback_verify_before_claiming]] for the neighbouring failure mode on factual claims.
