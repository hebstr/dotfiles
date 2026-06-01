---
name: External config pattern import discipline
description: Before importing a pattern, format, or rule from an external Claude Code config (audit communautaire), identify the consumer that justifies it. If the consumer doesn't exist locally, the format adds friction without gain
metadata:
  type: feedback
---

When evaluating a pattern, format, or rule extracted from an external Claude Code config audit (aaddrick, vsbuffalo, solatis, etc.), do **not** import it without first identifying the **consumer in the source system that justifies the format**. Imports without a downstream consumer add friction without gain: they alter inputs without altering behavior.

Concrete sub-patterns flagged in audits to date:

1. **Structured XML formats** (e.g. `<principle>` / `<violations>` / `<threshold>` blocks): justified at solatis by `lib/workflow/quality_docs.py` which parses these tags by regex. Without that parser locally, plain markdown bullets convey the same information for Claude reading the rule in natural language. No gain.

2. **Strict JSON schemas for plan documents** (e.g. solatis `planner` plan.json with referential integrity between `intent_ref` and `decision_ref`): justified by an automated QR (Quality Reviewer) workflow that consumes the structured plan. Without that consumer, the schema is boilerplate that slows PLAN.md drafting for no behavioral change.

3. **Scripted output templates** (e.g. solatis `direct.md` "This won't work because… Alternative:… Proceed?" verbatim format): when the atomic components already exist as separate rules ("no hedging" + "no apology" + "concise"), composing them into a scripted template adds a third layer that prescribes form for cases the atomic rules already cover.

4. **Anticipatory conventions** (e.g. solatis "CLAUDE.md projet = index pur, README.md = explicatif"): justified by their `doc-sync` skill which enforces the convention at audit time. Without porting the skill (or having a concrete instance to enforce it against), the convention is prescription for a hypothetical artifact that doesn't yet exist.

**Why:** during the 2026-05-16 walkthrough of the solatis audit, 4 of 5 REJECTED findings matched this single meta-pattern (output-style, CLAUDE.md=index, PLAN.md constraints, principle/threshold format). Same pattern surfaced repeatedly in aaddrick (2026-05-16) and vsbuffalo (2026-05-16) audits but was diagnosed case-by-case, not consolidated. This memory consolidates the diagnostic into a reusable filter.

**How to apply:** before accepting "we should import pattern X from source S," answer:
- What system in S consumes X? (parser, automated workflow, downstream agent, enforced convention)
- Does that consumer exist locally? (have I ported it, or is it on my backlog?)
- If neither: the import alters inputs without altering behavior. REJECT or DEFER until the consumer exists.

Real imports still apply: a discrete behavioral rule that changes Claude's output (e.g. solatis `temporal.md` "comments must read timeless" → ACCEPTED at point 2 of the walkthrough because it changes how Claude writes comments, regardless of any consumer system). The filter targets *formal scaffolding without a parser*, not *substantive rules*.

Related: [[feedback_review_severity_claude_rules]] (calibration for `.claude/rules/` reviews), [[feedback_review_severity_claude_config]] (harness audit calibration). This memory covers external-config import decisions, complementary to those two which cover internal-audit calibration.
