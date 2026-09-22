---
name: litrev stays a separate plugin from hebstr marketplace
description: Decision (2026-04-26) to NOT bundle the litrev plugin into the hebstr marketplace, with the three reasons; prevents re-proposing the merge in future sessions
metadata:
  type: project
---
`litrev` was briefly migrated into the `hebstr` marketplace, then rolled back. It is permanently a separate plugin with its own repo (`hebstr/claude-code-litrev` → `claude-code-litrev/`). Do not propose merging it back into `hebstr` without new evidence.

**Why:**
1. **Heterogeneous stack.** `litrev` ships a Python MCP server (uv, dependencies), a `workspace/` and an active `PLAN.md`. `audit` and `workflow`, the plugins the hebstr marketplace lists, are pure markdown skills. Bundling them inflates `claude-code-plugins` with unrelated infrastructure.
2. **Disjoint audiences.** `litrev` targets medical researchers and clinicians; `audit` and `workflow` target Claude Code developers. Nothing justifies coupling their versions or release cycles.
3. **Provenance already separate.** `litrev` has its own upstream repo. The migration was a subtree import from `hebstr/claude-code-litrev`, never a merge of git histories.

**How to apply:** if a future task suggests "consolidate litrev into hebstr" or "add litrev as a hebstr plugin", push back with these three reasons before doing any work. The rollback commits (`2c911ca import litrev`, `a3836d7 revert litrev`, 2026-04-26) are no longer on `claude-code-plugins` main, whose history restarts at `24aebe3 initial release` (2026-05-21); they survive only as unreachable objects a gc can drop. Marketplace mechanics learned during the rollback are in [[reference_claude_code_marketplace_mechanics]].
