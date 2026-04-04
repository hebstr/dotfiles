---
name: QMD format hook pending
description: Add .qmd formatting to PostToolUse hook once air supports chunk formatting
type: project
---

PostToolUse hook currently formats .R and .py files after Claude edits. .qmd files are not covered because air does not yet support formatting R chunks inside .qmd files.

**Why:** User works heavily with Quarto and wants consistent formatting across all file types.

**How to apply:** When air adds .qmd chunk formatting support, update the PostToolUse hook in ~/.claude/settings.json to include a *.qmd case.
