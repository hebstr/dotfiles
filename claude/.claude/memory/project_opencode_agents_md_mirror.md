---
name: opencode AGENTS.md mirrors the behavioral rules of CLAUDE.md
description: When a behavioral rule of ~/.claude/CLAUDE.md is added, changed or removed, check whether ~/dotfiles/opencode/.config/opencode/AGENTS.md carries it and update that copy in the same response
metadata:
  type: project
---

`~/dotfiles/opencode/.config/opencode/AGENTS.md` is opencode's global instruction file, a hand-picked digest of `~/.claude/CLAUDE.md`, about 6.1 KB when written on 2026-09-21 and 6.4 KB on 2026-09-22 (`wc -c` for the current size), plus one rule taken from memory `feedback_format_hook_strips_new_import`, since opencode's edits now run the same post-edit hook, and two of its own with no `CLAUDE.md` counterpart, which must not be pruned as orphans: never write under `~/.claude/` or `~/dotfiles/claude/.claude/` (the roots the plugin guard protects, Claude Code itself writing memory there), and, from the first live run on the 9B, report a refused change, never redo it another way.
It holds the rules any agent can apply without Claude Code's own tools and whose breach costs most or recurs every session (hard limits, conversation, work discipline, code, gate handling), plus a table pointing to `~/.claude/rules/<lang>.md`.
Its existence also stops opencode from loading `CLAUDE.md` itself, so nothing else carries a rule change across.

**Why:** no mechanism keeps the two in sync, and the selection is a judgement no script can redo. The user accepted the drift risk against the token budget of a 9B local model, on the condition that it be handled by hand.

**How to apply:** after editing a behavioral rule in `CLAUDE.md`, grep `AGENTS.md` for it. If it is there, update it; if it is absent and matches the inclusion criterion of `~/dotfiles/.claude/DESIGN-OPENCODE-HARNESS.md` § "`AGENTS.md` keeps what any agent can apply, 2026-09-21", propose adding it. Rules about memory, plans, subagents, reviews, skills and hooks stay out, with one exception: reading a project's `.claude/PLAN.md` at session start, carried since the § "A project's `.claude/` is loaded like Claude Code loads it, 2026-09-21" of that design note. See [[project_ju_tp2_receiveonly]] for where such edits are made.
