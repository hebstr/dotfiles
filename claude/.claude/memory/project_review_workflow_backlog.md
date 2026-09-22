---
name: Review workflow remaining backlog
description: Implementation backlog from the March 2026 code review glowup audit (practices section removed, already covered by walkthrough and CLAUDE.md "Build discipline" section)
metadata:
  type: project
---

Remaining implementation items from the multi-agent code review audit (2026-03-25).

Listed here for reference; they belong in a proper issue tracker.

## Backlog

- CI/CD: GitHub Actions with lint + tests + quarto render on `hebstr` (still no `.github/workflows/` on 2026-09-22; the test files the backlog once listed, `str_helpers`, `easy_descr`, `gt_heatmap`, all exist by then)
- Runtime data validation: pointblank (R) / pandera (Python) in pipelines
- Occasional human review: rOpenSci community, biostat peers (quarterly on critical code)
- LLM-generated tests as alternative to code review
- Quarterly architecture review: emergent patterns, tech debt

## Removed items (already covered)

- ~~Human triage 2 min between reviewer and walkthrough~~ (handled by `/audit:walkthrough` severity reordering + author's defense gating)
- ~~Pre-mortem 3-5 lines~~ (overlaps with CLAUDE.md "Before marking any step done, verify the output is usable" + walkthrough author's defense)
- ~~ADR (Architecture Decision Records)~~ (covered by the named anchor pattern ("Decision: X because Y") of CLAUDE.md "Build discipline")
- ~~Reviewer prompt variants by code type~~ (the reviewer choice now lives in step 0.3 of `skills/commit/SKILL.md`, `--reviewer posit-dev:critical-code-reviewer`, and in the `/audit:walkthrough` reviewer scan)
