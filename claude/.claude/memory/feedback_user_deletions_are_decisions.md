---
name: Content missing from the user's own data is their pruning, never a loss to repair
description: Why a disappearance measured in a curated data file (a comment store, a register, a workbook) is presumed deliberate, and what to do with the stale count that revealed it
metadata:
  type: feedback
---

When live data holds fewer items than a tracking note claims, the gap is the user's own editing until something establishes otherwise. Never restore the missing items, from a git blob or from anywhere else.

**Why:** on 2026-10-25 in eds-prise, `.comments/collab-comments.json` held 18 of the 23 entries `PLAN.md` recorded, and the five had left in `981b60c`, a commit whose subject named only the `comment-hash` filter. That reading, collateral damage of a normalisation commit, was wrong: the user had deleted them. Restoring four of them put their reviewer's withdrawn comments back into a deliverable they had cleared, and the measurement that preceded it, every anchor still resolving uniquely, proved only that the restore was mechanically possible. A commit subject bounds what the author wrote about, not what the commit carries, and `git log` never says why a line is gone.

**How to apply:**
- Report the gap with its measurement and stop there. The deliverable's current state is the state the user chose.
- The stale figure is the defect: correct the note to the measured count and record that the removal was deliberate, so the next session does not re-open it. In that project the line now reads that the 18 are a ruling and not a loss.
- Restoring is a repair of the user's own work, so it is theirs to ask for, not a recommendation to make: a measurement showing the restore is clean is not a reason to run it.
- The same presumption covers a register pruned by hand, a workbook row removed, a note deleted from a `.claude/` tree: the project's `CLAUDE.md` says to delete a note only on explicit instruction, and the symmetry holds for putting one back.

Related: [[feedback_personal_working_files]], [[project_collab_comments_evaluation]], [[feedback_verify_before_claiming]].
