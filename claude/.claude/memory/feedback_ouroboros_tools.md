---
name: ouroboros-trigger-consensus
description: Which Ouroboros tools support trigger_consensus — prevents misuse of ouroboros_qa for cross-model judging
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3ef374d8-3a74-4711-9602-936f87a382de
---

**trigger_consensus cross-model:** Only `ouroboros_evaluate` supports `trigger_consensus: true` for cross-model consensus via OpenRouter. `ouroboros_qa` does NOT — the parameter is silently ignored, producing a same-model result that looks cross-model but isn't.

**Why:** Discovered 2026-03-31 during review-walkthrough session. The skill incorrectly instructed using `ouroboros_qa` with `trigger_consensus: true`.

**How to apply:** Cross-model consensus → `ouroboros_evaluate`. Same-model QA → `ouroboros_qa` without `trigger_consensus`.
