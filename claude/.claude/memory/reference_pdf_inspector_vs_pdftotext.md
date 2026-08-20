---
name: pdf-inspector complements pdftotext, never replaces it
description: Measured 2026-08-20 on a 25-doc corpus - pdf2md wins reading order on multi-column PDFs but fabricates tables on slide decks and breaks hyphenation, with no token gain; routing rule lives in rules/pdf.md, do not redo the benchmark
metadata:
  type: reference
---
`pdf-inspector` (Firecrawl, MIT, Rust) was evaluated on 2026-08-20 against poppler and installed via `cargo install pdf-inspector` (binaries `detect-pdf`, `pdf2md`, `dump_ops`). The operational routing rule lives in `~/.claude/rules/pdf.md` and is loaded through the `## PDF reading` trigger in `~/.claude/CLAUDE.md`. The full protocol, tables and raw numbers are in `~/dotfiles/_meta/notes/pdf-inspector-reco.md`, with the install trace in `pdf-inspector-install.md` beside it.

**What was measured** (25 PDFs drawn at random from `~/Documents`, 1 to 544 pages):

1. **No token gain.** `pdf2md` output is 1.01x plain `pdftotext` and 0.76x `pdftotext -layout`. The apparent 24 % saving is only the space padding of `-layout`. Never justify `pdf2md` on context cost.
2. **Reading order is the real win.** On multi-column pages both `pdftotext` modes interleave columns and yield a text that looks plausible while its logical sequence is wrong; `pdf2md` is monotonic. 20 of the 25 documents contain multi-column pages, so this is the common case, not an edge case.
3. **Fabricated tables on slide decks.** The heuristic alignment detector fires on slides holding no table and emits a Markdown table that severs values from their labels. No CLI flag disables it. This is why the rule forces `pdftotext -layout` whenever `pdfinfo` reports a PowerPoint-family `Producer`.
4. **Hyphenation regressed.** 242 words left split against 11 for `pdftotext`, despite the upstream feature claim.

**Why it still earns its place:** `detect-pdf` has no substitute. It classifies a 544-page book in 132 ms and isolates the single scanned cover page, where the previous heuristic (empty `pdftotext` output) classified the whole book as scanned and would have routed it to an OCR path that does not exist on this machine.

**How to apply:** trust `~/.claude/rules/pdf.md` for the routing and do not re-run this benchmark. If `pdf2md` output ever looks like a clean table on a slide, distrust it and re-extract with `pdftotext -layout`. No sys-update module is needed: `cargo install-update -a` already covers the binaries. OCR remains absent; that gap is independent of this decision and `ocrmypdf` plus `tesseract-ocr-fra` is the short path if it ever matters.
