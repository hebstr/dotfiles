---
name: audit:sweep / workflow:sync — checkup scope is directory-wide
description: '"audit complet du répertoire" means scan ALL files in the working directory, not just the active file'
metadata:
  type: feedback
---

When the user asks for an "audit complet du répertoire", "scan complet du répertoire", or similar, scan every file in the CWD (and subdirectories) for staleness. Do not limit scope to the file being actively edited.

**Why:** A "checkup" request was interpreted as single-file-only, missing a stale CONTEXT.md. User had to ask a second time.

**How to apply:** Any audit/checkup/scan request → list directory contents first, then check each file. Signals: "répertoire", "dossier", "tous les fichiers", "stale" all mean directory-wide scope.
