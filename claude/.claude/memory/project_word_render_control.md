---
name: project_word_render_control
description: The word-render control driving the real Word on ju-TP2 over SSH, and the Office activation that blocks it
metadata:
  type: project
---

`word-render` (bash driver plus `word-render-payload.ps1`, `bin` stow package, `_meta/tests/word-render.bats`) renders a `.docx` through the real Word on `ju-TP2` and brings the pages back as PNGs, Word's own `ExportAsFixedFormat` PDF rasterized here by `pdftoppm`.
Built 2026-10-04 and **blocked that day on Office activation**: Word there is `Word (Unlicensed Product)`, which opens and paginates a document but blocks forever on every save and export behind a `Sign in to set up Office` dialog, so the payload refuses on `Application.Caption` instead of hanging.
Until the user signs in on that desktop, no claim about Word's rendering rests on this route and `rules/docx.md`, section "What nothing on this machine settles", stands as written.

**Why:** the design, every measurement, the three deviations from the written plan (fixed job slot, `Start-ScheduledTask`, the `result.txt` sentinel) and the correction that Aptos *is* available there as a cloud font live in `~/dotfiles/_meta/notes/docx-verification.md`, section "A fourth route is open".

**How to apply:** do not re-derive the route or re-propose LibreOffice, ONLYOFFICE, Word for the web or `pandoc --pdf-engine=typst` ([[reference_word_embedded_fonts_blocked]]); run `word-render <file.docx>` and read its refusal, which names the registration command for the `Claude-WordRender` scheduled task when that task is missing.
