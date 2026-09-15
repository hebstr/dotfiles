---
name: ouroboros-trigger-consensus
description: Which Ouroboros tools support trigger_consensus — prevents misuse of ouroboros_qa for cross-model judging; and under the Ouroboros plugin's own `claude_code` backend that consensus is Claude voting under other models' labels (verified on 0.54.4, 2026-09-15)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3ef374d8-3a74-4711-9602-936f87a382de
---

**trigger_consensus cross-model:** Only `ouroboros_evaluate` supports `trigger_consensus: true` for cross-model consensus via OpenRouter. `ouroboros_qa` does NOT — the parameter is silently ignored, producing a same-model result that looks cross-model but isn't.

**Why:** Discovered 2026-03-31 during review-walkthrough session. The skill incorrectly instructed using `ouroboros_qa` with `trigger_consensus: true`.

**How to apply:** Cross-model consensus → `ouroboros_evaluate`. Same-model QA → `ouroboros_qa` without `trigger_consensus`. But read the correction below before counting that consensus as cross-model.

**Corrected 2026-09-15: under the plugin's own MCP launch, that consensus is not cross-model either.** The Ouroboros plugin's `.mcp.json` (0.54.4) starts the server with `--llm-backend claude_code`, and `ClaudeCodeAdapter._normalize_model` maps every `openrouter/<non-anthropic>/...` voter to `None`, the default Claude model. The CLI transcripts of the three votes of one 2026-09-15 round were all `claude-opus-5`, while the result labelled them `gpt-4o`, `claude-opus-5`, `gemini-2.5-pro`: the label is the requested model, not the served one. Editing `consensus` in `~/.ouroboros/config.yaml` changes nothing under that backend, and the `litellm` backend is not a way out, its extra being pinned to `python_version < '3.14'` while the plugin launches 3.14. For a real cross-provider verdict, call OpenRouter directly, as `audit:walkthrough` L2 does since that date with `audit/walkthrough/scripts/openrouter-verdict.py` (see [[feedback_audit_walkthrough]]). Versions before 0.54.4 not checked.

**`ouroboros_evaluate` reads `working_dir` from disk, so it must finish before any edit.** It does not judge the `artifact` in isolation: it opens the files, greps them, and quotes their live line numbers back. A call left running while the fix lands therefore evaluates the *corrected* code and returns APPROVED, which reads as "the finding is a false positive" and is the opposite of what happened. Observed 2026-07-27 on an edstr walkthrough: one L2 came back 2/3 approving on a finding that was real and already fixed, the third model (which judged the pasted snippet) rejecting it correctly. It also takes 2-5 minutes and gets moved to a background task, so the temptation to edit meanwhile is the default path. Sequence it: evaluate first, edit after. If the two do overlap, discard the verdict rather than reporting it.
