---
name: Review workflow remaining improvements
description: Actionable practices from the March 2026 code review glowup audit that are not yet adopted
type: project
---

Remaining improvements from the multi-agent code review audit (2026-03-25).

## Practices to adopt (no tooling needed)

- **Human triage (2 min)** between critical-code-reviewer and `/audit:walkthrough`: classify findings as blocking / important / minor / rejected before starting walkthrough
- **Pre-mortem (3-5 lines)** before submitting code for review: write down zones of doubt -- you usually know where it's fragile
- **ADR (Architecture Decision Records)**: 5-10 lines per non-obvious decision to avoid re-debating in future reviews

**Why:** the glowup audit identified these as high-value, zero-cost habits that reduce bikeshedding and improve review signal-to-noise.
**How to apply:** adopt as personal discipline during review workflow; no config or files to create.

## Backlog items (require implementation)

These are listed here for reference -- they belong in a proper issue tracker:

- Tests for `hebstr`: `str_helpers.R`, `easy_fct.R`, `easy_descr.R`, `gt_heatmap.R` (verify files still exist)
- Reviewer prompt variants by code type (R data transform vs Python API vs Quarto)
- CI/CD: GitHub Actions with lint + tests + quarto render
- Runtime data validation: pointblank (R) / pandera (Python) in pipelines
- Occasional human review: rOpenSci community, biostat peers (quarterly on critical code)
- LLM-generated tests as alternative to code review
- Quarterly architecture review: emergent patterns, tech debt
