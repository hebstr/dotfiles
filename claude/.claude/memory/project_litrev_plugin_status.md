---
name: litrev plugin: development paused, and separate from the hebstr marketplace
description: The two standing decisions on the litrev plugin, its pause (2026-10-26) with what serves a bibliographic search instead, and its separation from hebstr (2026-04-26)
metadata:
  type: project
---
## Development is paused and the plugin is not invoked, 2026-10-26

Stated by the user: neither `/litrev` nor its sub-skills (`litrev-search`, `litrev-screen`, `litrev-extract`, `litrev-synthesize`) nor its `litrev-mcp` server. `litrev@litrev` is already `false` in `~/.claude/settings.json`, so nothing loads it by default; do not propose enabling it.

**Why:** the tool is mid-development and the user has stopped working on it. A bibliographic need is therefore served by the always-available instruments rather than by waiting on the pipeline, and a plan that routes work to `/litrev` is blocked until the pause lifts, not merely unscheduled.

**How to apply:** for a targeted clinical search (a few questions, two or three references each, verified DOI), read the library first with the `zotero` skill, including the reference lists of the PDFs already attached, then search PubMed and verify each DOI with WebSearch and WebFetch, and record the keepers in the Zotero collection the project exports from. For a theme-level need, say that no pipeline is available and hand the scoping question to the user instead of improvising a review. In eds-prise this blocks the two `not_started` reviews of `.claude/PLAN-REVIEW.md`, facteurs de risque and pratiques cliniques; see [[feedback_litrev_pipeline_patterns]].

## It stays a separate plugin from the hebstr marketplace, 2026-04-26

`litrev` was briefly migrated into the `hebstr` marketplace, then rolled back. It is permanently a separate plugin with its own repo (`hebstr/claude-code-litrev` → `claude-code-litrev/`). Do not propose merging it back into `hebstr` without new evidence.

**Why:**
1. **Heterogeneous stack.** `litrev` ships a Python MCP server (uv, dependencies), a `workspace/` and an active `PLAN.md`. `audit` and `workflow`, the plugins the hebstr marketplace lists, are pure markdown skills. Bundling them inflates `claude-code-plugins` with unrelated infrastructure.
2. **Disjoint audiences.** `litrev` targets medical researchers and clinicians; `audit` and `workflow` target Claude Code developers. Nothing justifies coupling their versions or release cycles.
3. **Provenance already separate.** `litrev` has its own upstream repo. The migration was a subtree import from `hebstr/claude-code-litrev`, never a merge of git histories.

**How to apply:** if a future task suggests "consolidate litrev into hebstr" or "add litrev as a hebstr plugin", push back with these three reasons before doing any work. The rollback commits (`2c911ca import litrev`, `a3836d7 revert litrev`, 2026-04-26) are no longer on `claude-code-plugins` main, whose history restarts at `24aebe3 initial release` (2026-05-21); they survive only as unreachable objects a gc can drop. Marketplace mechanics learned during the rollback are in [[reference_claude_code_marketplace_mechanics]].
