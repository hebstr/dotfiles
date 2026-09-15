# Stow the /commit skill

*2026-09-15T11:57:37Z by Showboat 0.6.1*
<!-- showboat-id: 427a7a10-8b36-4478-ba05-d2b39d64e981 -->

Link the new personal skill claude/.claude/skills/commit into ~/.claude/skills so Claude Code loads /commit. The dry run (stow -n -v claude) showed a single LINK and no conflict.

```bash
cd ~/dotfiles && stow -v claude 2>&1 | grep -v "^BUG in find_stowed_path" ; echo "exit=$?"
```

```output
LINK: .claude/skills/commit => ../../dotfiles/claude/.claude/skills/commit
exit=0
```

```bash
readlink -e ~/.claude/skills/commit/SKILL.md
```

```output
/home/julien/dotfiles/claude/.claude/skills/commit/SKILL.md
```
