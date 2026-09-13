---
name: Word embedded fonts are blocked on the reading machines
description: The Word installs that receive the user's deliverables refuse OOXML-embedded fonts (corporate policy, not Protected View), while w:altName is honoured; design Word outputs around the fallback list, never around embedding
metadata:
  type: reference
---

Measured 2026-09-11 on a real Word install that receives the user's deliverables.

A `.docx` carrying correctly embedded faces renders in the **fallback** font, not the embedded one.
Everything verifiable on the file was conforming: `fsType = 0x0000` ("Installable Embedding", no licence restriction), de-obfuscation byte-for-byte per ECMA-376 over the whole file with no subsetting, `<w:embedTrueTypeFonts/>` present in `word/settings.xml`, the four `w:embedRegular`/`Bold`/`Italic`/`BoldItalic` entries with valid relationships, and LibreOffice uses those faces.
Leaving Protected View ("Activer la modification") changes nothing, which rules out the usual explanation and points at a managed-estate policy such as Windows "Block untrusted fonts".

**`w:altName` is honoured on the same machine**: with neither Luciole nor Aptos installed, a table declaring `Aptos, Calibri` came out in Calibri, the second name of the list.

How to apply: for a Word deliverable, treat font embedding as decorative and make the **ordered `w:altName` list** carry the intent. When the font matters for accessibility rather than for style (Luciole and the like), the robust route is installing it on the reading machines, not a file-side trick. Do not spend time debugging an embedding that looks correct on the writer's side.

Applied in `hebstr` on 2026-09-13: native Word tables (`theme_ft()`) default to Aptos with `w:altName` Calibri instead of the session font, and `easy_out()` embeds no Office fallback family. Luciole stays on every other output (HTML, SVG, PNG, figures inside a docx). Design note: `R-hebstr/.claude/DOCX-FONTS.md`.

Related: [[reference_quarto_extension_format_knitr]] for the font plumbing of `hebstr-doc`, [[project_md_nesrine_render_pitfalls]] for the docx render path.
