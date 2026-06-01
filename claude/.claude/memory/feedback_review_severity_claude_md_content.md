---
name: Review calibration for CLAUDE.md content audits
description: When auditing the rules/instructions in CLAUDE.md (not config artifacts), do not flag intentional trade-offs as gaps, demand opt-outs against the user's stated preference, re-document triggers owned by upstream systems, or treat harness-backstopped efficiency hints as correctness bugs
metadata:
  type: feedback
---

When reviewing or auditing the *content* of `~/.claude/CLAUDE.md` (the rules and instructions text, as opposed to settings.json / hooks / config artifacts), do **not** propose any of the following:

1. **Under-defined term flagged when the term is anchored by combined positive+negative criteria across distinct ceremonies.** Example: "non-trivial task" (used as trigger in pre-design, lint/format gate, test proposal). L92 gives negative criteria (bugfixes, one-liners, typos, explicitly-scoped edits); L107 gives positive criteria (new file, public function, script under `bin/`, modified logic). The two rules govern distinct ceremonies (pre-design vs lint/format/test), each with its own exclusion set. Apparent ambiguity in the shared trigger word is intentional asymmetry, not a wording gap. Cross-model L2 consensus (2-1 APPROVE on 2026-05-16) confirmed.

2. **"Add a fallback / opt-out for user override" when the current default reflects the user's stated preference.** Example: "what if the user doesn't want `.claude/` created in a fresh repo?" The user always wants `.claude/`, no root fallback needed. Defaults can be hardened (always-create) but not softened with hypothetical opt-outs the user does not want. Confirm the user's preference before proposing a fallback.

3. **"Trigger undefined" flagged when the trigger is owned by an upstream system.** Example: "when does Claude write a memory file?" is handled by the auto-memory system in the harness prompt, not CLAUDE.md. CLAUDE.md correctly stays in its lane (location: global vs project; source: CLAUDE.md vs memory). Re-documenting upstream-owned triggers in CLAUDE.md adds defensive prose without behavioral value and creates drift risk when the upstream changes.

4. **"Self-contradiction risk" flagged when the apparent contradiction is the deliberate cost of bias-catching or discipline.** Example: L126 re-evaluate-before-recommending can produce mid-response shifts (lean one way, then revise). This is the calibrated cost of doing actual deliberation; the alternative (commit to first take) ships worse recommendations. The "erratic appearance" critique is the surface cost the user accepted, not a flaw.

5. **"Cross-turn intent / state-dependence" flagged when a harness backstop makes the worst case efficiency, not correctness.** Example: L28 "Read should go to the real path when the next step is an edit". The stow-symlink write refusal in the harness enforces correctness; the Read-via-real-path instruction is an efficiency hint that saves one round-trip on failure. Critique that "LLM may forget cross-turn intent" describes a performance regression, not a correctness gate.

6. **"Document length / cognitive limit" flagged as a Walking-time fix.** Substantial offloading (sections moved to `rules/*.md`) is a structural refactor touching multiple files; it belongs in its own audit, not inline during a content walkthrough. Accept in-walkthrough fixes that incidentally reduce length (e.g., removing an embedded auto-generated block); reject proposals to move whole sections as out-of-scope.

**Why:** the 2026-05-16 `/audit:blindspot` + walkthrough on CLAUDE.md walked 18 Critical+Important findings (2 Critical + 16 Important). 6 of the 18 (33%) were rejected as patterns matching the categories above. All 6 patterns turn on the same underlying issue: the reviewer (Gemini in Phase 1, Claude skill-adversary in Phase 1, Claude again at walkthrough re-evaluation) treats intentional trade-offs as defects. CLAUDE.md is a hand-tuned instruction file where most surface "gaps" are calibrated calls; the reviewer's defaults (defensiveness, opt-outs, exhaustive specification) push against that calibration.

**How to apply:** in any future audit of `~/.claude/CLAUDE.md` content (skill-adversary, blindspot, critical-code-reviewer applied to the file), skip these six categories of suggestion immediately. They are recurring false positives. Real findings still apply: factual errors in instructions (wrong tool name, wrong command flag, broken algorithm description), violations of the file's own rules (em dashes in prose per L132, marketing copy per L118), missing fallbacks where no harness backstop exists, and contradictions between explicit rules (not between rule and apparent edge case).

Related: [[feedback_review_severity_claude_config]] (config artifacts: settings.json, hooks), [[feedback_review_severity_claude_rules]] (`.claude/rules/*.md` files), [[feedback_claude_md_refactor]] (CLAUDE.md instruction-budget refactor calibration), [[feedback_review_severity_skill_audits]] (SKILL.md audits).
