---
name: st.dataframe honours only three CSS properties from a pandas Styler
description: Streamlit's dataframe grid extracts only `color`, `background-color` and `font-weight` from a pandas Styler; everything else (font-size included) is silently dropped, and no CSS reaches rows or cells because the grid is a canvas
metadata:
  type: reference
---

`st.dataframe` accepts a `pandas.Styler`, but the frontend keeps only three declarations from the generated style block and drops the rest without warning:

```
color            -> themeOverride.textDark   (cell text colour; also textBubble on bubble/multi-select cells, linkColor on URI cells)
background-color -> themeOverride.bgCell
font-weight      -> themeOverride.baseFontStyle
```

Established 2026-08-31 by reading the shipped bundle (function `Am` in `streamlit/static/static/js/*.js`, Streamlit 1.60), not from the docstring, which only says "custom cell values, colors, and font weights". The Python side (`elements/lib/pandas_styler_utils.py`) passes declarations through verbatim, so the filtering is entirely in the frontend.

**Consequences worth knowing before designing a table.**

- **No font size.** A `●` stays at cell font size. For a dot the size of the grid's own selection marker, use `⬤` (U+2B24) instead of scaling.
- **No CSS on rows or cells at all.** The grid is drawn by glide-data-grid in a `<canvas>`, so no row is a DOM node: `::selection`, `:nth-child`, `scrollIntoView` and every stylesheet rule are inert. The Styler is the *only* colouring path.
- **The selection column cannot be restyled.** Its marker colour comes from the theme `primaryColor` and no API exposes it. To mark rows by status, add your own column.
- **`Styler.map(..., subset=[col])` chains onto `Styler.apply(..., axis=None)`** cleanly; declarations merge per cell. `applymap` is gone in pandas 3.
- **Column config alternatives that do not solve colouring**: `CheckboxColumn` renders a real checkbox with no colour control; `MarkdownColumn` shows plain text in the cell and renders markdown only in the click-to-expand overlay.
- **Cost**: the marshalling emits one CSS rule per styled cell, resent on every rerun (measured on one project: 1.9 KB at 18 rows, 110 KB at 1000, 570 KB at 5000). Use `subset` to limit it, and `st.fragment` to limit rerun frequency, noting `st.fragment` is incompatible with `AppTest` (streamlit#9242).

Related: [[reference_streamlit_altair_charts]] for the chart-side traps in the same stack.
