---
name: reference_panache_citation_diagnostics
description: panache resolves a Quarto `bibliography:` from the document's own folder, so a path that renders fine is still flagged in the editor; and a stale LSP keeps showing a fixed one
metadata:
  type: reference
---

panache's linter owns the `citation-keys` rule family, whose two diagnostics are `bibliography-load-error` ("Failed to load bibliography <path>: Failed to read file") and `missing-bibliography-key` ("Citation key '<key>' not found in bibliography"). They resolve the front matter's `bibliography:` and `csl:` **from the folder of the document that declares them**, and nothing else: a Quarto project's `resource-path`, written per folder in a `_metadata.yml` or declared anywhere else, is invisible to them.

So a document two levels down that declares its bibliography from the project root renders correctly and is flagged permanently in the editor. Measured 2026-10-24 on panache 3.17.0 in eds-prise, where `docs/csi/csi.qmd` declared `bibliography: docs/bib/bib.json`: pandoc resolved it through the `resource-path: ../..` of the folder's `_metadata.yml` and published fifteen notices, while panache looked for `docs/csi/docs/bib/bib.json` and reported every citation key missing. The fix is the document-relative form, `../bib/bib.json`, which both resolve. Same shape as [[reference_quarto_include_path_resolution]]: an `include` has no project-root form either.

Two things cost nothing to check before touching anything. The CLI reproduces the diagnostic, so `panache lint <file>.qmd` settles the path form without opening an editor, and both rules are on by default, no `--extend-select` needed. And the running LSP keeps publishing a diagnostic the file no longer deserves: the same binary started fresh on the corrected document returns zero diagnostics, and in Positron the flag survived the fix until a `Developer: Reload Window`. A diagnostic that outlives the edit that should clear it is a server to reload, not a declaration to change.

Never silence it with the `[lint] ignore = ["citation-keys"]` the diagnostic itself suggests: the same family is what reports a cited key with no notice, which is the drift worth catching between a document and its Zotero export. Formatter-side panache facts, its config, its hooks and its splitter defects, are in [[project_qmd_format_hook]].
