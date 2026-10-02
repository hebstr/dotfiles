---
name: "Commit proposals: `git add .` only when nothing in the sequence moves the ignore state"
description: "Staging in proposed commits: `git add .` at the repo root when the commit takes everything `git status` shows and no earlier command of the sequence touches `.gitignore` or runs `git rm --cached`; otherwise explicit paths or `git add -u`, never `git add -A`. Why: the edstr sequence whose failed `.gitignore` append let a broad add undo the cleanup, and the dotfiles sweep where a concurrent session's write landed between the status read and the commit."
metadata:
  type: feedback
---

When proposing commit blocks, stage with `git add .` from the repository root when the commit takes the whole working tree as `git status` shows it, and when no command earlier in the same sequence changes what git ignores (a `.gitignore` edit, a `git rm --cached`). In every other case stage explicit paths or `git add -u`. Never `git add -A`.

**Why:** two constraints meet here.
The user always stages from the repository root and asked on 2026-09-21 for `git add .` in place of a full path listing when the whole available diff goes in one commit. At the root it is equivalent to `git add -A` since git 2.0, and it never picks up an ignored file, which also removes the case of a proposal naming a gitignored path.
The earlier outright ban on broad staging came from edstr, 2026-07-22. The proposed sequence was: commit 1 removes a wrongly-tracked build artifact (`git rm --cached` + append a line to `.gitignore`), commits 2-3 stage explicit paths, commit 4 sweeps the remainder with `git add -A`. The `.gitignore` append did not land, so commit 4 re-added the artifact removed in commit 1, plus two siblings: 2112 insertions undoing the cleanup, unnoticed until a later `git status`. The defect was that broad staging was load-bearing on a *different command earlier in the same sequence* having succeeded, and the user runs these sequences unsupervised. The two conditions above keep exactly that case out while granting the request.

**A third failure mode the two conditions do not cover, observed in `~/dotfiles` on 2026-10-02.** Both conditions held when they were checked: `git status --short` showed exactly one modified file, the commit took all of it, and no command of the sequence touched the ignore state. That status output exists only in the session's transcript, so git cannot re-derive it afterwards; what git keeps is the outcome below. `git add .` still swept a second file, `claude/.claude/memory/reference_snds_variable_traps.md`, because a concurrent session wrote it in the interval between the status read and the commit. The commit went in as `c39e8a4 docs(claude): cut the closed buffer-untracking gap from memory` carrying someone else's SNDS corrections, so `git blame` on those lines now points at a commit about prompt buffers. Nothing was lost or undone, the content being correct, and `--amend` is no remedy since `git-write-guard.sh` refuses it. What makes this repository prone to it: the memory store and `claude/.claude/` are written by every session on the machine, and the `commit` skill's own staleness check already has an `unsealed` class for a file another live session's write journal names, that journal filtering by no path.

**How to apply:** the rule and the proposal format live in `skills/commit/SKILL.md`, section "3. Deliver". Beyond it:
- A file edited in the session but absent from `git status` is checked with `git check-ignore` and reported as ignored, never proposed: `git add` on an ignored path errors out and breaks the rest of the sequence.
- A sequence containing a `git rm --cached` or a `.gitignore` edit stages explicitly throughout, or puts the removal last.
- In `~/dotfiles`, and in any tree other live sessions write to, name explicit paths even when both conditions grant `git add .`: the status read cannot be made simultaneous with the commit, and the paths are already in hand from the `WRITES` list.
- After the user reports the commits are done, verify with `git log --oneline --diff-filter=A -- <artifact>` rather than assuming the sequence executed as written.

Relates to [[feedback_review_severity_edstr]].
