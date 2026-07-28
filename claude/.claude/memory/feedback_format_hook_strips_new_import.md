---
name: The format-on-edit hook deletes an import added before its first use
description: "In Python, adding an import in one Edit and its usage in a later Edit loses the import: the format-on-edit hook runs `ruff check --fix` between the two and removes it as F401"
metadata:
  type: feedback
---

When adding a symbol that needs a new import, write the usage first and the import second, or put both in a single Edit. The `format-on-edit` hook runs `ruff check --fix` after every edit, so an import added while nothing uses it yet is deleted as F401 before the next edit lands.

**Why:** observed 2026-07-28 in `eds-avc`, adding `FileLock` and `has_note_values` to the annotation apps. The import edit reported success, the hook stripped both names, and the next edit's diagnostics came back `unresolved-reference` on code that read as correct. The hook's own report ("PostToolUse hook modified <file> after your edit (likely a formatter)") does not say what it removed, so the cause is only visible by re-reading the import block.

**How to apply:** usage first, then the import. On any `unresolved-reference` for a name just imported, re-read the import block rather than re-deriving the symbol path: the likely answer is that the import is gone. The same reasoning covers any auto-fixer wired as a post-edit hook that prunes unused code, not just ruff.
