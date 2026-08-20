# PDF reading

On-demand reference for reading PDFs. Load before the first PDF read of a session, and whenever the choice of extraction path is decision-relevant.

## Toolchain

```
| Tool | Role | Source |
|---|---|---|
| `detect-pdf` | Classification (text vs scanned), per-page OCR routing, table and column maps | `cargo install pdf-inspector` |
| `pdf2md` | PDF to Markdown: multi-column reading order, heading tiers, lists | same crate |
| `pdftotext` | Raw text extraction; `-layout` preserves spatial arrangement | poppler-utils |
| `pdfinfo` | Metadata: page count, `Creator`, `Producer` | poppler-utils |
| `pdftoppm` | Page to PNG, to feed the native `Read` tool on a scanned page | poppler-utils |
| `Read` (native) | Renders pages; the only path that sees figures and scans | harness |
```

The Rust binaries stay current through `sys-update cargo` (`cargo install-update -a`), poppler through `sys-update apt`. Neither needs a dedicated module.

## Routing

1. Always open with `detect-pdf <file> --analyze --json`. A single pass returns `pdf_type`, `pages_needing_ocr`, `ocr_reasons_by_page`, `pages_with_columns` and `pages_with_tables` in tens of milliseconds. It classifies the document; `pdfinfo` stays the only source for the page size, rotation and producer fields rule 4 consumes.
2. Targeted search inside a text-based PDF: `pdftotext <file> - | rg <pattern>`. Leave `-layout` off here; its padding inflates the output by about a third and buys nothing for a regex.
3. Sustained reading of a linear or multi-column document (article, report, book, thesis): `pdf2md <file> --raw`. This is the only path that restores reading order across columns.
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

## Measured defects of pdf2md

Established on a 25-document corpus from this machine, 2026-08-20. Evidence and protocol in `~/dotfiles/_meta/notes/pdf-inspector-reco.md`.

- **Fabricated tables on slides.** The heuristic alignment detector fires on slides that hold no table and emits a Markdown table which scrambles the value-to-label pairing (a count separated from the thing it counts). A Markdown table reads as structured data, so the corruption carries false authority and passes unnoticed. No CLI flag disables the heuristic. Rule 4 above exists for this reason alone.
- **Hyphenation.** 242 words left split against 11 for `pdftotext` on the same corpus, despite the feature being documented upstream. `déter- minations` defeats any text search on the word.
- **No token gain.** Output measures 1.01x plain `pdftotext`. Choosing `pdf2md` to save context is unfounded; choose it for reading order.

## Sampling caveat

`detect-pdf` samples 8 pages by default, so `pages_needing_ocr` is drawn from that sample and is a routing signal, never an inventory: a 544-page book is judged on 8 inspected pages.

## OCR gap

This machine has no OCR. The default `pdf-inspector` build ships none, and its `ocr` feature requires PDFium and ONNX Runtime installed separately. A genuinely scanned page still goes to the native `Read` tool, page by page. `pdf-inspector` improves that case on one point: it names which pages are concerned instead of leaving it to guesswork.
