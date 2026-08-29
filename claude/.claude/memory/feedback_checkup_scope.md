---
name: audit:sweep / workflow:sync — checkup scope is directory-wide
description: '"audit complet du répertoire" means scan every file in the working directory, not just the active file; the NOTES.md / TODO.md / CALENDRIER.md scratchpads are scanned too, and never rewritten'
metadata:
  type: feedback
---

When the user asks for an "audit complet du répertoire", "scan complet du répertoire", or similar, scan every file in the CWD (and subdirectories) for staleness. Do not limit scope to the file being actively edited.

The one carve-out is on output, not on input: `NOTES.md`, `TODO.md` and `CALENDRIER.md` are read like any other file at every depth, and the sweep never writes to them. A staleness they carry is reported to the user, who fixes it. Rule and rationale in CLAUDE.md and [[feedback_personal_working_files]].

**Why:** A "checkup" request was interpreted as single-file-only, missing a stale CONTEXT.md. User had to ask a second time.

**How to apply:** Any audit/checkup/scan request → list directory contents first, then check each file, the three gated basenames above included as read-only. Signals: "répertoire", "dossier", "tous les fichiers", "stale" all mean directory-wide scope.
