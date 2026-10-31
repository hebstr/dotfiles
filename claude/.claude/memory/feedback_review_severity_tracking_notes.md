---
name: Review severity for the .claude tracking notes
description: "Calibrate reviews and audits of the tracking notes of ~/dotfiles/.claude (the PLAN*, DESIGN* and register notes, DEFERRED.md): do not propose a mechanical cap, ratchet or threshold trigger on a note's growth, the invoked prune pass and instructions-budget covering it on the measured drift"
metadata:
  type: feedback
---

Do not propose a mechanical cap, a growth ratchet or a threshold trigger on the size of a tracking note under `~/dotfiles/.claude`.
The question is closed by measurement rather than by taste, and a reviewer meeting these notes reaches for it because nothing visibly caps them, which is true and decides nothing.

**Why:** rejected 2026-10-31 on the premise test, closing a backlog row open since 2026-09-30 that had carried the ratchet design (compare the staged file against `HEAD`, refuse further growth of a file already over a watch threshold).
The figures, with the full reading in `~/dotfiles/.claude/PRUNE-OBSERVATIONS.md` under "A growth ratchet on the staged file": over `47876d6..119680a`, 2026-10-16 to 2026-10-30, net 479 lines *added* across 29 notes, about 32 a day, under one line per note per day; the size distribution flat over the fortnight (6 notes over 40 KB against 7 on 2026-10-13, 9 over 30 against 8, 11 over 20 against 12); one note alone over 100 KB, `DESIGN-COMMIT-GUARD.md`, which moved 2,897 B in that span.
The case a cap would exist for is the one the invoked prune pass demonstrably takes, `PLAN-SESSION-DISCIPLINE.md` going from 236 KB to 62 KB on 2026-10-15.
A watch threshold is also the figure that file says does not pick the target, which is the ground its harness-trigger entry fell on.
Cross-model L1 agreed on the figures of the day.

**How to apply:** drop the finding before reporting it, and say the drift was measured rather than that the growth is bounded, which it is not.
Two mechanisms stay in scope and real: `instructions-budget` on the always-loaded set (`CLAUDE.md`, the rules files, `MEMORY.md`), whose ceilings a finding may legitimately question, and `check-added-large-files` at 500 KB on the parent repository, which these notes never reach, the parent ignoring `/.claude/`.
Re-open only on a reading that moves the direction rather than confirms it: a note past 210 KB again, or a month whose net sits far above the measured rate.
The criterion the row waited on, about two months of history, is answered in substance by two independent windows agreeing, so a third reading of the same thing is not the reason to re-open.

Related: [[feedback_review_severity_claude_rules]] for `.claude/rules/*.md` content, [[feedback_review_severity_claude_config]] for the harness config artifacts, [[feedback_audit_walkthrough]] for the pass that recorded this.
