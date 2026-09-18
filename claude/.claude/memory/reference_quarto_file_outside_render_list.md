---
name: A .qmd outside the project render list gets no project metadata
description: In a Quarto project with a `render:` list, rendering a `.qmd` not in that list skips `_quarto.yml` metadata (e.g. `lang`) and `output-dir`, while pre-render still runs and its `_metadata.yml` still applies
metadata:
  type: reference
---

Measured 2026-09-18 on Quarto 1.10 in `md-nesrine` (`_quarto.yml` with `render: [index.qmd]`, `lang: fr`, `output-dir: docs`, a `pre-render` script writing `_metadata.yml`), by rendering a second file, `index_manuscrit.qmd`, that is not in the list.

- **Project metadata does not reach it.** `quarto inspect index_manuscrit.qmd` resolves `lang` to `en` (the theme's `common: lang: en`) where `index.qmd` resolves `fr`; the docx TOC came out titled "Table of contents". Declare such keys in the file's own front matter.
- **`output-dir` does not apply.** The output stays at the project root instead of moving to `docs/`, so it cannot overwrite the listed document's output there.
- **Pre-render still runs, and the directory `_metadata.yml` still applies**: the file took the `output-file` name the pre-render script wrote for the listed report.

See also [[project_quarto_extensions_need_project_root]] and [[reference_quarto_doc_crossref_overrides_format]].
