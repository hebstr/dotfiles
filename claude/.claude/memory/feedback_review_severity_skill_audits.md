---
name: Review calibration for Claude Code skill audits
description: When auditing SKILL.md files (skill-adversary, blindspot, walkthrough on skills), reject four recurring false-positive patterns: harness portability hedging, declared-prior anchoring concerns, CLAUDE.md duplication for tool-call narration, and explicit-invocation false-negatives
type: feedback
---

When reviewing or auditing `SKILL.md` files in `claude-code-plugins/` (and similar Claude Code skill repos), do **not** apply the following patterns from external/cross-model reviewers:

1. **Hypothetical-harness portability hedging.** Findings like "the skill assumes parallel agent calls in one message — might break in a harness that doesn't support that" are not actionable. The skill targets Claude Code, where parallel `Agent` tool calls in one assistant message are a documented, standard pattern (explicit in CLAUDE.md and used by every workflow skill in this repo). Portability to hypothetical reduced-capability MCP harnesses is not a goal.

2. **"My take" / declared-prior framed as anchoring.** When a skill instructs the model to write its prior recommendation before consulting external evidence, external reviewers (esp. Gemini) often flag this as "anchoring bias — synthesize all evidence at once instead." This mischaracterizes the design: the prior is an *audit trail* (declared prior + explicit update), not the final answer. The Final recommendation section is where all-evidence synthesis happens. Reject these findings — the two-pass structure is the safer epistemic shape.

3. **Restating CLAUDE.md global rules inside individual skills.** Findings like "the skill doesn't tell the model to issue a 'starting research now' message before long operations" duplicate the global CLAUDE.md rule ("Before your first tool call, state in one sentence what you're about to do"). Reject — CLAUDE.md is loaded every session; per-skill restatements drift and bloat.

4. **Explicit-invocation false-negatives.** Trigger-attacker (or any reviewer) finding that "a user who phrases their request obliquely, in casual French, or without trigger keywords won't get the skill" is by design for `/workflow:*` skills that ship with `disable-model-invocation: true`. The light-mode equivalent (always-on, no command needed) lives in CLAUDE.md as a communication rule; the skill is for users who explicitly want the heavier output. Applies to every `/workflow:*` skill, not just `workflow:write`.

**Why:** the 2026-05-12 `/blindspot workflow/reco --reviewer skill-adversary` walkthrough produced 17 findings, 4 of which (24%) matched exactly these four patterns. They sound principled but ask the skill to either fight its host harness, abandon a deliberate epistemic structure, duplicate global rules, or undo the explicit-invocation gate that is the entire point.

**How to apply:** in any future skill-adversary, blindspot, or sweep audit on a `SKILL.md`, skip these four categories of suggestion immediately. Real findings still apply: least-privilege violations in `allowed-tools` (this is exactly the kind of blindspot cross-model review surfaces well), missing failure handling for sub-agents, ambiguous or operationally vague instructions, contradictions across sections, broken tool references after frontmatter changes.
