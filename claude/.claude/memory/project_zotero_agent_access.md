---
name: Zotero read access for Claude Code agents
description: Decision 2026-09-23 on how agents read the Zotero 10 library (local API via Zoteus read-only, full text from .zotero-ft-cache); full research already done, do not redo it
metadata:
  type: project
---

On 2026-09-23 a full `/workflow:reco` research covered giving Claude Code agents read access to the Zotero library (Zotero 10.0.3, `~/Zotero`, 295 PDFs, Better BibTeX).
Decision: Zotero local API (`localhost:23119/api/`) served by Zoteus (`oscardvs/zoteus`) with `ZOTEUS_READ_ONLY=true` and no cloud key; full text from the `.zotero-ft-cache` files; no pre-extraction and no vector index for now. Fallback: `54yyyu/zotero-mcp` with its write tools in `permissions.deny`.
Nothing is installed yet and the local API is still off (Settings → Advanced).
Research, local measurements and sources: `~/dotfiles/_meta/notes/zotero-agent-access-reco.md`.

**Why:** Zotero 10 runs `zotero.sqlite` in WAL under a hardcoded exclusive lock, so direct SQLite or DuckDB reads while Zotero runs are either locked, stale (`immutable=1` ignores the WAL) or a racy copy. `fulltext.sqlite` is a contentless FTS5 index that returns no text. The local API reads live data and refuses writes until the user grants a key.

**How to apply:** if the subject returns, read the note rather than rerun the research. Never grant a local API write key to an agent, never expose Better BibTeX JSON-RPC raw (unauthenticated methods with side effects), and read SQLite only with Zotero closed, in `mode=ro` without `immutable`. [[project_ubuntu_26_04_migration]] follows the same note-plus-pointer pattern.
