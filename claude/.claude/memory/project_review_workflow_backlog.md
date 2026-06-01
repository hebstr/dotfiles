---
name: Review workflow remaining backlog
description: Implementation backlog from the March 2026 code review glowup audit (practices section removed, already covered by walkthrough and CLAUDE.md "Build discipline" section)
metadata:
  type: project
---

Remaining implementation items from the multi-agent code review audit (2026-03-25).

Listed here for reference; they belong in a proper issue tracker.

## Backlog

- Tests for `hebstr` R package (`~/Documents/pro/packages/R/hebstr/`): `test-easy_fct.R` done; remaining: `str_helpers.R`, `easy_descr.R`, `gt_heatmap.R`
- CI/CD: GitHub Actions with lint + tests + quarto render on `hebstr` (no `.github/workflows/` as of 2026-05-16)
- Runtime data validation: pointblank (R) / pandera (Python) in pipelines
- Occasional human review: rOpenSci community, biostat peers (quarterly on critical code)
- LLM-generated tests as alternative to code review
- Quarterly architecture review: emergent patterns, tech debt

## Removed items (already covered)

- ~~Human triage 2 min between reviewer and walkthrough~~ (handled by `/audit:walkthrough` severity reordering + author's defense gating)
- ~~Pre-mortem 3-5 lines~~ (overlaps with CLAUDE.md "Before marking any step done, verify the output is usable" + walkthrough author's defense)
- ~~ADR (Architecture Decision Records)~~ (covered by CLAUDE.md L111 named anchor pattern ("Decision: X because Y"))
- ~~Reviewer prompt variants by code type~~ (adopted via CLAUDE.md L95-97 (`critical-code-reviewer` / `skill-adversary` / `blindspot`))
