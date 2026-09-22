---
name: Commit proposals: `git add .` only when nothing in the sequence moves the ignore state
description: Staging in proposed commits: `git add .` at the repo root when the commit takes everything `git status` shows and no earlier command of the sequence touches `.gitignore` or runs `git rm --cached`; otherwise explicit paths or `git add -u`, never `git add -A`. Also where the proposal format lives and why.
metadata:
  type: feedback
---

When proposing commits for the user to run, stage with `git add .` from the repository root when the commit takes the whole working tree as `git status` shows it, and when no command earlier in the same sequence changes what git ignores (a `.gitignore` edit, a `git rm --cached`). In every other case stage explicit paths or `git add -u`. Never `git add -A`.

**Why:** two constraints meet here.
The user always stages from the repository root and asked on 2026-09-21 for `git add .` in place of a full path listing when the whole available diff goes in one commit. At the root it is equivalent to `git add -A` since git 2.0, and it never picks up an ignored file, which also removes the case of a proposal naming a gitignored path.
The earlier outright ban on broad staging came from edstr, 2026-07-22. The proposed sequence was: commit 1 removes a wrongly-tracked build artifact (`git rm --cached` + append a line to `.gitignore`), commits 2-3 stage explicit paths, commit 4 sweeps the remainder with `git add -A`. The `.gitignore` append did not land, so commit 4 re-added the artifact removed in commit 1, plus two siblings: 2112 insertions undoing the cleanup, unnoticed until a later `git status`. The defect was that broad staging was load-bearing on a *different command earlier in the same sequence* having succeeded, and the user runs these sequences unsupervised. The two conditions above keep exactly that case out while granting the request.

**How to apply:**
- Every path a proposal names comes from `git status` output, never from what the session remembers editing. A file edited in the session but absent from `git status` is checked with `git check-ignore` and reported as ignored, never proposed: `git add` on an ignored path errors out and breaks the rest of the sequence.
- `git add .` is legitimate for a single commit, or for the last commit of a sequence whose earlier commands leave the ignore state alone. It is never legitimate when the whole tree holds a file the proposal advises keeping out (an untracked file judged not to belong, a secret-scope file): stage by path then.
- A sequence containing a `git rm --cached` or a `.gitignore` edit stages explicitly throughout, or puts the removal last.
- After the user reports the commits are done, verify with `git log --oneline --diff-filter=A -- <artifact>` rather than assuming the sequence executed as written.

**Where the format lives (decided 2026-09-22, superseding 2026-09-21):** the rendering and staging format lives in `skills/commit/SKILL.md`, section « 3. Rendre », beside the procedure; the Git section of `~/.claude/CLAUDE.md` keeps one line sending every commit suggestion to the skill. The 2026-09-21 decision had kept the format in `CLAUDE.md` because the skill then carried `disable-model-invocation: true` and never loaded for a spontaneous proposal. The flag was removed on 2026-09-22 (`.claude/PLAN-SESSION-DISCIPLINE.md`, « Cadrage de l'étape 3 »), and the Stop hook `commit-gate.sh` now blocks a response carrying a `git commit` line (`-am` included) written after unverified code writes, which pushes spontaneous proposals through the skill. The format agreed: one fenced block tagged `bash` per commit, holding its staging command and the full `git commit -m "<header>"` line, never the header alone. Open point: that the Claude Code terminal colorizes a `bash`-tagged fence is assumed, not verified.

Relates to [[feedback_review_severity_edstr]].
