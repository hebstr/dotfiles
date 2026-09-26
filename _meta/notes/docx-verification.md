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
