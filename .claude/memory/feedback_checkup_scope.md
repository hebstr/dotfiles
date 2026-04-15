---
name: checkup_scope
description: "audit complet du répertoire" means scan ALL files in the working directory and update anything stale
type: feedback
---

When the user asks for an "audit complet du répertoire et mets à jour ce qui est stale" (or shorter variants like "audit du répertoire", "scan complet du répertoire"), scan every file in the current working directory (and subdirectories) for staleness relative to changes made in the session. Do not limit scope to the file being actively edited.

**Why:** During an editing session, a "checkup" request was interpreted as single-file-only, missing a stale companion file (CONTEXT.md). The user had to ask a second time. Convention established: "audit complet du répertoire" is the canonical phrasing.

**How to apply:** On any audit/checkup/scan request, use `/sync-files` (or `/sync-files --deep` for cross-repo semantic consistency). This applies to any directory (skill, package, project), not just skills. Key signals: "répertoire", "dossier", "tous les fichiers", "stale" all mean directory-wide scope — delegate to sync-files rather than doing ad-hoc checks.
