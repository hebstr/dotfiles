---
name: project_word_render_control
description: The word-render control driving the real Word on ju-TP2 over SSH, its --capture route, and the unlicensed Office that shuts every write path
metadata:
  type: project
---

`word-render` (bash driver plus `word-render-payload.ps1`, `bin` stow package, `_meta/tests/word-render.bats`) renders a `.docx` through the real Word on `ju-TP2`, captures landing in `<project>/.claude/screenshots/`.
Word there is `Word (Unlicensed Product)` and the user has no subscription, so **every write path is shut** (`ExportAsFixedFormat`, `SaveAs2` to PDF and to `.docx`, and `PrintOut` to `Microsoft Print to PDF` all block forever) and the default `pdf` mode refuses on `Application.Caption` in 10 s rather than hanging.
**`word-render --capture` is the route that works**: Word's layout engine runs fully in reduced functionality, so it photographs the window page by page at screen resolution and the line breaking, justification and pagination read from it are Word's own. It carries no text layer, it is the screen rendering, and it renders the page dark while Windows is in dark mode.

**Why:** the design, every measurement, the three deviations from the written plan (fixed job slot, `Start-ScheduledTask`, the `result.txt` sentinel), the four mechanisms the capture rests on (hide the `NUIDialog` rather than close it, navigate by `Document.GoTo`, end the instance `Quit` leaves, `SetProcessDPIAware`) and the correction that Aptos *is* available there as a cloud font live in `~/dotfiles/_meta/notes/docx-verification.md`, sections "A fourth route is open" and "The capture route".

**How to apply:** do not re-derive the route or re-propose LibreOffice, ONLYOFFICE, Word for the web or `pandoc --pdf-engine=typst` ([[reference_word_embedded_fonts_blocked]]); run `word-render --capture <file.docx>`, and read a colour from it only once the dark-mode question of the note is settled. Its refusal names the registration command for the `Claude-WordRender` scheduled task when that task is missing.
