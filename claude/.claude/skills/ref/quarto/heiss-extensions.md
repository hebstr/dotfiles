---
domain: quarto
author: heiss
topic: extensions
sources:
  - kind: repo
    repo: andrewheiss/quarto-wordcount
    url: https://github.com/andrewheiss/quarto-wordcount
    ref: "v1.8.0"
    captured: 2026-04-25
    files:
      - _extensions/wordcount/_extension.yml
      - _extensions/wordcount/words.lua
      - _extensions/wordcount/wordcount.lua
      - _extensions/wordcount/citeproc.lua
  - kind: repo
    repo: andrewheiss/quarto-output-styling
    url: https://github.com/andrewheiss/quarto-output-styling
    ref: "59a4945"
    captured: 2026-04-25
    files:
      - _extensions/output-styling/_extension.yml
      - _extensions/output-styling/output-styling.lua
  - kind: repo
    repo: andrewheiss/fancy-epigraphs-quarto
    url: https://github.com/andrewheiss/fancy-epigraphs-quarto
    ref: "b21f5d6"
    captured: 2026-04-25
    files:
      - _extensions/epigraph/_extension.yml
      - _extensions/epigraph/epigraph.lua
  - kind: repo
    repo: andrewheiss/quarto-footnote-styles
    url: https://github.com/andrewheiss/quarto-footnote-styles
    ref: "v0.2.0"
    captured: 2026-04-25
    files:
      - _extensions/footnote-styles/_extension.yml
      - _extensions/footnote-styles/footnote-styles.lua
---

# Quarto: Heiss multi-format extensions

Reference for Andrew Heiss's Quarto extensions targeting HTML, PDF (LaTeX), Typst, and docx.
Source: [github.com/andrewheiss](https://github.com/andrewheiss) (captured 2026-04-25).

For Heiss's full academic manuscript starter (which composes several of these), see [heiss-templates](heiss-templates.md).
For his Bayesian / `marginaleffects` patterns, see [heiss-bayes](../biostat/heiss-bayes.md).

## quarto-wordcount

- Repo: <https://github.com/andrewheiss/quarto-wordcount>
- Type: **Lua filter + shortcodes**, shipped both as plain filter and as **custom format wrappers** (`wordcount-html`, `wordcount-pdf`, `wordcount-docx`, `wordcount-markdown`)
- Targets: **HTML, PDF, docx, markdown**. It runs on the rendered AST (post-knitr/jupyter, post-citeproc), so it counts what readers actually see, not citekeys.
- What: counts words in body / references / notes separately, fixing the long-standing problem where `wc` counted `@citekey2024` instead of "Smith (2024)". Provides shortcodes `{{< words-body >}}`, `{{< words-ref >}}`, `{{< words-note >}}`, `{{< words-sum body-note-ref >}}` and an optional banner.
- `_extension.yml` (essential):
  ```yaml
  version: 1.8.0
  quarto-required: ">=1.4.551"
  contributes:
    shortcodes:
      - "words.lua"
    format:
      common:
        filters:
          - at: pre-quarto
            path: citeproc.lua
          - at: pre-quarto
            path: wordcount.lua
        citeproc: false
      html: default
      pdf: default
      docx: default
      markdown: default
  ```
- Verbatim usage (wrapper-format pattern):
  ```yaml
  format:
    wordcount-html:
      toc: true
  params:
    wordcount: |
      <strong>{{< words-sum body-note-ref >}} total words</strong>: {{< words-body >}} in the body • {{< words-ref >}} in the references • {{< words-note >}} in the notes
  ```
  ```markdown
  ::: {.content-visible when-meta="wordcount-banner"}
  {{< include _extensions/andrewheiss/wordcount/banner.html >}}
  :::
  ```
- Status: active (last commit 2026-01-07, "Count the abstract").
- Note: the order `citeproc.lua` → `wordcount.lua` at `pre-quarto` is the trick. Heiss runs citeproc himself before disabling Quarto's, then counts the resolved citation strings.

## quarto-output-styling

- Repo: <https://github.com/andrewheiss/quarto-output-styling>
- Type: **Lua filter + CSS resources**, HTML-only (early `is_format("html")` guard at line 48 of `output-styling.lua`)
- Targets: **HTML only**.
- What: styles R/Python cell outputs (regular output, errors, warnings, messages) using Bootstrap-aligned colored fills or thin borders. Three appearances: `default`, `minimal`, `custom`.
- `_extension.yml`:
  ```yaml
  quarto-required: ">=1.5.0"
  contributes:
    filters:
      - output-styling.lua
    resources:
      - output-styling-default.css
      - output-styling-minimal.css
  ```
- Verbatim usage:
  ```yaml
  ---
  title: Your title
  filters:
    - output-styling
  output-styling:
    appearance: minimal   # default | minimal | custom
  ---
  ```
- Status: active (last commit 2025-08-25).

## fancy-epigraphs-quarto

- Repo: <https://github.com/andrewheiss/fancy-epigraphs-quarto>
- Type: **Shortcode (Lua) + CSS (HTML) + LaTeX header (PDF)**, also ships custom format wrappers (`epigraph-html`, `epigraph-pdf`)
- Targets: **HTML, LaTeX PDF, Typst PDF** with dedicated styling; other formats fall back to plain blockquote.
- What: typesets epigraphs as a left-aligned block inside a right-aligned box (the conventional academic look). Markdown is parsed inside the quote and inside the source.
- `_extension.yml`:
  ```yaml
  quarto-required: ">=1.7.0"
  contributes:
    shortcodes:
      - epigraph.lua
    formats:
      html:
        css: epigraph.css
      pdf:
        include-in-header:
          - file: epigraph.tex
  ```
- Verbatim usage:
  ```qmd
  {{< epigraph "Do or **do not**. There *is* no try." source="~~Grogu~~Yoda" >}}
  ```
  ```yaml
  format:
    epigraph-html: default   # or epigraph-pdf: default
  ```
- Status: active (last commit 2025-04-25).

## quarto-footnote-styles

- Repo: <https://github.com/andrewheiss/quarto-footnote-styles>
- Type: **Lua filter** (no shortcodes, no resources)
- Targets: **HTML, LaTeX PDF, Typst**, with explicit branching:
  ```lua
  if quarto.doc.is_format("html") then
  elseif quarto.doc.is_format("pdf") then
  elseif quarto.doc.is_format("typst") then
  ```
  docx is **not** supported.
- What: replaces default numeric footnote markers with alternative sequences (symbols `* † ‡ §`, lower/upper alpha, roman, or fully custom), with `start-at`, `marker-prefix`, `marker-suffix` knobs.
- `_extension.yml`:
  ```yaml
  version: "0.2.0"
  quarto-required: ">=1.7.0"
  contributes:
    filters:
      - footnote-styles.lua
  ```
- Verbatim usage:
  ```yaml
  ---
  title: Your title
  filters:
    - footnote-styles
  extensions:
    footnote-styles:
      style: "symbols"          # numeric-03, roman-lower, alpha-upper, symbols, …
      start-at: 4
      custom: ["†", "‡", "§", "‖"]
  ---
  ```
- Status: active (last commit 2026-03-02, the most recent of the four).

## Cross-cutting patterns

- **Sub-folder name ≠ repo name.** All four install under `_extensions/andrewheiss/<short-name>/` where `<short-name>` is `wordcount`, `output-styling`, `epigraph`, `footnote-styles`. This matters when `{{< include >}}`-ing assets shipped by the extension (see the wordcount banner).
- **Two activation patterns coexist** in Heiss's catalog:
  1. **Filter-as-YAML-key**: `filters: [output-styling]` or `filters: [footnote-styles]`. Plain.
  2. **Custom format wrapper**: `format: wordcount-html` or `format: epigraph-html`. The wrapper = base format + auto-included CSS/LaTeX/JS, no manual `filters:` line. Wordcount and Epigraph ship both styles.
- **`quarto-required` floor has crept up**: 1.4.551 (wordcount) → 1.5.0 (output-styling) → 1.7.0 (epigraph, footnote-styles). Worth checking before installing on older Quarto.
- **Multi-format branching is done in two places**: in shortcodes (epigraph picks HTML/PDF/Typst at the shortcode return point) or in filter top-guards (`output-styling` early-returns on non-HTML; `footnote-styles` dispatches via `is_format` chains). The wordcount filter makes no runtime `is_format` call, since it intentionally runs everywhere.

## Sources

- [andrewheiss/quarto-wordcount](https://github.com/andrewheiss/quarto-wordcount)
- [andrewheiss/quarto-output-styling](https://github.com/andrewheiss/quarto-output-styling)
- [andrewheiss/fancy-epigraphs-quarto](https://github.com/andrewheiss/fancy-epigraphs-quarto)
- [andrewheiss/quarto-footnote-styles](https://github.com/andrewheiss/quarto-footnote-styles)
