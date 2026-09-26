---
paths:
  - "**/*.docx"
---

# DOCX verification

On-demand reference for inspecting a `.docx`, whether it came out of Pandoc, Quarto or a Word user.
Nothing here governs authoring a docx; the Quarto render gate in `rules/quarto.md` still owns the `.qmd` that produced it.
The measurements behind each rule are in `~/dotfiles/_meta/notes/docx-verification.md`.

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

Every recipe found online calls the binary `soffice`, which is not on the PATH here: call `libreoffice`, never a hardcoded `/opt` path, which moves on every branch change.
`officer` is not a layout engine and renders nothing; it reads structure.

## Routing

1. **Start with the mechanical assertion.** `officer::docx_summary(x, detailed = TRUE)` returns one row per run and carries `paragraph_stylename`, `character_stylename`, `align`, `link`, `link_to_bookmark`, `bookmark_start`, plus fonts, `bold`, `italic`, `color`. A citation hyperlink comes back as `character_stylename` plus `link_to_bookmark` holding the anchor, which settles a `link-citations` question with no rendering at all.
2. **Anything inherited from a named style needs the XML.** `docx_summary()` reports direct paragraph formatting only, so `align` is `NA` on a paragraph justified by its style rather than by its own `w:jc`. Read `word/styles.xml` for those, and remember that Pandoc resolves a style by its `w:name`, never by its `w:styleId`: comparing identifiers is how a French template reads as covering nothing.
3. **Rasterize only for what the data cannot show**, page layout, spacing, a caption's position, a colour actually landing. `P=$(mktemp -d); trap 'rm -rf "$P"' EXIT; libreoffice --headless -env:UserInstallation="file://$P" --convert-to pdf --outdir <dir> <file>.docx`, then `pdftoppm -r 110 -png -f <first> -l <last> <file>.pdf <prefix>`, then the native `Read` tool on the PNG, kept in `<project>/.claude/screenshots/` (`rules/chromium.md`, "Where verification captures go"). Always go through the PDF: `--convert-to png` is reported to rasterize only the first page.
4. **Never turn a LibreOffice render into a claim about Word.** See the defects below; on appearance the gap falls exactly on justification and line breaking.
5. **A docx assembled by anything other than Word owes a structural pass before handover**, which no render performs: LibreOffice converts and rasterizes documents Word refuses to open outright. See "Structural validity" below for the check.

The profile in step 3 has to be fresh per invocation rather than merely non-default: concurrent invocations sharing one fail silently, a hardcoded path as surely as the default.

## Measured defects

- **`officer` does not resolve style inheritance.** Reading justification from `docx_summary()` alone can report the opposite of the truth, which is worse than reporting nothing.
- **LibreOffice diverges from Word precisely on justification.** Word's line breaking is undocumented, so a justified paragraph can wrap different words on different lines between the two. Gross breakage is visible in the render, a line-break judgement is not transferable.
- **LibreOffice can inject characters that are not in the document.** Read an unexplained glyph in a rasterized page as a conversion artefact until the XML confirms it.
- **Pandoc emits a `w:pStyle` whether or not the reference doc defines the style.** The reference dangles, the renderer falls back to `Normal`, and nothing errors. `officer` reports such a paragraph with a `NA` style name, which is the signal to look for.
- **Pandoc writes the syntax highlighting styles itself**, `Source Code` and 31 `*Tok` character styles, from the highlighting theme rather than from the reference doc. Finding them in an output proves nothing about the template.
- **A table of contents rasterizes empty**, because headless conversion does not run Word's field update. Read a heading with nothing under it as a field waiting for Word, not as a missing table of contents.
- **Quarto emits a second `w:pPr` inside paragraphs it restyles**, one per figure and table caption, from its own filters. LibreOffice renders through it and Word opens it; do not chase it as a local defect.
- **Both readers return a reply as a standalone comment.** Word keeps threading outside `word/comments.xml`: `word/commentsExtended.xml` gives each reply a `w15:paraIdParent` pointing at the `w14:paraId` of the last paragraph of the comment it answers, the last one for comments of several paragraphs too. `officer::docx_comments()` and `pandoc --track-changes=all` both drop the parent. Thread through `commentsExtended.xml`, which the `/depouiller` skill's `scripts/squelette.py` does.
- **A reviewer's reference number belongs to the render they read.** A numeric citation style numbers references at render time, by order of first citation, so a "reference 8" in a comment resolves on the bibliography of the reviewed docx, never by counting citations in the source, which any later edit can reorder.

A caption sitting alone at the foot of a page is usually pagination, not a lost figure: an inline image taller than the remaining space moves whole to the next page. Confirm on the following page before reporting anything.

## Structural validity, which a render never tests

Word enforces parts of the OOXML content model that LibreOffice ignores, and it enforces them by refusing to open the file rather than by degrading it, with a dialog that points at nothing. A document that converts and rasterizes cleanly here can therefore be unopenable for its only reader.

The rule met in practice is that **the last block-level element of a `w:tc` must be a `w:p`**, `w:tbl` and `w:sdt` not counting, range markers such as `w:bookmarkEnd` being transparent to it. Word reports the breach as "an ambiguous cell mapping was encountered", in French "un mappage de cellule ambigu a été rencontré", and names the missing element: "`<p>` elements are required before each `</tc>`". The check costs one pass over `word/document.xml`:

```python
import zipfile, xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
r = ET.fromstring(zipfile.ZipFile(path).read("word/document.xml"))
bad = [
    tc
    for tc in r.iter(W + "tc")
    if [k for k in tc if k.tag in (W + "p", W + "tbl")][-1:] != []
    and [k for k in tc if k.tag in (W + "p", W + "tbl")][-1].tag != W + "p"
]
print(len(bad), "cell(s) not ending on w:p")
```

The shape that produces it is a table nested as the last thing in a cell: Quarto wraps every cross-referenced float in a one-cell table, and a `flextable` or a `gt` table arrives from knitr as a raw `{=openxml}` block ending on `</w:tbl>`. The fix belongs to whatever emits the raw block, an empty paragraph appended to its text; a Pandoc `Para` carrying no inline is dropped before the writer sees it, so it cannot be inserted at AST level.

Two neighbouring breaches are non-blocking, since Word opens both: a paragraph carrying two `w:pPr`, and a `w:pStyle` referring to a style the reference doc does not define.

## What nothing on this machine settles

Fidelity to Word itself. No installed tool renders a docx the way Word does, and the divergence is documented, active and version-dependent rather than a fixed set of known gaps; Pandoc's contribution guide holds its own maintainers to a Word pass.
Before a docx template or a docx output is declared finished, say plainly that a pass on a real Word install is owed, rather than presenting a LibreOffice render as the check.

## References

- Quarto Word templates: https://quarto.org/docs/output-formats/ms-word-templates.html
- LibreOffice command line parameters: https://help.libreoffice.org/latest/en-US/text/shared/guide/start_parameters.html
- `officer::docx_summary()`: https://davidgohel.github.io/officer/reference/docx_summary.html
