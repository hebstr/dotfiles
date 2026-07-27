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

**`ouroboros_evaluate` reads `working_dir` from disk, so it must finish before any edit.** It does not judge the `artifact` in isolation: it opens the files, greps them, and quotes their live line numbers back. A call left running while the fix lands therefore evaluates the *corrected* code and returns APPROVED, which reads as "the finding is a false positive" and is the opposite of what happened. Observed 2026-07-27 on an edstr walkthrough: one L2 came back 2/3 approving on a finding that was real and already fixed, the third model (which judged the pasted snippet) rejecting it correctly. It also takes 2-5 minutes and gets moved to a background task, so the temptation to edit meanwhile is the default path. Sequence it: L2 first, edit after. If the two do overlap, discard the verdict rather than reporting it.
