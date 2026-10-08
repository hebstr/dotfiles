---
name: reference-todo-sync
description: Centralized TODO aggregation system via the todo-sync shell command
metadata:
  type: reference
---

The user maintains TODO lists per project as `TODO.md` at any depth under `$HOME`, plus two special-cased files: `~/admin/TODO.md` (admin group, sorted first) and `~/notes/TODO.md` (notes group, sorted last). All other projects form the middle group.

`todo-sync` (shell command, installed via stow from `~/dotfiles/bin/.local/bin/todo-sync`) prints all `TODO.md` items to stdout sorted by group (admin=0, project=1, notes=2), then by priority tier (P0 → P1 → P2), then by project, then by source order within each (tier, project). No persistent file output. Manual trigger only, never automatic. Excludes vendoring paths (`*library*`, `node_modules`, `.venv`, `venv`, `site-packages`, `vendor`).

Output mode is auto-detected, a TTY getting padded coloured columns and a pipe a markdown table; the exact columns, colours and separators are in `bin/.local/bin/todo-sync` and pinned by `_meta/tests/todo-sync.bats`.

A TODO.md yielding no rows is reported in a diagnostic section rather than passed over: byte-empty placeholders apart from non-empty files that carry no `## P0/P1/P2` heading. A file whose items are all checked is not flagged.

**TODO.md format convention.** Items classified by priority tier as H2 sections: `## P0` (critical, drop everything), `## P1` (important, this week), `## P2` (normal). No archive section, no `## Fait`. Items are checkbox-prefixed (`- [ ]`, `- [x]` skipped at inlining). Status (blocked, in progress) is an inline annotation at end of line: `- [ ] item *(bloqué : reason)*`; the Statut column (the bracketed tag in TTY mode) shows only the part before ` : ` (short label). Multi-axis projects use an item-level prefix (`- [ ] streamlit : audit`) rather than H3 sub-axes. Source order within each tier is preserved in the aggregate, so reordering items in `TODO.md` is how fine-grained priority is expressed.

When the user mentions "INBOX", "todo-sync", or "the aggregated TODOs", this is the system in scope. New projects opt in implicitly by creating a `TODO.md` at the desired location.
