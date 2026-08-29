---
name: Quarto custom crossref floats from knitr chunks
description: How to make a custom crossref type (`anx`) work from a chunk label, via a pre-quarto `FloatRefTarget` filter, and the two routes abandoned before it (R helper emitting the div, knitr label hook)
metadata:
  type: project
---

Quarto has no built-in appendix crossref prefix: the built-in types are fig/tbl/eq/sec/lst/thm/lem/cor/prp/cnj/def/exm/exr, and `crossref: appendix-title`/`appendix-delim` only letter book chapters (`crossref.lua` gates them on `bookItemType == "appendix"`).
A custom `crossref: custom: [{kind: float, key: anx, ...}]` is the only mechanism outside a book project.

`#| label: anx-x` can never produce a float on its own: the knitr engine hardcodes `^#?(fig|tbl)-` in `is_figure_label()`/`is_table_label()` (`/opt/quarto/share/rmd/hooks.R:1110-1120`) and drops any other label before the id reaches Pandoc.

**The working route is a `at: pre-quarto` Lua filter.** At that stage Quarto's `FloatRefTarget` custom node is already built and still mutable, so a float authored as an ordinary table or figure can be retyped:

```lua
function FloatRefTarget(float)
  local id = float.identifier
  if id:match("^tbl%-anx%-") or id:match("^fig%-anx%-") then
    float.identifier = id:gsub("^%a+%-", "")
    float.type = "Annexe"
    return float
  end
end
```

`float.type` takes the `reference-prefix` string, not the key: Quarto resolves a float through `crossref.categories.by_name`, and `obj_mapping` in `main.lua` maps `reference-prefix` to `name` while `key` becomes `ref_type`.
`#| label: tbl-anx-x` + `#| tbl-cap:` then renders exactly like a `tbl` float, and a hand-written `::: {#anx-x}` div shares the same counter.
Implemented 2026-08-29 in `quarto-hebstr-doc` (`filters/crossref-anx.lua`, `tests/test_crossref_anx.lua`, `tests/anx-float.sh`) and shipped the same day in `v1.4.0`, so `quarto add hebstr/quarto-hebstr-doc@v1.4.0` carries it.

Two things measured while implementing it:

- **`parent_id` is not yet set at `pre-quarto`.** `crossref_mark_subfloats` lives in `quarto_crossref_filters`, which runs after that entry point, so a filter there cannot tell a subfloat from a top-level float and no guard on nesting is writable.
- **A document-level `crossref:` replaces the format's block wholesale**, it does not merge into it. Redeclaring the custom type in a document to change its prefix drops `title-delim` and `tbl-title` from the format, and the caption silently reverts to `Annexe 1:`; both keys have to be repeated alongside `custom:`.

Degradation is silent in both directions: without the filter the render still exits 0 and the float comes out as an ordinary `tbl`, which is why the feature carries a render-probe shell test rather than unit tests alone.

Caption keys are derived as `<ref>-cap` (`main.lua:17786`), so on a `#anx-` div only `anx-cap` is read and `tbl-cap` is silently ignored.
Per-type numbering is closed to custom types (`anx-labels` fails YAML validation, the `crossref` schema is `closed: true`); lettering requires global `crossref: labels: "alpha A"` plus pinning `fig-labels`/`tbl-labels`/`eq-labels`/`sec-labels`/`lst-labels` back to `arabic` and `subref-labels` to `alpha a`, which is why it was dropped.
A custom float gets `class="quarto-float-<key>"`, so any theme rule written against `.quarto-float-tbl` (centred caption, top margin) has to name the custom key too or the caption renders left-aligned.

Two routes abandoned, do not reopen:

- An R helper emitting the div through `knitr::asis_output()` (`anx_qmd()` in md-nesrine). It forces `gt::as_raw_html()` and three silent traps: `inline_css = TRUE` routes through juicyjuice and V8 and kills the render far from the cause; a table carrying a literal `id` is read as a subfloat once it is a direct child of the float div (this bit through `gt_qmd`, whose `id` defaulted to `"tbl-id"` until 2026-08-29 and now defaults to `NULL`, so it survives only for an explicit `id`); bare raw HTML makes Pandoc wrap gt's `<style>` in a `<p>`.
- A `knitr::opts_hooks$set(label = )` rewriting `anx-x` to `tbl-anx-x` to get the bare prefix. Works, but hijacks the `label` option of every chunk, makes the feature R-only, and inverts the failure mode: without the hook the float loses number and caption, whereas `tbl-anx-x` without the filter degrades to a plain, visible `tbl` float.

Related: [[project_hebstr_doc_adaptive_figures]], [[user_quarto_typst_only]]
