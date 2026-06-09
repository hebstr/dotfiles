---
name: QMD formatting via panache
description: Quarto/.qmd formatting solved by panache (Rust LSP+formatter+linter), not by waiting on air .qmd support
metadata:
  type: project
---

Quarto has no native formatter, but [panache](https://panache.bz/) (Rust LSP + formatter + linter for Markdown/Quarto/Rmd, by jolars) fills the gap: it parses Pandoc/Quarto syntax (fenced divs, grid tables, citations) and delegates embedded code-block formatting to external tools (`air` for R, `ruff` for Python; linters `jarl`/`ruff`/`shellcheck`).

Global config stowed at `~/dotfiles/panache/.config/panache/config.toml` → `~/.config/panache/config.toml` (stow package `panache`). Key choice: `wrap = "semantic"` (semantic line breaks, sembr.org) to honor the user's one-sentence-per-line / no-soft-wrap rule; never `reflow`. Per-project `panache.toml` overrides by walking up to nearest `.git`.

**Why:** User works heavily with Quarto and wants consistent formatting across all file types; the old plan (wait for `air` to support `.qmd` chunks, then add a `*.qmd` case to the PostToolUse hook) is superseded.

**How to apply:** Requires `cargo install panache` + the Positron Open VSX extension for format-on-save (add a formatter to the `[quarto]` block). panache does NOT support Typst, so a Typst-raw `.qmd` (e.g. the cv) gains little; verify it preserves `{=typst}` raw blocks verbatim before trusting format-on-save there. `prose-lint` still required (em/en dash anti-AI-slop rules are not panache's job).
