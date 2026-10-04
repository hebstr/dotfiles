---
name: Quarto _extensions resolution stops at the input directory without a project
description: Without a _quarto.yml, Quarto looks for _extensions only in the input file's own directory, so a .qmd using a custom format must sit beside _extensions or the repo must gain a project file
metadata:
  type: project
---

Quarto searches `_extensions/` in the input file's directory, then walks up **to the project root**. With no `_quarto.yml` anywhere there is no project, so there is no walk-up: the search stops at the input file's own directory and a `.qmd` in a subdirectory fails with `ERROR: Unable to read the extension '<name>'`.

Measured 2026-09-02 on a throwaway tree with a fake extension, three cases:

```
| Setup                                                   | Result           |
|---------------------------------------------------------|------------------|
| no `_quarto.yml`, document in a subdirectory             | ERROR, extension |
| `_quarto.yml` at the root, everything else identical     | Output created   |
| no `_quarto.yml`, `_extensions` beside the document      | Output created   |
```

Consequence for a repo with no `_quarto.yml`: every `.qmd` using a custom format must stay at the root. Moving one into a subdirectory needs either a `_quarto.yml` at the root or a second `_extensions` beside it.

The render-gate objection to the first route is measured wrong, 2026-10-04 in eds-prise, which gained a `_quarto.yml` that day: `quarto render` alone renders what `render:` names and nothing else, and a document left out of that list keeps its own command, comes out beside itself and takes no `output-dir`. A dot-directory stays outside the project either way, so a `.qmd` under `.claude/` still fails to resolve the extension, measured there the same day.

The error names the extension, not the path, so it reads as a missing install rather than a resolution failure. Check the input file's directory before reinstalling anything.

Related: [[project_quarto_custom_crossref_float]], [[project_qmd_format_hook]].
