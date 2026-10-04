---
name: A .qmd outside the project render list gets no project metadata
description: In a Quarto project with a `render:` list, rendering a `.qmd` not in that list skips `_quarto.yml` metadata (e.g. `lang`) and `output-dir`, while pre-render still runs and its `_metadata.yml` still applies, which silently renames that outside file; a single-file render of a listed document does get `output-dir` and both render scripts, and `output-file` refuses a path outright
metadata:
  type: reference
---

Measured 2026-09-18 on Quarto 1.10 in `md-nesrine` (`_quarto.yml` with `render: [index.qmd]`, `lang: fr`, `output-dir: docs`, a `pre-render` script writing `_metadata.yml`), by rendering a second file, `index_manuscrit.qmd`, that is not in the list.

- **Project metadata does not reach it.** `quarto inspect index_manuscrit.qmd` resolves `lang` to `en` (the theme's `common: lang: en`) where `index.qmd` resolves `fr`; the docx TOC came out titled "Table of contents". Declare such keys in the file's own front matter.
- **`output-dir` does not apply.** The output stays at the project root instead of moving to `docs/`, so it cannot overwrite the listed document's output there.
- **Pre-render still runs, and the directory `_metadata.yml` still applies**: the file took the `output-file` name the pre-render script wrote for the listed report.

Re-measured 2026-10-03 on Quarto 1.10.18, in a throwaway project, which sharpens the last bullet and adds two facts the first pass did not reach.

- **The `_metadata.yml` route silently renames the outside file**, which is the trap rather than a curiosity: with `output-file: 2026-10-03_prise_csi` at the project root, a second document outside `render:` came out as `2026-10-03_prise_csi.html` beside itself, exit 0, no warning. So md-nesrine's dating mechanism, a `pre-render` writing `_metadata.yml`, cannot be copied into a repository holding several root documents. Declare `output-file` in the listed document's own front matter instead, guarded against its `date:` field.
- **`output-file` refuses a path**: `Invalid value for output-file: paths are not allowed`. A subfolder for the deliverable comes from `output-dir` or from a post-render move, never from the front matter.
- **A single-file render inside a project still gets `output-dir`, `pre-render` and `post-render`.** `quarto render main.qmd` on a listed document wrote to `docs/csi/` and ran both scripts, `QUARTO_PROJECT_OUTPUT_DIR` set. So adopting a project does not cost the per-file render habit. Name the scripts `./pre.sh`, not `pre.sh`, which fails with `Failed to spawn: entity not found`.

See also [[project_quarto_extensions_need_project_root]] and [[reference_quarto_doc_crossref_overrides_format]].
