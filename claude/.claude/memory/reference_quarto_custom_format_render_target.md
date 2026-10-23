---
name: Quarto custom format resolves to its base at render time
description: A custom Quarto format (e.g. `hebstr-doc-docx`) resolves to its base format before knitr starts, so `knitr::pandoc_to()`/`is_html_output()` discriminate from the setup chunk and a Lua filter's `FORMAT`/`quarto.doc.is_format()` sees the base name; and `--to <custom-format>` renders a document that does not declare it
metadata:
  type: reference
---

Measured 2026-09-09 on Quarto 1.10.18 with the `hebstr-doc` extension, on the real custom formats rather than on generic `format: html` / `format: docx` (the distinction is the actual risk).

Three behaviours, all load-bearing for a single-source multi-format document:

- **A Lua filter sees the base format too**, measured 2026-10-23 on Quarto 1.10.19: under `format: hebstr-doc-docx`, `FORMAT` is `docx` and `quarto.doc.is_format('docx')` is true, as `is_format('html')` is under `hebstr-doc-html`. Quarto's `pandoc/datadir/_format.lua` reduces `is_format('docx')` to `FORMAT == "docx"` with no pattern tolerance, so a third-party filter branching on the base format works unchanged on a derived one (worked case: the `collab-comments` docx branch, [[project_collab_comments_evaluation]]).
- **The custom format resolves to its base before knitr starts.** `quarto render doc.qmd --to hebstr-doc-html` gives `knitr::pandoc_to() == "html"` and `is_html_output() == TRUE`; `--to hebstr-doc-docx` gives `"docx"` and `FALSE`. Available from the `setup` chunk onward, so one document can branch on the render target in R rather than duplicating itself or doubling every output into `::: {.content-visible when-format=}` blocks (which also makes two blocks fight over the same crossref anchor).
- **`--to <custom-format>` works on a document that does not declare it.** The YAML can keep the routine format alone (`hebstr-doc-html`), and the second one is a command-line argument. A plain `quarto render doc.qmd` then still produces only the routine output instead of every declared format.

Consequence: a report needing both an HTML and a Word deliverable is one `.qmd`, with a helper returning the live object under HTML and `knitr::include_graphics()` of the artefact otherwise. Worked example and the design behind it: `eds-prise`, `lib/out-helpers.R` and `.claude/DESIGN-DOCX.md`.

The `content-visible when-format` bug that applied the condition to the last listed format only was fixed in Quarto 1.6, so it is not what rules that route out.

See also [[reference_quarto_extension_format_knitr]] for scoping `knitr: opts_chunk:` to one format inside `_extension.yml`, and [[project_quarto_extensions_need_project_root]] for where `_extensions` resolves.
