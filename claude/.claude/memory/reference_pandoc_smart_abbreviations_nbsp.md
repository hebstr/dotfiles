---
name: Pandoc smart typography turns the space after an abbreviation into a non-breaking one
description: With `smart` on, Pandoc replaces the space after known abbreviations ("et al.", "e.g.", "vs.") with U+00A0; an empty file passed as `abbreviations:` in a Quarto format disables it without touching quotes or dashes
metadata:
  type: reference
---

Measured 2026-09-18 on Quarto 1.10 (bundled Pandoc 3.10), docx output, while copying a Word thesis into a `.qmd` character for character.

- `Mackay et al. ; 7.` rendered as `Mackay et al. ; 7.`: Pandoc's markdown reader, under the `smart` extension, applies its built-in abbreviation list. Seven "et al." in one document were altered this way.
- Fix: `abbreviations: abbreviations.txt` under the Quarto format, pointing at an empty file. Verified on a probe that spaces then stay regular, while `smart` still renders `\'` as a straight apostrophe, `'` as a curly one and `---` as an em dash. Do not point it at `/dev/null` if the project may render on Windows.
- Related trap in the same round trip: `pandoc -t markdown` writes a `LineBreak` at the end of a `Strong` as `**label:\**`, which reads back with literal asterisks. Move the trailing `LineBreak`/`Space` out of the `Strong` in the AST before writing.

Worked example: `md-nesrine`, `.claude/DESIGN-TEMPLATE-MANUSCRIT.md`.
