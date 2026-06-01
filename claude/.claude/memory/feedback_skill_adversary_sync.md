---
name: skill-adversary calibration for workflow:sync
description: False positives to filter when running skill-adversary on workflow:sync SKILL.md
metadata:
  type: feedback
---

When reviewing workflow:sync with skill-adversary, do not flag:

- `disable-model-invocation` as assumed context — it is a standard Claude Code skill frontmatter key
- The `CONTEXT.md` dependent in the heuristic table as ecosystem-specific — expected by design
- The Grep catch-all as insufficient for unlisted file types — the heuristic table is a domain boost, Grep covers the rest
- Minor count ambiguities in report templates (e.g. "Scanned: M dependents") — live sessions count actual files
- Edge cases two levels deep in fallback paths (no git + wrong filenames) — obvious behavior
- `find 2>/dev/null` as hiding partial results — runs in user's own project directory
- `disable-model-invocation: true` and "must be executed by the main model" as contradictory — complementary (auto-trigger vs delegation)

**Why:** These patterns were systematically rejected during the 2026-03-31 skill-adversary review as false positives from a context-unaware adversarial critic.

**How to apply:** Pre-filter findings matching these patterns before escalating.
