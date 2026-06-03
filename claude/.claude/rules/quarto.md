---
paths:
  - "**/*.qmd"
  - "**/_quarto.yml"
  - "**/_quarto.yaml"
  - "**/_metadata.yml"
  - "**/_metadata.yaml"
  - "**/_brand.yml"
  - "**/_extension.yml"
  - "**/_quarto-*.yml"
---

# Quarto toolchain

## CLI tools

| Tool | Role |
|---|---|
| `quarto render` | Render a document or project to its output (HTML, or PDF via Typst) |
| `quarto check` | Verify the installation. Targets: `install`, `knitr`, `jupyter`, `julia`, `versions`, `all` (no `typst` target; the bundled Typst version shows under `versions`) |

Quarto has no formatter or linter equivalent to `air`/`ruff`. The gate is a clean render plus the language gate on chunk code; for a user-facing `.qmd`, it also includes `prose-lint` for the always-on dash and soft-wrap rules (mechanical enforcement, not optional polish: see Prose conventions below).

## Mandatory pipeline after every create/edit

```sh
quarto render <file>.qmd
```

Substitute `<file>.qmd` with the file being edited. When the edit is to `_quarto.yml`/`_quarto.yaml` or any project-level config (book, website, multi-file report), the gate is instead a full-project render from the project root:

```sh
quarto render
```

A single-file render does not exercise project config (sidebar, book chapters, cross-references), so it gives a false pass on the exact edit that triggered the rule.

Check the exit code: non-zero means a broken document (invalid YAML front matter, a failing code chunk, a missing dependency, or an unresolved cross-reference or citation such as an undefined `@ref` or a missing bib entry). A clean render is the pass condition; there is no separate lint step for the prose.

`quarto check` diagnoses the environment (missing R/Python/Jupyter/Typst, version mismatch), not document content. Run it only when a render fails for a toolchain reason or on a `command not found`-class error, never after every edit. Scope it with `quarto check knitr` (R engine) or `quarto check jupyter` (Python engine).

For a fast pass while iterating, `quarto render <file>.qmd --no-execute` skips code execution (it still validates YAML front matter, so it is not a pure prose-only check). A task is not done until a render *without* `--no-execute` exits 0; never report a Quarto task complete on the strength of a `--no-execute` render.

## Code chunks

R and Python chunks inside a `.qmd` follow their own language rules: see `rules/r.md` and `rules/python.md` (idioms, and the `air`/`ruff` format+lint gate). Quarto tooling cannot lint chunk contents in place. For a substantive chunk (same threshold as the file-edit gate in `CLAUDE.md`), copy the chunk body to a scratch `.R`/`.py` file, run the language gate from `rules/r.md`/`rules/python.md`, then paste the formatted result back. After paste-back, re-render *without* `--no-execute` to confirm the chunk still executes: the scratch-file round trip can shift the chunk's indentation or disturb the fence boundaries, and a `--no-execute` pass validates YAML but not chunk execution, so it would give a false pass on exactly that breakage. Skip for trivial chunks (a single plot or `mutate` call). Do not duplicate those conventions here.

The engine is set per project or per document (`engine: knitr` for R, `engine: jupyter` for Python); read it from the document YAML front matter or the project `_quarto.yml` `engine:` key. Match `quarto check <engine>` to whichever the document uses.

## Prose conventions

- One sentence or logical unit per line; no manual soft wraps (matches the global Markdown rule). Quarto renders a single source newline as a soft break, so source line breaks do not change the output.
- On a user-facing `.qmd`, `prose-lint <file>` is the mandatory mechanical check (dashes, soft wraps); `/workflow:write` is optional deeper polish and anti-AI-slop review. Both apply to authored documents, not to this rules file.

## Feature syntax: defer to skills

Do not reconstruct Quarto feature syntax from memory (callouts, cross-references, citations, extensions, websites/books, theming, `_brand.yml`). Use the skills instead:

- `quarto:quarto-authoring` for authoring features, project types, and migration from R Markdown/bookdown/Jupyter
- `quarto:brand-yml` for `_brand.yml` branding
- `/ref quarto` for curated theming, extension, and academic-template snippets

## Useful flags

**quarto render**

| Flag | Effect |
|---|---|
| `--to FORMAT` | Render a single format (`html`, `pdf`, `docx`, ...) |
| `--no-execute` | Skip code execution (prose-only, faster while iterating) |
| `-P KEY:VALUE` | Pass an execution parameter |
| `-M KEY:VALUE` | Override a metadata value |
| `--cache` | Enable execution caching (`--no-cache` disables it; `--cache-refresh` forces a refresh of an existing cache) |
| `--output -` | Write rendered output to stdout |
| `--output-dir DIR` | Write output to a directory (input/project-relative) |

**quarto check**

| Flag | Effect |
|---|---|
| `--no-strict` | Do not fail on imprecise dependency-version matches |
| `--output PATH` | Write the report as JSON to a file (note: unlike `render`, `check` has no stdout `-` form) |

## References

- Quarto guide: https://quarto.org/docs/guide/
- Project config (`_quarto.yml`): https://quarto.org/docs/projects/quarto-projects.html
- Typst PDF backend: https://quarto.org/docs/output-formats/typst.html
