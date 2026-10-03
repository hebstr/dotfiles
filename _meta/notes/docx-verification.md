# DOCX verification: measurements behind `rules/docx.md`

The rules file keeps each rule in a sentence; this note keeps the measurements that ground them.
Moved out of `claude/.claude/rules/docx.md` on 2026-09-26, when the file went under the 9,000-character cap that the `instructions-budget` prek gate holds every file `inject-rules.sh` injects to (`.claude/DESIGN-INSTRUCTION-ROUTING.md`).

## LibreOffice install layout

`/usr/local/bin/libreoffice` is a symlink into `/opt/libreoffice<branch>/program/soffice`, installed from the TDF debs by the `sys-update libreoffice` module.
TDF ships one `/opt` tree per branch and its debs create only branch-versioned launchers (`libreoffice26.8`), so `libreoffice-update` maintains the unversioned symlink itself: it repoints it at the branch it just installed, then purges the superseded one.
A single tree is therefore expected, and two mean a purge failed.

## Measured defects

- **`officer` does not resolve style inheritance.** Measured 2026-09-09 on a document rendered against the `template.dotx` `hebstr-doc` shipped before its 2026-09-15 rebuild, whose `Normal` style carried `w:jc w:val="both"`: the body paragraph is visibly justified in the render and `align` comes back `NA`.
- **LibreOffice diverges from Word on justification.** Word has shrunk inter-word spaces through an undocumented algorithm since 2013, and the LibreOffice side states that "metrically equivalent fonts cannot guarantee MS Word-interoperability any more because of the undocumented changes in MS Word line break algorithm" (numbertext.org/typography, verified 2026-09-09).
- **LibreOffice can inject characters that are not in the document.** Converting a docx built on `template.dotx` puts a stray `X` at the end of the last body paragraph, absent from `word/document.xml`, appearing only when the document carries a bibliography and only under that template, the pre-rebuild one. Measured by difference 2026-09-09, cause not established, not re-measured on the rebuilt template.
- **A table of contents rasterizes empty.** Measured 2026-09-09 on a 36-page Quarto output: `word/document.xml` carries a well formed `TOC \o "1-4" \h \z \u` field instruction and the rendered page shows the heading with nothing under it.
- **Quarto emits a second `w:pPr` inside paragraphs it restyles.** Seventeen occurrences in the same output, one per figure and table caption, produced by `/opt/quarto/share/filters/main.lua` and not by any local extension.
- **Both readers flatten comment replies.** `officer::docx_comments()` (0.7.6) returns the `para_id` but no parent, and `pandoc --track-changes=all` (3.10) emits a reply as its own `comment-start` span with no parent attribute. Measured 2026-09-14 on a docx commented in Word online, 17 comments of which one reply, flattened by both. On 12 desktop Word files checked 2026-09-15, every one of the 24 comments with two or more paragraphs is named by its last paragraph in `commentsExtended.xml`, as `w15:paraId` or as a reply's `w15:paraIdParent`, and none by its first.
- **A reviewer's reference number belongs to the render they read.** Checked 2026-09-14 against the bibliography of the reviewed file.
- **`--convert-to png` rasterizes only the first page.** Reported by practitioners, not verified here.

## The unopenable document

Word refuses a document whose cell ends on something other than a paragraph, with a dialog that offers no recovery and names `/word/document.xml` line 0, column 0.
Measured 2026-09-11 on a Quarto report of 36 tables: 14 cells left open, Word refusing the document outright while LibreOffice converted it to PDF without a warning.
The position of the appended empty paragraph relative to a trailing `w:bookmarkEnd` is free, both orders verified in Word that day.

## Word fidelity

Pandoc's own contribution guide holds its maintainers to the same limit as this machine: "For docx or pptx tests, open the files in Word or Powerpoint to ensure that they weren't corrupted and that they had the expected result, and mention the Word/Powerpoint version and OS in your commit comment" (pandoc.org/CONTRIBUTING.html, verified 2026-09-09).

Three routes are closed, so none is worth proposing again.

- **No substitute engine closes the gap.** SSIM at 150 dpi against Word on 48 documents: ONLYOFFICE 0.908 for 42/48 pages matched, LibreOffice 0.892 for 43/48, for a stated set-difficulty variance of ±0.02 (oxi-dd65f4.gitlab.io, verified 2026-09-30). The benchmark's own engine claims the best of both figures, 0.903 for 48/48, and ships nowhere, so its lead reopens nothing. `officer` owns no layout engine at all.
  No delivery route reopens that verdict, since both reach the same converter: `X2tConverter` lives in `ONLYOFFICE/core` (AGPL-3.0), which Desktop Editors and Document Server share, so the bundled `x2t` of the desktop snap and the Docs conversion API render through one engine. Re-proposed on 2026-10-01 before this section was read, and withdrawn on it.
- **Pandoc to PDF captures no layout.** `pandoc <file>.docx --pdf-engine=typst -o <file>.pdf` keeps the content and loses the page: measured 2026-10-01 with pandoc 3.10 and typst 0.15.1 on a 9-page docx, 1.5 s, 1414 words against the docx's 1447, images carried straight out of the zip with no `--extract-media`, tables still tables, Libertinus Serif embedded and subset. It renders from the pandoc AST, so the reference doc's fonts, margins, headers, caption styles and field numbering are gone and the page size defaults to letter (`-V papersize=a4` fixes that one). It answers "give me something readable", never "show me the layout".
- **Word for the web and Graph `?format=pdf` render from the server's own font set**, which multi-tenant Office offers no way to extend, while this machine has the genuine Aptos family and Luciole: the local render uses the declared metrics and the cloud one substitutes, so for a `hebstr-doc` output the cloud route is worse, not better. Corrected by the user 2026-09-30 against an overclaim of mine reading the "looks the same as Print Layout view" sentence as certification; the same support page says "Many kinds of objects are displayed as placeholders" and nothing of fonts. Microsoft's font-substitution wording is published on a Publisher page and its Office Online Server custom-font page is retired, so this rests on the user's correction rather than on a citation.

### A fourth route is open and it is the real Word on `ju-TP2`, driven over SSH

**Approved by the user 2026-10-04**, which overturns the deferral of 2026-09-30 recorded in eds-prise's `PLAN.md` ("faute de Word sous la main"): `ju-TP2` carries Word, so the premise of that deferral is false.
The three closed routes above stay closed, and this one does not reopen them, the renderer being Word itself.

What is approved: a tool of this machine, on the pattern of `~/dotfiles/bin/.local/bin/transcribe`, whose driver stages the `.docx` into a scratch directory on `ju-TP2`, has Word export it through `ExportAsFixedFormat`, brings the PDF back and rasterizes it here with `pdftoppm`, the captures landing in `<project>/.claude/screenshots/`.
`transcribe`'s refusal on an unreachable remote comes with it: the control is unavailable when `ju-TP2` is down and says so rather than falling back on LibreOffice, which stays the gross-breakage check beside it.
Three gains over LibreOffice decide it: Word opening the file is itself the oracle that "The unopenable document" above approximates in Python, `Fields.Update()` fills the table of contents that a headless conversion leaves empty, and the line breaking is Word's own.

**Word drives in COM from an SSH session, and the blocker is the Windows session, measured 2026-10-04.**
`New-Object -ComObject Word.Application` succeeds through WSL interop over `ssh ju-TP2`, Word 16.0 build 16.0.20326, and `Documents.Add()` creates and manipulates a document without complaint.
But the interop child runs in Windows **session 0** with `[Environment]::UserInteractive` false, the user's desktop being session 2 (`quser`), because `WSL-KeepAlive` starts the distro before any logon.
There, on `2026-10-03_prise_csi_tables.docx`, `Documents.Open` returns `$null` and raises nothing, `ProtectedViewWindows.Open` throws `E_FAIL` for zero protected-view windows, and the next probe wedged: a later COM activation attaches to the wedged instance and inherits the hang, so a second run printed nothing at all and left `WINWORD.EXE` resident in session `Services`, killed by PID and the scratch directory removed the same day.
Office automation in a non-interactive session is unsupported by Microsoft and this is what that looks like, so the tool asserts the session before touching Word, which `[Environment]::UserInteractive` settles for free.

**Word reaches session 2 through a scheduled task, decided by the user 2026-10-04.**
A task registered as `julien` with an interactive logon carries the PowerShell payload, and the driver triggers it from session 0 by `schtasks /run`, then waits on the PDF rather than on the task's exit.
It needs no elevation, it leaves the SSH and keep-alive arrangement of `_meta/notes/ssh-lan-wsl.md` untouched, and its cost is one Windows object plus the requirement that the Windows session be open, which it is permanently on this machine (`quser` showing the console session open since 2026-10-03 17:26).
Rejected against it: restarting the distro from the interactive session so every interop child lands in session 2, which is simpler in the payload and costs the unattended-boot property that note measured on 2026-09-19, `ssh ju-TP2` becoming dependent on a logged-on session.

**No font of the deliverable's declared family is installed there, and the user decided 2026-10-04 not to install one.**
`template.dotx` of `hebstr-doc` declares `Aptos` and `Aptos Display` in its `fontTable.xml`; `find` over `C:\Windows\Fonts` and the Office tree on `ju-TP2` returns no Aptos and no Luciole, where this machine carries both.
The pass therefore measures the recipient's fallback render, which `reference_word_embedded_fonts_blocked.md` names as the case the Word output is designed around, and never the render at the declared metrics.
A line break read from it is the fallback's line break.

Rejected, with what disqualifies each:

- **Capturing the Word window on the Windows desktop** instead of exporting a PDF: it needs an unlocked interactive session, it depends on the window state, the zoom and the ribbon, and it buys nothing on a layout question that Word's own PDF does not give.
- **A recipe in `rules/docx.md` with the PowerShell inline in an `ssh` call**, no tool: the quoting traps through SSH, WSL and PowerShell are repaid at every pass and nothing is testable.
- **Doing nothing**, LibreOffice plus a manual pass by the user: the state until 2026-10-04, and it leaves the render unseen by Claude, which is the request itself.

Open:

- **The scheduled task is decided and not yet created**, and the whole route is untested past the COM activation: nothing has come back as a PDF, so no claim about Word's rendering of a deliverable rests on it yet.
- **`rules/docx.md`, section "What nothing on this machine settles", stands until the route works.** It is rewritten when a deliverable has come back as Word's own PDF, never on the strength of this design.
- Whether the control is worth running on the full report (44 pages) rather than on the assembled tables and figures is untested, no timing having been measured past the open call.
