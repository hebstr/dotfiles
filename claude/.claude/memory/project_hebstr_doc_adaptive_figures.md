---
name: Adaptive light/dark ggplot figures in quarto-hebstr-doc
description: Mechanism + hard constraints for theme-adaptive ggplot figures in quarto-hebstr-doc (sentinel ink + inline SVG); lightbox is incompatible
metadata:
  type: project
---

Making a ggplot figure's ink + background follow the Quarto light/dark toggle at runtime in `quarto-hebstr-doc` (HTML).

**Core constraint**: adaptivity requires the SVG **inline in the DOM**. A base64 `<img>` data URI (Quarto's default under `embed-resources`) is isolated: page CSS, `currentColor`, and `var(...)` cannot reach into it.

**Working recipe (validated 2026-07-07, spike in `example.qmd`)**:
- `theme_hebstr()` = ggplot2 4.0 theme with **sentinel colours**: `theme_minimal(ink = "#010101", paper = NA)` + explicit `theme(axis.text=..#010101, panel.grid=..#020202, axis.ticks=..#020202)`. ggplot2 4.0 `ink=` does **not** reach tick labels (grey30 `#4D4D4D`) or gridlines (`#EAEAEA`), so they must be set explicitly.
- Chunk device `dev: svglite` + `dev.args: !expr list(bg = "transparent")`. The white background comes from svglite's device `bg`, not from ggplot `paper` — `paper = NA` alone leaves it.
- Lua filter `_extensions/hebstr-doc/filters/adaptive-figure.lua`: reads the `.svg` file, remaps `#010101`→`currentColor`, `#020202`→`var(--caption-color)`, inlines as `pandoc.RawInline`. Ink then follows body colour per theme (`body.quarto-light`/`body.quarto-dark`); grid uses `--caption-color` (defined in both themes; there is **no** `--body-color` custom property, so ink uses `currentColor`).
- At Lua filter stage the image `src` is a **file path** (base64 embedding happens later), so the filter reads the file directly (no base64 decode needed).
- Keep the SVG's intrinsic `pt` dimensions (they carry the aspect ratio) + `max-width:100%`; do **not** depend on `viewBox` (Quarto's HTML re-serialisation lowercases `viewBox`→`viewbox`; browsers re-fix it for inline SVG, but don't rely on it).

**Lightbox is incompatible** with this approach (decision: adaptive figures opt out): pre-quarto filter → no lightbox anchor at all; post-quarto (`filters: [quarto, ...]`) → anchor survives but under `embed-resources` its `href` points to the deleted `*_files/*.svg` (never rewritten to a data URI) → 404; and GLightbox's fixed dark modal cannot follow the runtime theme anyway. A working zoom would need a separate self-contained baked figure.

**Done**: prose-lint (`~/dotfiles/bin/.local/bin/prose-lint`) now exempts `$$…$$` display-math blocks (was flagging math content lines as soft wraps).

**Still to productize** (spike wired at document level in `example.qmd`): move filter + device wiring into `_extension.yml` (html); decide where `theme_hebstr()` lives (hebstr R package vs shipped snippet); gate the filter on sentinel presence so non-adaptive SVG figures keep lightbox; validate in a real consumer project. See [[feedback_verify_quarto_theming]].
