---
name: reference-revealjs-pdf-export
description: How a revealjs deck becomes a PDF (browser print), the page-size formula, and the post-render recipe
metadata:
  type: reference
---

A revealjs PDF is a browser print, never a Quarto output. Verified 2026-11-07 on Quarto 1.11.9.

- `quarto render` emits HTML only. `?print-pdf` (or `?view=print`, what Quarto's plugin now writes) switches reveal to print view: slides laid out as blocks, each `slide-background` moved inside its slide, and an injected `@page { size: … }` at `slide size × (1 + margin)`. A 1280x800 deck with `margin: 0.1` prints to 1056 x 660 pt; the stock 1050x700 to 865.92 x 577.92 pt.
- The browser's print backend writes the file (`Producer: Skia/PDF` from Chrome), text vectorial. Grounds and coloured pills come out because reveal's `css/print/pdf.scss` sets `print-color-adjust: exact` under `html.reveal-print`.
- Quarto bundles the `pdfexport` plugin unconditionally (`pluginBundles` in `quarto.js`), so the `E` key and the menu entry `PDF Export Mode` exist in every deck and no format option adds or removes them. Both only toggle the query string and reload. Quarto sets `pdfSeparateFragments: false`, so one page per slide.
- Render-time variant, measured working: a project `post-render:` script reads `QUARTO_PROJECT_OUTPUT_FILES` (newline-separated, project-relative, with `QUARTO_PROJECT_RENDER_ALL=1`) and calls `chromium --headless=new --print-to-pdf=… "file://$PWD/$f?print-pdf"`, dropping the PDF beside the HTML in one render. 1.7 s for a 16-slide self-contained deck. Project-level only: an extension's `contributes:` takes shortcodes, filters, formats and engines, no hook.
- In CI this needs no install: GitHub's `ubuntu-24.04` image ships Chrome and Chromium (156 on 2026-11-07).

Headless chromium constraints on this machine are in [[feedback_browser_layout_probe]]; the decision not to wire this into quarto-hebstr-slide is in that repository's `DESIGN-EXTENSION.md`.
