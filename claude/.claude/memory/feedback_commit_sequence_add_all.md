---
name: "Commit proposals: `git add .` only when nothing in the sequence moves the ignore state"
description: "Staging in proposed commits: `git add .` at the repo root when the commit takes everything `git status` shows and no earlier command of the sequence touches `.gitignore` or runs `git rm --cached`; otherwise explicit paths or `git add -u`, never `git add -A`. Why: the edstr sequence whose failed `.gitignore` append let a broad add undo the cleanup."
metadata:
  type: feedback
---

When proposing commit blocks, stage with `git add .` from the repository root when the commit takes the whole working tree as `git status` shows it, and when no command earlier in the same sequence changes what git ignores (a `.gitignore` edit, a `git rm --cached`). In every other case stage explicit paths or `git add -u`. Never `git add -A`.

**Why:** two constraints meet here.
The user always stages from the repository root and asked on 2026-09-21 for `git add .` in place of a full path listing when the whole available diff goes in one commit. At the root it is equivalent to `git add -A` since git 2.0, and it never picks up an ignored file, which also removes the case of a proposal naming a gitignored path.
The earlier outright ban on broad staging came from edstr, 2026-07-22. The proposed sequence was: commit 1 removes a wrongly-tracked build artifact (`git rm --cached` + append a line to `.gitignore`), commits 2-3 stage explicit paths, commit 4 sweeps the remainder with `git add -A`. The `.gitignore` append did not land, so commit 4 re-added the artifact removed in commit 1, plus two siblings: 2112 insertions undoing the cleanup, unnoticed until a later `git status`. The defect was that broad staging was load-bearing on a *different command earlier in the same sequence* having succeeded, and the user runs these sequences unsupervised. The two conditions above keep exactly that case out while granting the request.

**How to apply:** the rule and the proposal format live in `skills/commit/SKILL.md`, section "3. Deliver". Beyond it:
- A file edited in the session but absent from `git status` is checked with `git check-ignore` and reported as ignored, never proposed: `git add` on an ignored path errors out and breaks the rest of the sequence.
- A sequence containing a `git rm --cached` or a `.gitignore` edit stages explicitly throughout, or puts the removal last.
- After the user reports the commits are done, verify with `git log --oneline --diff-filter=A -- <artifact>` rather than assuming the sequence executed as written.

Relates to [[feedback_review_severity_edstr]].
