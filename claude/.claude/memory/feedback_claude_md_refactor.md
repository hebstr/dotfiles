---
name: CLAUDE.md Progressive Disclosure refactor calibration
description: When refactoring CLAUDE.md under HumanLayer's instruction-budget framework (extraction to rules/*.md), do not extract always-on safety-net checklists coupled to inline triggers, and prefer prose pointers over hook automation when operational behavior is identical
type: feedback
---

When refactoring `~/.claude/CLAUDE.md` to reduce its instruction count toward the HumanLayer "uniform decay" budget (~150–200 for thinking models, see [[reference_claude_code_best_practices]]), do **not** propose any of the following:

1. **Extracting always-on safety-net checklists to on-demand `rules/*.md`** even when the instruction-count gain is real. The post-change greps block (CLAUDE.md "Plan & memory discipline") is the canonical example: 6 numbered sub-items coupled to an inline trigger ("After a structural change, verify consistency..."). The failure mode is silent — Claude doesn't know it forgot to grep until the doc/test rots. Always-on cost ~7 instructions counted is acceptable when (a) the content is short, (b) it's tightly coupled to a behavior gate one bullet above. Both conditions hold for safety-net checklists by definition.

2. **Adding a SessionStart/PostToolUse hook that parses `paths:` frontmatter in `rules/*.md`** to auto-load matching files. A prose pointer in CLAUDE.md covers 95% of the operational behavior at ~1 line / 0 instructions counted. The hook adds: (a) script authoring + testing cost, (b) maintenance of glob-matching logic, (c) failure mode if the hook bugs out silently. The deterministic-load gain over Claude-reads-pointer is marginal; it's over-engineering. Suppression of the now-ornamental `paths:` frontmatter in `rules/python.md`/`shell.md`/`r.md` is a separate question (probably yes, in a future cleanup pass) — but writing a hook to revive it is the wrong move.

**Why:** the 2026-05-16 walkthrough on the CLAUDE.md Progressive Disclosure refactor produced 7 findings; 2 (29%) matched these patterns. Pattern 1 came from undervaluing the silent-failure cost of forgotten checklists. Pattern 2 came from treating the dead frontmatter (`paths:` unread by any hook) as a problem to fix rather than a tombstone to either ignore or remove. Both rejections turned on the same principle: instruction count is a budget, not a goal — gains that come at the cost of compliance safety or maintenance burden are net negative regardless of the arithmetic.

**How to apply:** in any future CLAUDE.md refactor under the instruction-budget framework, before proposing an extraction or automation, ask:
- For extraction: "If Claude never loads this rules file, does the always-on behavior still hold?" If no → keep inline.
- For automation: "Does the same behavior already work via prose pointer or Claude's default reading?" If yes → do not automate.

Real refactor wins still apply: extracting context-specific content (secrets handling, showboat, env reference) that doesn't gate ongoing behavior, splitting bundled multi-rule bullets into atomic rules **when** there's no consolidation alternative, pruning genuinely dead sections.

Related: [[feedback_review_severity_claude_config]] (review calibration for CLAUDE.md *content* audits), [[feedback_review_severity_claude_rules]] (review calibration for `rules/*.md` files), [[reference_claude_code_best_practices]] (HumanLayer mechanism + budget figures).
