---
name: Redacting text out of local commits before a first push
description: "What it takes to remove text from unpushed commits: the introducing commit, git log --all -S over a grep of the tips, fixup+autosquash, the rm --cached worktree trap, filter-repo-rs --partial, the checks that a plain push leaves the backup ref behind, and the three steps that clear the clone afterwards (reflog expire, gc --prune, then rm -r .git/filter-repo, which no gc touches)"
metadata:
  type: reference
---
A redaction committed **on top** of the commit that introduced the text protects nothing once the push happens: the original blob stays reachable, so the edit has to land inside the introducing commit while it is still local.
Find that commit with `git log --diff-filter=A -- <path>`, and never assume one commit holds everything: on 2026-11-08 the 28 `.claude` notes entered at one commit while a 29th had entered at the next, and each needed its own target.

**Test containment with `git log --all -S'<string>'` over every reachable commit, never with `git grep` on the tips.** A string deleted at the tip is still in history, and one sitting in an already-pushed commit cannot be removed without rewriting published history, which is a different and usually refused decision. Both traps fired that day: a warehouse schema believed confined to one note turned out to be reachable from an ancestor of `origin/main` through a memory since deleted, while three e-mail addresses and three private addresses believed to be in deleted files only were in fact quoted in the note that reported scanning for them.

The route, measured end to end:

- commit the redaction with `git commit -m "fixup! <target subject>"`, then `git rebase --autosquash <base>`, which needs no `-i` (git 2.56.0: "can be run without an explicit --interactive"), so there is no todo list to edit;
- **keep the redaction and any newly written prose in separate commits.** A fixup carrying both conflicts at every intermediate commit that touches the same file, because the three-way merge treats the whole region and not the hunk: two conflicts on one file that day, both avoidable;
- **a `git rm --cached` inside such a fixup deletes the files from the worktree when the rebase replays it.** `--cached` spares the worktree only in the commit where it is typed. Restore with `git show <pre-rewrite-sha>:<path> > <path>`, which is why the backup ref must outlive the rebase rather than be deleted right after it;
- a path already deleted at the tip is absent from the index, so no `git rm` reaches it: that case needs `filter-repo-rs --invert-paths --path <p>`. **`--partial` is mandatory**, without it the tool runs its remote cleanup and `origin` is gone; `--backup` writes a bundle under `.git/filter-repo/`, which stays local and which `.stignore` keeps out of Syncthing;
- commits whose trees the filter does not change keep their hashes, so already-pushed history survives untouched. Verify it, rather than trusting it, with `git rev-parse origin/main` before and after.

**After the rewrite the backup ref and the filter's bundle still carry the unredacted blobs.** With `push.default` unset (so `simple`), no `remote.origin.push` refspec and no upstream on that ref, a plain `git push` leaves them behind: check those three before concluding it. Never `git push --all` while the ref exists, and delete it once the push is verified.

**Deleting that ref prunes nothing, and clearing the clone takes three steps rather than one.** The pre-rewrite commits stay readable from the reflog and from the unreachable objects, so `git cat-file -t <old sha>` still answers `commit` and `git grep` still reads the unredacted text out of it. `git reflog expire --expire=now --all` then `git gc --prune=now` is what ends that half, verified by the old sha becoming unresolvable and `git fsck --unreachable --no-reflogs` reporting none. Neither touches `.git/filter-repo/`, whose `fast-export.filtered` and backup bundle are plain files holding the same text: that directory is a separate `rm -r`. Reading the `gc` as covering it is [[feedback_verify_native_gc_semantics]] exactly. None of this is an exposure while `.stignore` holds `.git` and no refspec pushes it, so it is hygiene and not urgency.

Worked case, with the verdicts and what was refused: [[project_claude_dir_local_only_repo]] and `~/dotfiles/.claude/DESIGN-CLAUDE-REPO.md`, section "The confidentiality read before the push (2026-11-08)".
