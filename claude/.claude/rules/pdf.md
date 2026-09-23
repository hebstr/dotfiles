# PDF reading

On-demand reference for reading PDFs. Load before the first PDF read of a session, and whenever the choice of extraction path is decision-relevant.

## Toolchain

```
| Tool | Role | Source |
|---|---|---|
| `detect-pdf` | Classification (text vs scanned), per-page OCR routing, column map; its table map is no inventory (see the defects below) | `cargo install pdf-inspector` |
| `pdf2md` | PDF to Markdown: multi-column reading order, heading tiers, lists | same crate |
| `pdftotext` | Raw text extraction; `-layout` preserves spatial arrangement | poppler-utils |
| `pdfinfo` | Metadata: page count, `Creator`, `Producer` | poppler-utils |
| `pdftoppm` | Page to PNG at a chosen resolution, for the table pages of rule 6; a scanned page goes to the native `Read` tool as a PDF range (rule 5) | poppler-utils |
| `Read` (native) | Renders pages; the only path that sees figures and scans | harness |
```

The Rust binaries stay current through `sys-update cargo` (`cargo install-update -a`), poppler through `sys-update apt`. Neither needs a dedicated module.

## Routing

1. Always open with `detect-pdf <file> --analyze --json`. A single pass returns `pdf_type`, `pages_needing_ocr`, `ocr_reasons_by_page`, `pages_with_columns` and `pages_with_tables` in tens of milliseconds. It classifies the document; `pdfinfo` stays the only source for the page size, rotation and producer fields rule 4 consumes.
2. Targeted search inside a text-based PDF: `pdftotext <file> - | rg <pattern>`. Leave `-layout` off here; its padding inflates the output by about a third and buys nothing for a regex.
3. Sustained reading of a linear or multi-column document (article, report, book, thesis): `pdf2md <file> --raw`. This is the only path that restores reading order across columns. Its pipe tables are never a source: rule 6 governs every table. A question about what a document says on a topic is a search, then a read: locate the pages with rule 2, splitting its output on form feeds (`awk -v RS='\f'`) as rule 6 does, then read only those with `pdf2md <file> --raw --select-pages N`. Any number or verbatim quote is copied from the `pdftotext` output of the same page, `pdf2md` serving for the order only.
4. Slide deck, or any page whose spatial arrangement carries the meaning: `pdftotext -layout`, never `pdf2md`. The test is the union of two `pdfinfo` probes, and both halves are load-bearing: page width greater than height once `Page rot` is folded in, OR a `Creator` or `Producer` naming PowerPoint, Impress, Keynote or Google Slides. `$file` holds the path and the chain exits 0 on a deck; an unreadable `pdfinfo` exits 0 as well, since the safe failure is the one that keeps a possible deck out of `pdf2md`.

   ```
   read -r w h rot < <(pdfinfo "$file" | awk '/^Page size:/{w=$3; h=$5} /^Page rot:/{r=$3} END{if (w != "") print w, h, r+0}')
   [ -n "$w" ] || exit 0
   prod=$(pdfinfo "$file" | awk '/^(Creator|Producer):/{sub(/^[^:]*:[[:space:]]*/, ""); print}' | tr '\n' ' ')
   awk -v w="$w" -v h="$h" -v r="$rot" 'BEGIN{if (r==90 || r==270) {t=w; w=h; h=t} exit !(w>h)}' \
     || printf '%s' "$prod" | rg -qi 'powerpoint|impress|keynote|slides'
   ```

   Neither half suffices alone. A deck exported through Chrome reports `Skia/PDF` and one printed from PowerPoint reports `Microsoft: Print To PDF`, so the producer test alone misses both; portrait PowerPoint decks exist, so the orientation test alone misses those. On the 154-file `~/Documents` corpus the union flags 55 documents: mostly decks, the rest landscape figures, posters and forms. Bias toward flagging: a wrongly flagged document only loses reading-order reflow, while a missed deck gets its data scrambled into a table that looks authoritative.
5. Pages whose `ocr_reasons_by_page` entry reads `scanned`, or any need to see a figure: native `Read` restricted to that page range. The two other reasons, `suspected_garbled_text` and `vector_text`, leave a text layer in place, so extract the page with `pdftotext` first and render only when what comes back is unusable or visibly incomplete.
6. Any value, label or header taken from a table: read it with `pdftotext -layout -f N -l N` on the table's own pages, never from a `pdf2md` pipe table. Render those pages when the table carries exponents or special glyphs (`≤`, `±`), a header spanning several levels, or sits on a rotated page: `pdftoppm -r 110 -png -f N -l N`, 220 dpi for a dense grid, then the native `Read` tool on the PNG; the image wins over `-layout`. Locate the pages by the caption, with `$file` holding the path and `$n` the table number (`3`, `IV`); the command prints candidate pages, the caption's page among them, and a caption set below a multi-page table names only its last page, so walk back from it on the rendered pages. Neither `pages_with_tables` nor the `<!-- Page N -->` markers of `pdf2md --pages` locate a table, and a pipe table in `pdf2md` output is no evidence that the page holds one.

   ```
   pdftotext "$file" - | awk -v RS='\f' -v n="$n" '$0 ~ "(^|\n)[ \t]*(Table|TABLE|Tableau|TABLEAU)[ .]+" n "([^0-9IVX]|$)" {printf "%d ", NR}'
   ```

## Measured defects of pdf2md

Established with pdf-inspector 1.15.0 on a 25-document corpus from this machine, 2026-08-20, then with 1.24.0 on 38 tables from 16 Zotero articles, 2026-09-23. Each bullet keeps one headline figure; `~/dotfiles/_meta/notes/pdf-inspector-reco.md` is the source of every figure, with the protocol, the full breakdown and the upstream fixes that call for a re-measurement, and is updated before this section.

- **Fabricated tables.** The heuristic alignment detector fires on pages that hold no table and emits a Markdown table which scrambles the value-to-label pairing (a count separated from the thing it counts). Measured first on slides, then in articles: 21 pages without a table in 11 of the 16 articles, pdfTeX included, came out as tables built from two-column prose, title pages, figure labels or code listings. A Markdown table reads as structured data, so the corruption carries false authority and passes unnoticed. No CLI flag or library option disables the heuristic. Rules 4 and 6 above exist for this reason.
- **Unfaithful tables in articles.** Of 38 real tables, 5 came out faithful, 25 altered and 8 not detected at all; 47 % of cells were wrong, against 9 % unrecoverable with `pdftotext -layout`. No producer is safe, pdfTeX included. Rows merge when a cell wraps or a group row has no value, values slide into the next column when a cell is empty, exponents leave their cell (`2.3 · 10` with `<sup>19</sup>` on a later line), and nearby prose and captions get glued into cells.
- **Page markers.** `--pages` omits markers and files up to twelve pages under a single `<!-- Page N -->`, so a marker does not locate a page.
- **`pages_with_tables` is not a table inventory.** It missed at least one page of 6 of the 38 tables, listed pages of plain text and figures, and runs only part of the detectors `pdf2md` runs, so it disagrees with what `pdf2md` emits.
- **Hyphenation.** 298 words left split against 12 for `pdftotext` on the 16 articles, re-measured on 1.24.0, despite the feature being documented upstream. `déter- minations` defeats any text search on the word.
- **Math-font punctuation.** A number typeset in a TeX math font can lose its punctuation in running prose: `0.9` comes out as `0*:* 9` and `2,000` as `2*;*000` in one pdfTeX article of the 16, where `pdftotext` decodes both. Elsewhere the emphasis markup only wraps intact punctuation (`28*.*4`).
- **No token gain.** Output measures 1.01x plain `pdftotext`. Choosing `pdf2md` to save context is unfounded; choose it for reading order.

## Sampling caveat

`detect-pdf` samples 8 pages by default, so `pages_needing_ocr` is drawn from that sample and is a routing signal, never an inventory: a 544-page book is judged on 8 inspected pages.

## OCR gap

This machine has no OCR. The default `pdf-inspector` build ships none, and its `ocr` feature requires PDFium and ONNX Runtime installed separately. A genuinely scanned page still goes to the native `Read` tool, page by page. `pdf-inspector` improves that case on one point: it names which pages are concerned instead of leaving it to guesswork.
