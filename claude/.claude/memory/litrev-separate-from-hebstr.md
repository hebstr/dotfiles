---
name: litrev stays a separate plugin from hebstr marketplace
description: Decision (2026-04-26) to NOT bundle the litrev plugin into the hebstr marketplace, with the three reasons — prevents re-proposing the merge in future sessions
metadata:
  type: project
  originSessionId: e3cb33c3-05ad-4318-aa10-31d456904d95
---
`litrev` was briefly migrated into the `hebstr` marketplace, then rolled back. It is permanently a separate plugin with its own repo (`hebstr/claude-code-litrev` → `claude-code-litrev/`). Do not propose merging it back into `hebstr` without new evidence.

**Why:**
1. **Stack hétérogène** — `litrev` embarque un MCP Python (uv, deps), un `workspace/`, un `PLAN.md` actif. `review` and `workflow` (the actual hebstr plugins) are pure markdown skills. Bundling them inflates `claude-code-plugins` with unrelated infra.
2. **Audiences disjointes** — `litrev` cible des chercheurs médicaux/cliniciens. `review`/`workflow` ciblent des devs Claude Code. Pas de raison de coupler les versions ou les release cycles.
3. **Provenance déjà séparée** — `litrev` a sa propre repo upstream. La migration consistait à importer en subtree depuis `hebstr/claude-code-litrev`, jamais à fusionner les histoires git.

**How to apply:** if a future task suggests "consolidate litrev into hebstr" or "add litrev as a hebstr plugin," push back with these three reasons before doing any work. Audit trail of the rollback is in `git log` (commits `2c911ca import litrev` then `a3836d7 revert litrev` on `claude-code-plugins` main, 2026-04-26). Marketplace mechanics learned during the rollback are in `claude-code-marketplace-mechanics.md`.
