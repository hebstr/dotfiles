---
name: Adaptive light/dark figures in quarto-hebstr-doc
description: Decision (2026-07-20) — theme-adaptive figures use Quarto's native `renderings`; the custom Lua filter is dropped, and the lightbox does survive `embed-resources`
metadata:
  type: project
---

Making a figure's ink follow the Quarto light/dark toggle at runtime in `quarto-hebstr-doc` (HTML).

**Decision (2026-07-20): use Quarto's native `#| renderings: [light, dark]`.** The cell emits one plot per mode, Quarto tags the outputs `.light-content` / `.dark-content`, and `body.quarto-light` / `body.quarto-dark` selects one via a `display` rule. `adaptive-figure.lua` is deleted; do not rebuild it. Usage is documented in the repo README and illustrated in `example.qmd`.

Constraints of the native path:
- Incompatible with cell-level crossref options (`label:`, `fig-cap:`): wrap the cell in a fenced div (`::: {#fig-x}` … caption … `:::`).
- Give the device a transparent background (`dev.args: !expr list(bg = "transparent")`) so the page background shows through; only the ink then needs a per-mode value.
- ggplot2 4.0 `ink=` does **not** reach tick labels or gridlines: set `axis.text`, `panel.grid` and `axis.ticks` explicitly, or the figure silently loses both.
- Cost: two SVGs in the output (+238 KB vs +64 KB for the dropped inline-SVG filter, against a 3.2 MB font baseline).

**Correction to an earlier note: the lightbox is NOT broken by `embed-resources`.** The anchor `href` does point at a `*_files/*.svg` that is deleted after render, but Quarto rewrites the source at runtime and GLightbox loads a `data:` URI. Verified headless (`chromium --headless --dump-dom` with an injected click probe) on a plain figure and on a `renderings` figure alike. The previous "adaptive figures opt out of lightbox" conclusion was wrong, and it was the main reason the custom filter looked acceptable.

Why the filter lost: it forced every adaptive figure to give up the lightbox (inline SVG carries no anchor), and its sentinel-colour convention (`#010101` ink, `#020202` grid, remapped to `currentColor` / `var(--caption-color)`) is checked nowhere. The version actually committed (fd04dbf) omitted the explicit `axis.text` / `panel.grid` / `axis.ticks` sentinels and rendered without gridlines or tick labels in both modes.

Headless verification recipe, reusable for the accessibility work: `chromium --headless --disable-gpu --no-sandbox --virtual-time-budget=9000 --dump-dom file://…` runs injected JS, so a script can click an element and append its verdict to the DOM. Snap confinement requires the file to live under `$HOME`, not `/tmp`. See [[feedback_verify_quarto_theming]].
