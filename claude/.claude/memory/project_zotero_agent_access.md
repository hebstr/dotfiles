---
name: Zotero read access for Claude Code agents
description: Decision 2026-09-23 on how agents read the Zotero 10 library (skill + local API by curl, full text from .zotero-ft-cache by rg, no MCP server); research and decision in one note, do not redo them
metadata:
  type: project
---

On 2026-09-23 a `/workflow:reco` research then a `/cadrer` pass settled agent read access to the Zotero library (Zotero 10.0.3, `~/Zotero`, 295 PDFs, Better BibTeX).
Decision: no MCP server. A `zotero` skill in `claude/.claude/skills/` gives agents `curl` GET recipes against the local API (`localhost:23119/api/users/0/...`) and `rg` recipes over `~/Zotero/storage/*/.zotero-ft-cache`. The pref `extensions.zotero.httpServer.localAPI.enabled` goes to `true` in the `zotero` stow package's `user.js`, and `permissions.deny` blocks Better BibTeX JSON-RPC. This reverses the provisional Zoteus choice made the same day.
Usages in scope: find a reference and its citation key, search full text and quote a passage, get a PDF path for `rules/pdf.md`. Litrev export is out for now (user, 2026-09-23); annotations and notes have no content to serve.
Nothing is implemented yet and the local API is still off. First implementation step: test the needed GET routes live before writing the skill.
Research, decision, rejected options and sources: `~/dotfiles/_meta/notes/zotero-agent-access-reco.md`, section "Les agents passent par un skill et l'API locale, sans serveur MCP".

**Why:** agents have Bash, so an MCP read-only switch adds nothing: the real write lock is Zotero refusing local API writes until the user grants a key. A skill is versioned in dotfiles and also reaches opencode, which keeps MCP servers out (`.claude/DESIGN-OPENCODE-HARNESS.md`, 2026-09-21). Zotero 10 runs `zotero.sqlite` in WAL under a hardcoded exclusive lock, so direct SQLite reads while Zotero runs are locked, stale or racy.

**How to apply:** if the subject returns, read the note rather than rerun the research or the framing. If a needed API route fails, reopen the framing on that usage instead of switching to an MCP server, which would use the same API. Never grant a local API write key to an agent, and read SQLite only with Zotero closed, in `mode=ro` without `immutable`. [[project_ubuntu_26_04_migration]] follows the same note-plus-pointer pattern.
