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

Consequence for a repo with no `_quarto.yml` (eds-prise is one): every `.qmd` using a custom format must stay at the root. Moving one into a subdirectory needs either a `_quarto.yml` at the root, which changes the render gate for the whole repo (`quarto render` alone then renders every document), or a second `_extensions` beside it.

The error names the extension, not the path, so it reads as a missing install rather than a resolution failure. Check the input file's directory before reinstalling anything.

Related: [[project_quarto_custom_crossref_float]], [[project_qmd_format_hook]].
