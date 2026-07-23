---
name: Never propose `git add -A` in a multi-commit sequence
description: When proposing a series of commits, use `git add -u` or explicit paths, never `git add -A`; its safety must not depend on an earlier command in the same sequence having run.
metadata:
  type: feedback
---

When proposing a sequence of commits for the user to run, stage with `git add -u` (tracked files only) or explicit paths. Never `git add -A`.

**Why:** observed failing on edstr, 2026-07-22. The proposed sequence was: commit 1 removes a wrongly-tracked build artifact (`git rm --cached` + append a line to `.gitignore`), commits 2-3 stage explicit paths, commit 4 sweeps the remainder with `git add -A`. The user ran the sequence but the `.gitignore` append did not land. With nothing ignoring them, commit 4 re-added the artifact removed in commit 1, plus two siblings: 2112 insertions undoing the cleanup, and neither of us noticed until a later `git status` showed the file modified again.

The defect is not the missing `.gitignore` line, it is that `git add -A` was load-bearing on a *different command earlier in the same sequence* having succeeded. A staging command whose correctness depends on unverified prior state is a trap, and the user runs these commands unsupervised (they manage all git operations, so there is no chance to intervene mid-sequence).

**How to apply:**
- Default to `git add -u` in any proposed commit sequence. It cannot pick up an untracked file, so it is inert to `.gitignore` state.
- Use explicit paths when the commit is a subset of the tracked changes.
- If a sequence includes both a `git rm --cached` and a later broad staging step, treat that as the smell: reorder so the removal is the last commit, or stage explicitly throughout.
- After the user reports the commits are done, verify with `git log --oneline --diff-filter=A -- <artifact>` rather than assuming the sequence executed as written.

Relates to [[feedback_review_severity_edstr]].
