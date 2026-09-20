---
domain: quarto
author: heiss
topic: snippets
sources:
  - kind: blog
    url: https://www.andrewheiss.com/blog/2023/12/11/separate-bibliographies-quarto/
    published: 2023-12-11
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2024/11/04/render-generated-r-chunks-quarto/
    published: 2024-11-04
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2021/08/27/tikz-knitr-html-svg-fun/
    published: 2021-08-27
    captured: 2026-04-25
---

# Quarto: Heiss advanced snippets

Three Quarto patterns from Andrew Heiss's blog that don't fit in the extension/template fiches: separate bibliographies via `multibib`, programmatic chunk generation, and TikZ → SVG with fonts.
Source: <https://www.andrewheiss.com/blog/> (captured 2026-04-25).

For Heiss's standalone extensions, see [heiss-extensions](heiss-extensions.md). For the academic starter, see [heiss-templates](heiss-templates.md).

## Separate bibliographies per section (multibib)

Source: [How to create separate bibliographies in a Quarto document](https://www.andrewheiss.com/blog/2023/12/11/separate-bibliographies-quarto/) (2023-12-11).

**Use case.** Academic paper with appendix. Citations in the appendix shouldn't inflate the manuscript word count, and the two reference lists must render in their own positions in the document.

**Mechanism.** The pandoc `multibib` extension (shipped as `pandoc-ext/multibib`) lets you declare several bibliographies and place each one inside a fenced div with the corresponding ID. Heiss combines it with his own `wordcount` filter so only the *main* references list contributes to the count.

YAML in `_quarto.yml` or document front matter:

```yaml
bibliography:
  main: references.json
  appendix: appendix.json

citeproc: false

crossref:
  custom:
    - kind: float
      key: apptbl
      latex-env: apptbl
      reference-prefix: Table A
      space-before-numbering: false
      latex-list-of-description: Appendix Table

filters:
  - at: pre-render
    path: "_extensions/pandoc-ext/multibib/multibib.lua"
  - at: pre-render
    path: "_extensions/andrewheiss/wordcount/wordcount.lua"
```

Place each list with a fenced div whose ID matches a bibliography key:

```markdown
Here's the main references list:

::: {#refs-main}
:::

Here's the appendix references list:

::: {#refs-appendix}
:::
```

Tweak in `wordcount.lua` so only the main bib counts:

```lua
function is_ref_div (blk)
   return (blk.t == "Div" and blk.identifier == "refs-main")
end
```

Install:

```bash
quarto add pandoc-ext/multibib
quarto add andrewheiss/quarto-wordcount
```

**Caveats.**

- `citeproc: false` is **required**: multibib takes over the citation processing.
- Quarto 1.4+ at the time of writing; YAML schema warnings appear but renders succeed.
- The terminal emits spurious "citation not found" warnings, which are noise.
- For PDF submission, journals may still require manual reference separation.

## Generate and render R chunks programmatically

Source: [Guide to generating and rendering computational markdown content programmatically with Quarto](https://www.andrewheiss.com/blog/2024/11/04/render-generated-r-chunks-quarto/) (2024-11-04).

**Use case.** Building 100+ near-identical sections (one per group, one per race, one per file) without copy-pasting markdown.

**Why `results: asis` alone fails.** It emits markdown text, but inline `` `r expr` `` and other R chunks inside the emitted text are never re-evaluated by knitr: they hit the page as literal source. You need to pre-render the generated string yourself.

**Core trick.** Wrap the generated markdown in `knitr::knit(text = ...)` from an *inline* expression. By the time Quarto sees the document, the markdown has already been evaluated.

```markdown
`r knitr::knit(text = paste0(pi_stuff$list_element, collapse = "\n"))`
```

**Pattern: panel-tabset builder.** Use `glue::glue()` with `<<...>>` delimiters so braces inside the chunk don't conflict with `glue`'s default `{...}`:

```r
build_panel <- function(panel_title, plot_index) {
  chunk_label <- glue("panel-continent-{title}",
                      title = janitor::make_clean_names(panel_title))

  output <- glue("
  ### <<panel_title>>

  ```{r}
  #| label: <<chunk_label>>
  #| echo: false
  continents_plots$plot[[<<plot_index>>]]
  ```", .open = "<<", .close = ">>")

  output
}
```

Build the markdown column row-by-row:

```r
continents_plots_with_text <- continents_plots |>
  mutate(row = row_number()) |>
  mutate(markdown = pmap_chr(
    lst(continent, row),
    \(continent, row) build_panel(panel_title = continent,
                                   plot_index = row)
  ))
```

Render in the document:

```markdown
::: {.panel-tabset}

`r knitr::knit(text = paste0(continents_plots_with_text$markdown, collapse = "\n\n"))`

:::
```

**Caveat.** Heiss notes that he has not found the approach formally documented anywhere, and that he came across it in a gist from 2015. Alternative for cleaner separation: `knitr::knit_child()` against external template files.

## TikZ → SVG with embedded fonts

Source: [How to automatically convert TikZ images to SVG (with fonts!) from knitr](https://www.andrewheiss.com/blog/2021/08/27/tikz-knitr-html-svg-fun/) (2021-08-27).

**Use case.** Use TikZ for diagrams (DAGs, schematics) and get SVG in HTML output, PDF in LaTeX output, with the *same* fonts in both.

**Why default knitr+TikZ is unsatisfying.** For HTML, knitr falls back to a low-res PNG. Naive SVG conversion via `dvisvgm` strips fonts. The fix is to set `--font-format=woff` so fonts get embedded into the SVG.

**Modern approach** (knitr supports `dvisvgm.opts` via `engine.opts`):

```r
#| label: setup
Sys.setenv(LIBGS = "/usr/local/share/ghostscript/9.53.3/lib/libgs.dylib.9.53")
```

```r
#| label: setup
#| include: false
if (knitr::is_latex_output()) {
  knitr::opts_template$set(
    tikz_settings = list(fig.ext = "pdf", fig.align = "center")
  )
} else {
  knitr::opts_template$set(
    tikz_settings = list(fig.ext = "svg", fig.align = "center",
                         engine.opts = list(dvisvgm.opts = "--font-format=woff"))
  )
}
```

Then any TikZ chunk uses the template:

````markdown
```{tikz dag-text, echo=FALSE, fig.cap="DAG with text", opts.label="tikz_settings"}
\usetikzlibrary{positioning}
\begin{tikzpicture}[every node/.append style={draw, minimum size=0.5cm}]
\node [draw=none] (X) at (0,0) {$X_{it}$};
\node [draw=none] (Y) at (2,0) {$Y_{it}$};
\node [rectangle] (Z) at (1,1) {$Z$};
\path [-latex] (X) edge (Y);
\draw [-latex] (Z) edge (Y);
\draw [-latex] (Z) edge (X);
\end{tikzpicture}
```
````

**Custom fonts that survive both PDF and HTML.** Use `pdflatex` with font packages (not XeTeX, see the caveat below):

```r
font_opts <- list(extra.preamble = c("\\usepackage{libertine}",
                                     "\\usepackage{libertinust1math}"),
                  dvisvgm.opts = "--font-format=woff")
```

**Pre-merge / manual hook** (older knitr without `dvisvgm.opts` plumbing):

```r
embed_svg_fonts <- function(before, options, envir) {
  if (!before) {
    paths <- knitr:::get_plot_files()
    knitr:::in_base_dir(
      lapply(paths, function(x) {
        path_svg <- xfun::with_ext(x, "svg")
        path_dvi <- xfun::with_ext(x, "dvi")
        if (system2('dvisvgm', c('--font-format=woff',
                                  '-o', shQuote(path_svg),
                                  shQuote(path_dvi))) != 0)
          stop('Failed to convert ', path_dvi, ' to ', path_svg)
      })
    )
  }
}
knitr::knit_hooks$set(embed_svg_fonts = embed_svg_fonts)
```

**Caveats.**

- macOS-specific Ghostscript/dvisvgm wiring. Set `LIBGS` to the actual `libgs.dylib` path, whose version number changes with each MacTeX upgrade.
- RStudio (and Positron, by extension) doesn't inherit shell environment variables, so set `LIBGS` via `Sys.setenv()` inside the document, not in `.Renviron` alone.
- **Do not use XeTeX for HTML output.** XeTeX produces `.xdv`, but knitr hardcodes `.dvi → dvisvgm` for SVG. Use `pdflatex` with font packages (`libertine`, `gfsartemisia-euler`, etc.) for dual PDF+HTML output.

## Sources

- [How to create separate bibliographies in a Quarto document](https://www.andrewheiss.com/blog/2023/12/11/separate-bibliographies-quarto/) (2023-12-11)
- [Guide to generating and rendering computational markdown content programmatically with Quarto](https://www.andrewheiss.com/blog/2024/11/04/render-generated-r-chunks-quarto/) (2024-11-04)
- [How to automatically convert TikZ images to SVG (with fonts!) from knitr](https://www.andrewheiss.com/blog/2021/08/27/tikz-knitr-html-svg-fun/) (2021-08-27)
