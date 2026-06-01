---
name: skills with explicit-invocation gate
description: Skills in this marketplace whose SKILL.md description explicitly states "user-invocable only via /<command>; does not auto-trigger" use a strict invocation gate by design. Applies to workflow:* AND audit:* AND any future family. Do not propose broadening the trigger, adding synonyms, oblique-request fallbacks, FR triggers, or auto-trigger logic.
metadata:
  type: feedback
  originSessionId: 4ec4f715-2af2-4db8-982d-6cadb4c684c9
---

Skills in this marketplace whose `SKILL.md` description explicitly declares "User-invocable only via `/<command>`" or "User-invocable ONLY via `/<command>`. Does not auto-trigger ..." use a strict invocation gate **by design**. Applies regardless of skill family.

**Confirmed cases (2026-05-19 to 2026-05-28):**
- `workflow:write`, `workflow:doc-structure`, `workflow:continue`, `workflow:reco`, `workflow:sync` (workflow family)
- `audit:walkthrough`, `audit:blindspot` (audit family, added 2026-05-21)
- `audit:skill-adversary`, `audit:mcp-adversary`, `audit:sweep` (audit family, converted from auto-trigger 2026-05-28). All skills in `hebstr/claude-code-plugins` are now explicit-only.

Apply the same rule to any future skill (any family) whose description starts with the same "User-invocable only via ..." sentence.

Reviewers (skill-adversary, blindspot-review, cross-model judges) routinely flag the strict gate as a "false negative". Oblique users who describe symptoms (e.g. "reads like a robot", "où mettre mes notes pour Claude et le README", "I have 30 review findings, help me triage") never get redirected to the skill; missing FR synonyms in the exclusion list; no fuzzy match on command typos. They also flag the description as "too broad" because phrases like "any review skill" could match non-Claude sources. **Reject all such findings.**

**Why:** the user explicitly chose the strict gate. Auto-triggering on natural-language matches ("rewrite", "sound natural", "make it less AI", "réorganiser mes docs", "walk through", "triage", FR equivalents) creates constant false positives where Claude opens the skill on every prose-related, doc-related, or review-related conversation. The cost of "user doesn't know the command exists" is acceptable; the cost of "skill triggers all the time intrusively" is not. Trigger-breadth findings (description "any X" matches too much) are also moot because the trigger surface isn't exercised: the user types the command.

**How to apply:** when reviewing any `SKILL.md` whose description contains "User-invocable only via" / "User-invocable ONLY via" and "does not auto-trigger", treat any finding about trigger description breadth/narrowness, missing synonyms, oblique-request false negatives, command-typo fuzzy match, FR/multilingual trigger absence, or auto-trigger fallbacks as REJECTED with reason "explicit-invocation only by design". Apply across all reviewer skills (skill-adversary, blindspot-review, mcp-adversary if it ever scopes here, etc.). Findings about *internal* skill behavior (instruction clarity, contradictions, file structure, security, taxonomy ambiguity, gaps in workflow phases, cross-file coherence) are still valid and should be evaluated normally.

**Frontmatter `disable-model-invocation: true` is NOT the convention.** The gate is declared via the description string alone. Reject reviewer findings proposing to add `disable-model-invocation: true` to the frontmatter for alignment, "runtime enforcement", or precedent-with-write. Confirmed 2026-05-19 across `workflow/continue`, `workflow/reco`, `workflow/sync`, `workflow/doc-structure`. Even if `workflow/write/SKILL.md` historically has the flag, the canonical convention chosen by the user is description-only; do not propose adding the flag elsewhere, and do not propose removing it from `write` either (no destructive symmetry).
