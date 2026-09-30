---
name: .claude in dotfiles is versioned by a nested repo with no remote
description: Decision (2026-09-30) to version ~/dotfiles/.claude locally through a nested git repo with no remote, why git offers no path-level push filter, and the two open points (what the initial commit takes, and the history not replicating across machines)
metadata:
  type: project
---
`~/dotfiles/.claude/` is versioned locally without ever reaching `github.com/hebstr/dotfiles`, through a nested repository: `git init` was run in `~/dotfiles/.claude` on 2026-09-30, with no remote and no commit yet. The parent's `.gitignore` already carries `/.claude/`, so git never sees a gitlink and nothing changes in the dotfiles repo.

**Why:** git's push granularity is the repository and the ref, never the path: a `git push` sends the commits reachable from the pushed ref with all their content, and no refspec, client option or GitHub setting excludes a directory. `.gitignore` excludes from history altogether, `--skip-worktree` and `--assume-unchanged` only mask local modifications while the path stays in the pushed history, and sparse-checkout acts on what is extracted. The alternatives are a separate repository or a branch never pushed; the branch form was rejected as leak-prone (`git push --all`) and as requiring a rebase on every parent commit.

**How to apply:** do not re-derive the mechanism, and do not re-propose a `.gitignore`-only or `skip-worktree` answer. What stays open, deferred by the user on 2026-09-30 and tracked in `~/dotfiles/.claude/DEFERRED.md`: what the initial commit takes. Measured that day, 2.2 MB of markdown against 21 MB of PNG under `screenshots/` and 17 MB of PDF under `pdf-tables-eval/`, plus `settings.local.json`, which is machine-local and already out of Syncthing. A `.claude/.gitignore` holding `settings.local.json`, `screenshots/` and `*.pdf` was proposed and refused pending that decision. Second open point: `.stignore` excludes `.git` at any depth, so the notes replicate across machines but their history does not; an exception is safe only while ju-TP2 stays receive-only ([[project_ju_tp2_receiveonly]]). Undo is `rm -rf ~/dotfiles/.claude/.git`.
