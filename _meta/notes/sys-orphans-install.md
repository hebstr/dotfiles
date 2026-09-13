# Stow sys-orphans into ~/.local/bin

*2026-09-13T08:20:57Z by Showboat 0.6.1*
<!-- showboat-id: b3b24156-2558-46f6-82a1-8cf67dd1b78f -->

sys-orphans is the read-only detector of dangling references designed in .claude/PLAN-ORPHANS.md (step 8). sys-cleanup calls it with --count at the end of each run, so it must resolve on the PATH. It lives in the bin stow package like every other script, so stow creates the link; nothing is copied.

```bash
cd ~/dotfiles && stow bin && readlink -e ~/.local/bin/sys-orphans
```

```output
/home/julien/dotfiles/bin/.local/bin/sys-orphans
```

Verification: the command resolves through the stow link, and the counting mode sys-cleanup consumes prints a bare integer.

```bash
command -v sys-orphans && sys-orphans --count | grep -Ex "[0-9]+" >/dev/null && echo "count mode prints an integer"
```

```output
/home/julien/.local/bin/sys-orphans
count mode prints an integer
```
