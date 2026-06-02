---
name: user_quarto_typst_only
description: User renders Quarto PDF via Typst only; does not use LaTeX
metadata:
  type: user
---

For Quarto PDF output the user uses Typst exclusively (`format: typst`).
They do not use LaTeX/TinyTeX, so do not suggest the `format: pdf` LaTeX path, `quarto check install` for TinyTeX, or LaTeX-specific troubleshooting as if relevant.

**Why:** correcting a blindspot audit of `rules/quarto.md` (2026-06-02), the user stated "i dont use latex" and rejected a finding that framed "PDF via Typst" as too narrow. For their setup, Typst-first is the correct mental model, not a narrowing.

**How to apply:** treat Typst as the sole PDF backend when reasoning about Quarto renders. See `rules/quarto.md` (auto-loaded on Quarto work) and `rules/environment.md`. Related: [[feedback_verify_quarto_theming]].
