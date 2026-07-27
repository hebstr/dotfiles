---
name: Quarto render on a disabled book chapter can rewrite _quarto.yml
description: Running `quarto render <file>.qmd` on a chapter commented out of a Quarto book's `chapters:` list can make Quarto uncomment/insert it into `_quarto.yml`; check `git status` on the project config after the render gate
metadata:
  type: feedback
---

In a Quarto **book** project, running the render gate on a single `.qmd` that is commented out of `book.chapters:` can silently rewrite `_quarto.yml`: Quarto replaces the commented line with a live list entry so the file it was asked to render belongs to the project.

Observed 2026-07-27 in `eds-avc` (`docs/chapters/05-methode_annot.qmd`, one of five chapters commented out). Signature of the mutation:

- the render output path moves from beside the source (`docs/chapters/x.html`, standalone render) to the book output dir (`_book/docs/chapters/x.html`)
- `git status` shows `_quarto.yml` modified, with the chapter's `#     - path` comment turned into `        - path`

**Why it matters:** the render exits 0, so the gate reports a pass while having committed-adjacent damage to project config the user deliberately curated. Disabled chapters are a normal authoring state in a thesis-style book, so this recurs.

**How to apply:** after `quarto render <file>.qmd` in a book project, run `git status --porcelain` and check `_quarto.yml` (and `_metadata.yml`) before reporting the gate as passed. If mutated, restore the commented line with an Edit rather than a `git restore` (git writes belong to the user, see the Git rule in CLAUDE.md). Rendering a chapter that is *already* in `chapters:` does not trigger this.

Timing is not fully pinned down: the first render of that same file rendered standalone and left `_quarto.yml` untouched; a later identical invocation performed the rewrite, so `.quarto/` project state appears to be involved. Treat the check as unconditional rather than trying to predict which invocation mutates.

Related: [[project_md_nesrine_render_pitfalls]] for other Quarto render traps, [[project_qmd_format_hook]] for the panache formatting side of `.qmd` edits.
