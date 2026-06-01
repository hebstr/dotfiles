---
name: feedback-edit-proposal-format
description: When proposing edits to any file, call the Edit tool directly and let the permission prompt render the diff. Do not duplicate the diff as prose "before/after" blocks in the chat.
metadata:
  type: feedback
---

When proposing edits to any file (CLAUDE.md, rules/*.md, memory files, code files, anything), call the Edit tool directly and let the IDE/CLI permission prompt render the diff. The user approves or denies in the UI.

Do NOT:
- Write "### Avant" / "### Après" blocks in chat
- Reproduce old_string and new_string as separate code blocks in prose
- Write multi-paragraph justification of the change before the tool call

DO:
- A single short line stating the intent ("Je remplace la règle X par Y" or "Édit sur ligne 82").
- Then call Edit directly.
- After the edit lands, a brief confirmation if useful.

**Why**: the permission prompt already renders a readable diff. Duplicating it in prose creates console noise the user explicitly rejected (2026-05-21 session). The earlier "diff-presentation" rule in CLAUDE.md (now revised) was overengineered.

**How to apply**: every edit, every file, every project (code, config, prose, memory). No exception for "important" files like CLAUDE.md: the gate for high-impact files is *still* user approval, but approval flows through the permission prompt, not through duplicated prose blocks in chat. The CLAUDE.md rule for editing Claude-config files (ligne 82) defers to the universal format rule in the Communication section.

Related: [[feedback-claude-md-edits]] (if/when written).

**Drift pattern to resist**: when the user requests sequential, case-by-case review of edits, this is **not** a license to write before/after prose blocks. It licenses sequential Edit calls (one tool call per edit, paced by user validation), not prose duplication. The validation gate remains the permission prompt regardless of pacing.
