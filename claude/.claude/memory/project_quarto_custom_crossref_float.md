---
name: Quarto custom crossref floats from knitr chunks
description: "Consumer side of the custom `anx` crossref type shipped by quarto-hebstr-doc: author annexes as `tbl-anx-`/`fig-anx-` chunks with `tbl-cap`, `anx-cap` on a div, repeat `title-delim`/`tbl-title` when redeclaring `crossref:`, no per-type lettering"
metadata:
  type: project
---

The mechanism (the `pre-quarto` filter `filters/crossref-anx.lua` retyping a `FloatRefTarget`, why knitr's `is_figure_label()`/`is_table_label()` rule out a bare `anx-` chunk label, `float.type` taking the `reference-prefix` name, `parent_id` not yet set, the `quarto-float-anx` theme rules) and the two abandoned routes (R helper emitting the div, knitr `label` hook; do not reopen) are in `~/Documents/packages/quarto-hebstr-doc/.claude/CLAUDE.md` § "Custom crossref type : `anx` (annexes)". Shipped in `v1.4.0` (2026-08-29).

What a consumer document needs to know:

- **Authoring.** `#| label: tbl-anx-x` + `#| tbl-cap:` (or `fig-anx-` + `fig-cap`) renders exactly like a `tbl` float, and a hand-written `::: {#anx-x}` div shares the same counter. Without the filter the render still exits 0 and the float comes out as an ordinary `tbl`, so a missing filter is silent.
- **Caption key on a div.** Caption keys are derived as `<ref>-cap` (`caption_attr_key` in `parse_float_div`, `/opt/quarto/share/filters/main.lua`), so on a `#anx-` div only `anx-cap` is read and `tbl-cap` is silently ignored.
- **Redeclaring `crossref:`** in a document replaces the format's block wholesale: repeat `title-delim` and `tbl-title` alongside `custom:`, or the caption silently reverts to `Annexe 1:`. See [[reference_quarto_doc_crossref_overrides_format]].
- **No lettering.** Per-type numbering is closed to custom types (`anx-labels` fails YAML validation, the `crossref` schema is `closed: true`); lettering requires global `crossref: labels: "alpha A"` plus pinning `fig-labels`/`tbl-labels`/`eq-labels`/`sec-labels`/`lst-labels` back to `arabic` and `subref-labels` to `alpha a`, which is why it was dropped.

Related: [[user_quarto_typst_only]]
