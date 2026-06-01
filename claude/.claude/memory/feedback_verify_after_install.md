---
name: Verify tools after install or config
description: After installing a tool, creating a hook, or configuring a new integration, always verify it actually works end-to-end before considering the task done
metadata:
  type: feedback
---

After setting up any new tool, hook, or integration, always run a smoke test to verify it works end-to-end. Never consider the task complete without verification.

**Why:** A formatting hook (air/ruff) was configured with `2>/dev/null`, masking the fact that `air` wasn't in PATH. The hook silently failed for an unknown period. A feature that fails silently is worse than no feature: it gives false confidence.

**How to apply:**
- After installing a binary: confirm it's in PATH (`which <tool>`)
- After configuring a hook: trigger it and verify the output changed as expected
- Never suppress stderr on new integrations until they're confirmed working
- If a command uses `2>/dev/null` or `|| true`, flag it and ask whether silent failure is intentional
