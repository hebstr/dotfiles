---
name: audit:sweep / workflow:sync — checkup scope is directory-wide
description: '"audit complet du répertoire" means scan every file in the working directory, not just the active file, minus the NOTES.md / TODO.md read-gate'
metadata:
  type: feedback
---

When the user asks for an "audit complet du répertoire", "scan complet du répertoire", or similar, scan every file in the CWD (and subdirectories) for staleness. Do not limit scope to the file being actively edited.

The one carve-out: `NOTES.md` and `TODO.md` stay out of the sweep at every depth, even when they sit in the working directory or the uncommitted-file list. Report them as skipped rather than opening them. Rule and rationale in CLAUDE.md and [[feedback_personal_working_files]].

**Why:** A "checkup" request was interpreted as single-file-only, missing a stale CONTEXT.md. User had to ask a second time.

**How to apply:** Any audit/checkup/scan request → list directory contents first, then check each file except the two gated basenames above. Signals: "répertoire", "dossier", "tous les fichiers", "stale" all mean directory-wide scope.
