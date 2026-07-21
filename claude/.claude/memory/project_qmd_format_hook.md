---
name: QMD formatting via panache
description: Quarto/.qmd formatting solved by panache (Rust LSP+formatter+linter), not by waiting on air .qmd support
metadata:
  type: project
---

Quarto has no native formatter, but [panache](https://panache.bz/) (Rust LSP + formatter + linter for Markdown/Quarto/Rmd, by jolars) fills the gap: it parses Pandoc/Quarto syntax (fenced divs, grid tables, citations) and delegates embedded code-block formatting to external tools (`air` for R, `ruff` for Python; linters `jarl`/`ruff`/`shellcheck`).

Global config stowed at `~/dotfiles/panache/.config/panache/config.toml` → `~/.config/panache/config.toml` (stow package `panache`). Key choice: `wrap = "semantic"` (semantic line breaks, sembr.org) to honor the user's one-sentence-per-line / no-soft-wrap rule; never `reflow`. Per-project `panache.toml` overrides by walking up to nearest `.git`.

**Why:** User works heavily with Quarto and wants consistent formatting across all file types; the old plan (wait for `air` to support `.qmd` chunks, then add a `*.qmd` case to the PostToolUse hook) is superseded.

**How to apply:** Requires `cargo install panache`. Wired into the `format-on-edit` PostToolUse hook (`hooks/format-on-edit.sh`, `*.md | *.qmd` case): runs `panache format` in place (guarded by `command -v panache`) before `prose-lint`, matching the fixer-first slot of `air`/`ruff`/`shfmt`. Scope decision (user, 2026-07-21): panache runs on **authored docs only**. The hook's first inner `case "$REAL"` skips panache for the curated instruction files (`CLAUDE.md`, `rules/*.md`) and transient Claude notes (`memory/`, `PLAN.md`, `DEFERRED.md`, `*-context.md`), so panache's whole-file semantic reflow never churns them. A second `case "$REAL"` gates `prose-lint`: the stowed global config (`~/dotfiles/claude/.claude/`) stays checked, while a project's own `.claude/` tree and `*-context.md` notes are exempt from it too. Positron format-on-save (Open VSX extension, formatter in the `[quarto]` block) is the editor-side complement. panache does NOT support Typst, but the user rarely uses Typst-raw `.qmd`, so it is not blocking; `{=typst}` raw blocks should still pass through verbatim. `prose-lint` still required (em/en dash anti-AI-slop rules are not panache's job).
