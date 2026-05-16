---
name: reference-todo-sync
description: Centralized TODO aggregation system via the todo-sync shell command
metadata:
  type: reference
---

The user maintains TODO lists per project as `TODO.md` at any depth under `$HOME`, plus a personal TODO at `~/Documents/pro/notes/TODO.md`.

`todo-sync` (shell command, installed via stow from `~/dotfiles/bin/.local/bin/todo-sync`) prints all `TODO.md` items to stdout sorted by priority tier (P0 → P1 → P2), then by project, then by source order within each (tier, project). No persistent file output. Manual trigger only, never automatic. Excludes vendoring paths (`*library*`, `node_modules`, `.venv`, `venv`, `site-packages`, `vendor`).

**Output mode is auto-detected:** TTY stdout → padded columns with ANSI colors (P0 bold red, P1 yellow, P2 default; `bloqué` red, `en cours` cyan; status appears as `[bracketed tag]` after the item, omitted if empty). Pipe/redirect stdout → markdown table (`Prio | Projet | Item | Statut`) suitable for `grep`, `glow`, or `> file.md`. `NO_COLOR=1` disables colors in TTY mode while keeping padding.

Project column shows only the last 2 path segments (`parent/leaf`) of the TODO.md location; personal TODO renders as `Perso`. TODO.md files yielding no rows are listed at the bottom in two distinct sections: byte-empty placeholders under `Fichiers vides`, and non-empty files without any `## P0/P1/P2` sections under `Fichiers non conformes`. Either section is omitted when empty.

**TODO.md format convention.** Items classified by priority tier as H2 sections: `## P0` (critical, drop everything), `## P1` (important, this week), `## P2` (normal). No archive section, no `## Fait`. Items are checkbox-prefixed (`- [ ]`, `- [x]` skipped at inlining). Status (blocked, in progress) is an inline annotation at end of line: `- [ ] item *(bloqué : reason)*`; the table's Statut column shows only the part before ` : ` (short label). Multi-axis projects use an item-level prefix (`- [ ] streamlit : audit`) rather than H3 sub-axes. Source order within each tier is preserved in the aggregate, so reordering items in `TODO.md` is how fine-grained priority is expressed. Template lives at `~/Documents/pro/notes/TODO-template.md`.

When the user mentions "INBOX", "todo-sync", or "the aggregated TODOs", this is the system in scope. New projects opt in implicitly by creating a `TODO.md` at the desired location.
