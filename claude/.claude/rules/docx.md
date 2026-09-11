# DOCX verification

On-demand reference for inspecting a `.docx`, whether it came out of Pandoc, Quarto or a Word user.
Load before the first docx verification of a session, and whenever the choice between a mechanical assertion and a visual pass is decision-relevant.
Nothing here governs authoring a docx; the Quarto render gate in `rules/quarto.md` still owns the `.qmd` that produced it.

## Toolchain

```
| Tool | Role | Source |
|---|---|---|
| `officer` | Read a docx from R into a data frame: styles, runs, links, direct formatting | R package, `docx_summary()` and `styles_info()` |
| `unzip` + `rg` | Read `word/document.xml`, `word/styles.xml`, `word/settings.xml` directly; the only route to anything resolved through style inheritance | coreutils, ripgrep |
| `libreoffice` | Headless conversion to PDF, the only rendering engine on this machine | `/usr/local/bin/libreoffice` |
| `pdftoppm` | PDF page to PNG, to hand a page to the native `Read` tool | poppler-utils |
| `pandoc` | Reads docx; with `-f docx+styles` it surfaces style names as `custom-style` attributes | `/usr/bin/pandoc` |
| `python3` | Walk `word/document.xml` to assert the OOXML content model Word enforces and no renderer tests | stdlib, `zipfile` + `xml.etree.ElementTree` |
```

Every recipe found online calls the binary `soffice`, and `soffice` is not on the PATH here: `/usr/local/bin/libreoffice` is a symlink into `/opt/libreoffice<branch>/program/soffice`, installed from the TDF debs by the `sys-update libreoffice` module.
TDF ships one `/opt` tree per branch and its debs create only branch-versioned launchers (`libreoffice26.8`), so `libreoffice-update` maintains the unversioned symlink itself: it repoints it at the branch it just installed, then purges the superseded one. A single tree is therefore expected, and two mean a purge failed.
Call `libreoffice`, never a hardcoded `/opt` path, which moves on every branch change.
`officer` is not a layout engine and renders nothing; it reads structure.

## Routing

1. **Start with the mechanical assertion.** `officer::docx_summary(x, detailed = TRUE)` returns one row per run and carries `paragraph_stylename`, `character_stylename`, `align`, `link`, `link_to_bookmark`, `bookmark_start`, plus fonts, `bold`, `italic`, `color`. A citation hyperlink comes back as `character_stylename` plus `link_to_bookmark` holding the anchor, which settles a `link-citations` question with no rendering at all.
2. **Anything inherited from a named style needs the XML.** `docx_summary()` reports direct paragraph formatting only, so `align` is `NA` on a paragraph justified by its style rather than by its own `w:jc`. Read `word/styles.xml` for those, and remember that Pandoc resolves a style by its `w:name`, never by its `w:styleId`: comparing identifiers is how a French template reads as covering nothing.
3. **Rasterize only for what the data cannot show**, page layout, spacing, a caption's position, a colour actually landing. `libreoffice --headless -env:UserInstallation=file:///tmp/<profile> --convert-to pdf --outdir <dir> <file>.docx`, then `pdftoppm -r 110 -png -f <first> -l <last> <file>.pdf <prefix>`, then the native `Read` tool on the PNG. Around 1,5 s for a short document.
4. **Never turn a LibreOffice render into a claim about Word.** See the defects below; on appearance the gap falls exactly on justification and line breaking.
5. **A docx assembled by anything other than Word owes a structural pass before handover**, which no render performs: LibreOffice converts and rasterizes documents Word refuses to open outright. See "Structural validity" below for the check.

The isolated profile in step 3 is not optional hygiene: concurrent invocations sharing the default profile fail silently.

## Measured defects

- **`officer` does not resolve style inheritance.** Measured 2026-09-09 on a document rendered against `hebstr-doc`'s `template.dotx`, whose `Normal` style carries `w:jc w:val="both"`: the body paragraph is visibly justified in the render and `align` comes back `NA`. Reading justification from `docx_summary()` alone reports the opposite of the truth, which is worse than reporting nothing.
- **LibreOffice diverges from Word precisely on justification.** Word has shrunk inter-word spaces through an undocumented algorithm since 2013, and the LibreOffice side states that "metrically equivalent fonts cannot guarantee MS Word-interoperability any more because of the undocumented changes in MS Word line break algorithm" (numbertext.org/typography, verified 2026-09-09). A justified paragraph can therefore wrap different words on different lines between the two. Gross breakage is visible in the render, a line-break judgement is not transferable.
- **LibreOffice can inject characters that are not in the document.** Converting a docx built on `template.dotx` puts a stray `X` at the end of the last body paragraph, absent from `word/document.xml`, appearing only when the document carries a bibliography and only under that template (measured by difference 2026-09-09, cause not established). Read an unexplained glyph in a rasterized page as a conversion artefact until the XML confirms it.
- **Pandoc emits a `w:pStyle` whether or not the reference doc defines the style.** The reference dangles, the renderer falls back to `Normal`, and nothing errors. `officer` reports such a paragraph with a `NA` style name, which is the signal to look for.
- **Pandoc writes the syntax highlighting styles itself**, `Source Code` and 31 `*Tok` character styles, from the highlighting theme rather than from the reference doc. Finding them in an output proves nothing about the template.

- **A table of contents rasterizes empty**, because headless conversion does not run Word's field update. Measured 2026-09-09 on a 36-page Quarto output: `word/document.xml` carries a well formed `TOC \o "1-4" \h \z \u` field instruction and the rendered page shows the heading with nothing under it. Read that as a field waiting for Word, not as a missing table of contents.
- **Quarto emits a second `w:pPr` inside paragraphs it restyles**, one per figure and table caption, where a paragraph takes a single properties element and `w:pStyle` comes first inside it. Seventeen occurrences in the same output, produced by `/opt/quarto/share/filters/main.lua` and not by any local extension. LibreOffice renders through it; whether Word does is untested. Do not chase it as a local defect.

One further limit is reported by practitioners and not verified here: `--convert-to png` on a docx only rasterizes the first page, which is why the PDF step is mandatory rather than a detour.

A caption sitting alone at the foot of a page is usually pagination, not a lost figure: an inline image taller than the remaining space moves whole to the next page. Confirm on the following page before reporting anything.

## Structural validity, which a render never tests

Word enforces parts of the OOXML content model that LibreOffice ignores, and it enforces them by refusing to open the file rather than by degrading it: the dialog offers no recovery and names `/word/document.xml` line 0, column 0, which points at nothing. A document that converts and rasterizes cleanly here can therefore be unopenable for its only reader, so a docx assembled by anything other than Word owes a structural pass before it is handed over.

The rule met in practice is that **the last block-level element of a `w:tc` must be a `w:p`**, `w:tbl` and `w:sdt` not counting, range markers such as `w:bookmarkEnd` being transparent to it. Word reports the breach as "an ambiguous cell mapping was encountered", in French "un mappage de cellule ambigu a été rencontré", and names the missing element: "`<p>` elements are required before each `</tc>`". The check costs one pass over `word/document.xml`:

```python
import zipfile, xml.etree.ElementTree as ET
W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
r = ET.fromstring(zipfile.ZipFile(path).read("word/document.xml"))
bad = [tc for tc in r.iter(W + "tc")
       if [k for k in tc if k.tag in (W + "p", W + "tbl")][-1:] != [] and
       [k for k in tc if k.tag in (W + "p", W + "tbl")][-1].tag != W + "p"]
```

The shape that produces it is a table nested as the last thing in a cell, which no author writes by hand and a pipeline reaches easily: Quarto wraps every cross-referenced float in a one-cell table to keep caption and content together, and a `flextable` or a `gt` table arrives from knitr as a raw `{=openxml}` block ending on `</w:tbl>`. Measured 2026-09-11 on a Quarto report of 36 tables: 14 cells left open, Word refusing the document outright while LibreOffice converted it to PDF without a warning. The fix belongs to whatever emits the raw block, an empty paragraph appended to its text; a Pandoc `Para` carrying no inline is dropped before the writer sees it, so it cannot be inserted at AST level. Its position relative to a trailing `w:bookmarkEnd` is free, both orders verified in Word that day.

Two neighbouring breaches are worth knowing as non-blocking, since finding one in a file Word opens means nothing: a paragraph carrying two `w:pPr` (Quarto emits one per figure and table caption) and a `w:pStyle` referring to a style the reference doc does not define. Word opens both.

## What nothing on this machine settles

Fidelity to Word itself. No installed tool renders a docx the way Word does, and the divergence is documented, active and version-dependent rather than a fixed set of known gaps.
Pandoc's own contribution guide holds its maintainers to the same limit: "For docx or pptx tests, open the files in Word or Powerpoint to ensure that they weren't corrupted and that they had the expected result, and mention the Word/Powerpoint version and OS in your commit comment" (pandoc.org/CONTRIBUTING.html, verified 2026-09-09).
Before a docx template or a docx output is declared finished, say plainly that a pass on a real Word install is owed, rather than presenting a LibreOffice render as the check.

## References

- Quarto Word templates: https://quarto.org/docs/output-formats/ms-word-templates.html
- LibreOffice command line parameters: https://help.libreoffice.org/latest/en-US/text/shared/guide/start_parameters.html
- `officer::docx_summary()`: https://davidgohel.github.io/officer/reference/docx_summary.html
