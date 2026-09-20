---
name: A clean `git status` does not mean a history rewrite will apply
description: git status --porcelain omits ignored files, so a clean-tree guard before a rebase misses an untracked-but-ignored file that an earlier commit adds back; check with --ignored and move the file aside first
metadata:
  type: feedback
---

`git status --porcelain` lists untracked files but never ignored ones, so it reports a clean tree on a working directory holding files that a replayed commit will refuse to overwrite. The collision shape is a file **untracked and ignored at the tip, but tracked earlier in history**: a rebase rewinds to a point where the `.gitignore` entry does not exist yet, the on-disk copy becomes an ordinary untracked file, and the pick that adds it aborts with `error: The following untracked working tree files would be overwritten by merge`.

**Measured 2026-09-20** on `~/Documents/packages/quarto-hebstr-slide`, squashing the three root commits through `git commit-tree` plus `git rebase --onto`. The script's five preflight guards included `[ "$(git status --porcelain)" != "" ] && die`, which passed: the tip commit had removed `README.md` from the index and added `/README.md` to `.gitignore` (the author keeping the file on disk pending a re-read before publication). The rebase then stopped mid-run on `README.md` while replaying the commit that created it. `TODO.md`, ignored by the same commit and in no commit at all, surfaced as `??` during the rebase and blocked nothing.

**Why:** the guard read as a pass and the rewrite still failed, leaving the repository mid-rebase. The cost is small when a backup branch exists and the trap prints the way back, but the diagnosis is not obvious from the error, which names a file the user believes untracked and therefore irrelevant.

**How to apply:** before any command that replays or checks out an older history state (`rebase`, `rebase --onto`, `cherry-pick`, `checkout` of an old commit), run `git status --porcelain --ignored` and compare its ignored entries against the paths the replayed commits touch (`git show --name-status <range>`). Any intersection is a collision: move the file aside, run the rewrite, move it back, and say so in the procedure handed to the user. The general form is the same false negative as [[feedback_rg_misses_gitignored_trackers]]: a default that hides ignored paths turns an incomplete check into an apparent pass.
