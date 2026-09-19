---
name: ju-TP2 is receive-only for dotfiles and ~/.claude
description: On ju-TP2 (WSL) never write to ~/dotfiles or ~/.claude; ju-TP is the single writer, Syncthing overwrites or strands ju-TP2 edits
metadata:
  type: project
---

`~/dotfiles` and `~/.claude` are Syncthing `sendonly` on `ju-TP` and `receiveonly` on `ju-TP2` (see `_meta/notes/wsl-init-tuto.md`, "Git se pratique sur la machine principale").
Any write on `ju-TP2` stays a local change that never reaches `ju-TP` or git, and is silently replaced whenever `ju-TP` touches the same file.

**Why:** on 2026-09-19 a `ju-TP2` session edited README, CLAUDE.md, tracking files and a new stow package locally while a `ju-TP` session did the same step; three `ju-TP2` edits were lost to overwrites and the rest duplicated work already done on `ju-TP`.

**How to apply:** on `ju-TP2`, treat both trees as read-only. A change they need is made on `ju-TP`, either by the `ju-TP` session or over `ssh ju-TP`, and only while no `ju-TP` session is editing the same files. Stray local edits on `ju-TP2` are staged to a directory outside the synced trees, merged on `ju-TP`, then discarded with Syncthing's "Revert Local Changes" on `dotfiles`. Never revert `claude` while a Claude Code session runs on `ju-TP2`: the harness itself writes its session state under `~/.claude`, and what `syncthing/.claude/.stignore` does not exclude shows up there as local changes that a revert deletes. The rule binds authored edits, not the harness's own writes. Check the hostname before any write in these trees. Since 2026-09-19 `ssh ju-TP2` works from `ju-TP` (`.claude/DESIGN-SSH.md` in the dotfiles), so a read on `ju-TP2` no longer needs its session.
