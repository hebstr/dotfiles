---
domain: quarto
author: heiss
topic: templates
sources:
  - kind: repo
    repo: andrewheiss/hikmah-academic-quarto
    url: https://github.com/andrewheiss/hikmah-academic-quarto
    ref: v1.0
    captured: 2026-04-25
    files:
      - _extensions/hikmah/_extension.yml
      - _extensions/hikmah-manuscript/_extension.yml
      - _extensions/hikmah-response/_extension.yml
      - template.qmd
      - hikmah-response-memo.qmd
      - hikmah-testing-custom.qmd
      - README.md
---

# Quarto: Heiss `hikmah-academic-quarto` starter

Reference for Andrew Heiss's academic-paper starter template.
Source: [github.com/andrewheiss/hikmah-academic-quarto](https://github.com/andrewheiss/hikmah-academic-quarto) (captured 2026-04-25).

For Heiss's standalone extensions (`quarto-wordcount`, `fancy-epigraphs-quarto`, `quarto-output-styling`, `quarto-footnote-styles`), see [heiss-extensions](heiss-extensions.md). The starter does **not** vendor those; it expects them installed separately when needed.

## What it ships

```
quarto add andrewheiss/hikmah-academic-quarto
```

One repo, **three extension folders**, **five named formats** (PDF, manuscript-PDF, manuscript-docx, manuscript-odt, response-Typst):

```
_extensions/hikmah/                 # hikmah-pdf + hikmah-html
  _extension.yml
  include-in-header.tex
  partials/before-body.tex
  partials/title-block.html
  partials/title.tex
  styles/pretty.scss

_extensions/hikmah-manuscript/      # hikmah-manuscript-{pdf,docx,odt,html}
  _extension.yml
  include-in-header.tex
  partials/before-body.tex
  partials/title.tex
  styles/reference.docx
  styles/reference.odt
  templates/odt-manuscript.odt

_extensions/hikmah-response/        # hikmah-response-typst
  _extension.yml
  include-in-header.typ
  response.lua
  typst-template.typ
```

Note: install path is `_extensions/hikmah/`, **not** `_extensions/andrewheiss/hikmah/`: the namespace folder is skipped.

## Format-by-format

### hikmah-pdf (LaTeX)

- Type: LaTeX template via Pandoc partials (`title.tex`, `before-body.tex`, `include-in-header.tex`).
- `quarto-required: ">=1.4.11"`, `version: 0.0.9`.
- Defaults: `geometry: top=10pc bottom=10pc left=11pc right=11pc heightrounded`, `block-headings: false`, `indent: true`, `colorlinks: true`, `*color: DarkSlateBlue`.
- Bibliography by default: `cite-method: citeproc`, `biblio-style: apa`, with `biblatex-chicago: false` flag exposed.
- Sibling `hikmah-html` format reuses `partials/title-block.html` + `styles/pretty.scss`.

### hikmah-manuscript-pdf (LaTeX)

- Type: LaTeX manuscript style, letter paper, 12pt, double-spaced, 1in margins.
- `quarto-required: ">=1.4.11"`, `version: 0.0.15`.
- `documentclass: article`, `papersize: letter`, `fontsize: 12pt`, `linestretch: 2`, `geometry: 1in`.
- Custom YAML knobs: `left-aligned: true` (kills justification), `endnotes: true` (requires a `\theendnotes` block in the body, see the snippet below).

### hikmah-manuscript-docx (Pandoc docx)

- Type: docx with `reference-doc: _extensions/hikmah-manuscript/styles/reference.docx`.
- knitr defaults: `dev: ragg_png, dpi: 300, out.width: 80%`.

### hikmah-manuscript-odt (Pandoc odt)

- Type: ODT with **both** a `template:` (`templates/odt-manuscript.odt`) and a `reference-doc:` (`styles/reference.odt`), which is uncommon; the template provides the structure, the reference-doc provides the styles.
- README recommends opening with LibreOffice.

### hikmah-response-typst (Typst)

- Type: Typst template (`typst-template.typ`) + Lua filter (`response.lua`) + header (`include-in-header.typ`).
- `quarto-required: ">=1.7.23"`, `version: 0.1.0`.
- Custom Typst params: `color-reviewer: "dd5129"`, `color-excerpt: "0f7ba2"` (hex without `#`).
- Lua filter expands custom Divs: `.memo-reviewer`, `.memo-excerpt`, `.memo-reviewer-inline`, `.memo-excerpt-inline`, used to typeset reviewer comments and excerpted manuscript passages in a response memo.

## Minimal usage

From `template.qmd`:

```yaml
format:
  hikmah-pdf: default
  hikmah-manuscript-pdf: default
```

From `hikmah-response-memo.qmd`:

```yaml
---
title: Responses to editor and reviewer concerns
format:
  hikmah-response-typst: default
---
```

## Fancy title block: multi-author + ORCID + affiliations

The title block builds on Quarto's standard `author/affiliations` schema (<https://quarto.org/docs/journals/authors.html>), with a few extra fields the template handles natively. Verbatim from `template.qmd`:

```yaml
title: |
  On the Surgical Removal of \
  Cardassian Cranial Implants
subtitle: A case study of a Cardassian patient
short-title: Cranial Implants
published: "Under review at *Starfleet Medical Journal*"
code-repo: "Access the code, data, and analysis at <https://...>"
correspondence-prefix: "Correspondence concerning this article should be addressed to"
author:
  - name: Julian Bashir
    email: jbashir@starfleet.ufp
    orcid: 0000-0002-3948-3914
    title: Chief Medical Officer
    affiliations:
      - id: ds9
        name: Starbase Deep Space Nine
        department: Sick Bay
        address: 1234 Main Street
        city: Anytown
        region: NY
        country: USA
        postal-code: 90210
    attributes:
      corresponding: true
  - name: Elim Garak
    email: tailor.spy@obsidianorder.card.gov
    title: Shopkeeper and Tailor
    affiliations:
      - id: terok
        name: Terok Nor
        department: Promenade
      - ref: ds9
abstract: |
  Space: the final frontier...
thanks: |
  Placeholder text...
additional-info: |
  We have no known conflict of interest to disclose.
keywords:
  - surgery
  - espionage
  - brains
date: August 24, 2022
bibliography: references.bib
```

Custom fields beyond Quarto core: `short-title`, `published`, `code-repo`, `correspondence-prefix`, `additional-info`, `attributes.corresponding`. Affiliation reuse via `- ref: <id>` is standard but worth noting.

LaTeX-side, multi-author left-aligned layout is achieved by redefining `\and` in `include-in-header.tex` (long inline comment in source explains the choice).

## biblatex-chicago integration

- **Not vendored.** The template assumes `biblatex-chicago` is already installed in the local TeX distribution.
- Activated by a custom flag: `biblatex-chicago: true` (default `false` in both PDF `_extension.yml`).
- Switching it on means switching Quarto's `cite-method: biblatex` (citeproc is the default).

Full custom-fonts + Chicago example from `hikmah-testing-custom.qmd`:

```yaml
format:
  hikmah-pdf:
    mainfont: "Linux Libertine O"
    mainfontoptions:
      - "Numbers=Proportional"
      - "Numbers=OldStyle"
    sansfont: "Jost"
    monofont: "InconsolataGo"
    monofontoptions:
      - "Mapping=tex-ansi"
      - "Scale=MatchLowercase"
    mathfont: "Libertinus Math"
    biblatex-chicago: true
    biblio-style: authordate
    biblatexoptions:
      - backend=biber
      - autolang=hyphen
      - isbn=false
      - uniquename=false
  hikmah-manuscript-pdf:
    left-aligned: true
    endnotes: true
    mainfont: "Linux Libertine O"
    mainfontoptions:
      - "Numbers=Proportional"
      - "Numbers=OldStyle"
    mathfont: "Libertinus Math"
    biblatex-chicago: true
    biblio-style: authordate
    biblatexoptions:
      - backend=biber
      - autolang=hyphen
      - isbn=false
      - uniquename=false
```

Endnotes block required in the body for `endnotes: true` (manuscript-pdf):

````markdown
::: {.content-visible when-meta="endnotes"}
```{=latex}
\newpage
\begingroup
\singlespacing
\parindent 0pt
\parskip 2ex
\def\enotesize{\normalsize}
\theendnotes
\endgroup
\newpage
```
:::
````

## quarto-required floor

| Extension | Minimum |
|---|---|
| `hikmah` | `>=1.4.11` |
| `hikmah-manuscript` | `>=1.4.11` |
| `hikmah-response` | `>=1.7.23` |

Global floor for the full set: **`>=1.7.23`**. The custom fonts stack (Libertine, Jost, InconsolataGo, Libertinus Math) requires **XeLaTeX or LuaLaTeX**.

## Patterns to copy

- **One extension dir, multiple formats.** `hikmah-manuscript` ships `pdf` + `docx` + `odt` + `html` from a single `_extension.yml`. Reuse pattern when a paper needs synced manuscript exports.
- **Template + reference-doc combo for ODT.** Heiss declares both: the template owns layout, the reference-doc owns styles. Useful when a reviewer needs an editable ODT that still respects journal styling.
- **Custom YAML flags exposed by the format**, not hardcoded in the template body: `left-aligned`, `endnotes`, `biblatex-chicago`, `correspondence-prefix`. Lets a user customize from the document YAML without forking the extension.
- **Affiliation reuse via `- ref: <id>`** (standard Quarto, but Heiss's template demonstrates the multi-author + shared-affiliation pattern cleanly).
- **Typst response-memo divs** (`memo-reviewer`, `memo-excerpt`): semantic markup expanded by a Lua filter into Typst boxes. Cleaner pattern than raw `#box` calls in the body.

## Pitfalls / non-features

- The starter does **not** ship epigraph styling; the README points to standalone `andrewheiss/fancy-epigraphs-quarto`.
- No `mainfont` is imposed by default, so Pandoc/Latin Modern ships unless overridden.
- `biblatex-chicago` requires `cite-method: biblatex` and a working biber install; flipping just `biblatex-chicago: true` without `cite-method` won't apply Chicago styling.

## Sources

- [andrewheiss/hikmah-academic-quarto](https://github.com/andrewheiss/hikmah-academic-quarto): repo plus [README.md](https://github.com/andrewheiss/hikmah-academic-quarto/blob/main/README.md) for design-decision context (Healy lineage, Quarto-ification, biblatex-chicago rationale).
