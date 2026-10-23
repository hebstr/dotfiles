---
name: collab-comments evaluation (eds-prise, 2026-10-23), gate run 2026-10-24
description: collab-comments adopted for eds-prise and its gate passed on 2026-10-24, carrying a reviewer's Word comments back into a Quarto docx: 6 of 24 points carry, the block shapes that kill an anchor whatever the selection, Word's acceptance, the silent skip on stderr
metadata:
  type: project
---

`MikeLydeamore/collab-comments` (Quarto filter) plus `MichaelLydeamore.collab-comments` (Positron, OpenVSX 1.1.0) was evaluated on 2026-10-23 for `eds-prise`: carrying the 24 comment points of `docs/review/2026-09-29_prise_review-manuscrit.docx` back into the docx render of `docs/csi/csi.qmd`, so the reviewer receives an updated Word in which her remarks stay answerable.

**Adopted, both halves.** Full reading, arithmetic, revert path and trial gate in `~/dotfiles/_meta/notes/collab-comments-reco.md`. Four facts worth having before touching it:

- The decision rests on durability, not on coverage: a `.comments/collab-comments.json` entry is re-applied at every render, where a manual edit of a rendered Word dies at the next one. **Coverage measured at the gate of 2026-10-24: 6 of the 24 points carry**, the import having written 13 entries of which the render skips 7. The reading's 13/10/1 arithmetic described the import alone.
- **What kills an anchor is the block, not the span**, so resizing a selection never saves it: `rewrite_block()` refuses a `Para` carrying a citation, any list item, and a wholly bold paragraph. A `Para` of plain prose and a `Header` are what survive. Any hand-written entry has to clear block shape as well as uniqueness and single-line containment.
- The editor half is installed for its re-anchoring (`onDidChangeTextDocument` rewrites every stored range as the source moves), not for its import. Under a document still being rewritten by hand, a repaired store rots silently otherwise.
- A render that loses comments **exits 0**; the only trace is `[collab-comments] ...: skipped Word comment <id>: <reason>` on stderr. Read it at every delivery render.
- The export is stricter than the import: the import disambiguates several occurrences by stored context, the export demands exactly one occurrence in the rendered document and rewrites only a top-level `Para`, `Plain` or `Header`.

**Word accepts the package, measured at the gate**: Word 16.0.20430 on `ju-TP2` opens it with no repair prompt, updates the table-of-contents field and anchors every comment on its exact stored span, mid-word starts included. Pandoc writes no `w:initials`, so a re-emitted balloon reads `Commented [1]:` where one the reviewer wrote reads `Commented [GV1]:`; her name stays in `w:author`.

Revisit trigger: an upstream docx branch falling back to the stored `contextBefore` / `contextAfter` instead of requiring a literal single-line source slice would retire the hand-written entries, and an export writing `word/commentsExtended.xml` would restore threading. The trigger that would have overturned the adoption, a real Word refusing the package, is spent.

**Why**: two earlier verdicts exist and neither answers this question, so a pass unaware of them would redo both. The md-nesrine bench of 2026-09-07 (`~/Documents/services/md-nesrine/.claude/archive/NOTE-COLLAB-COMMENTS.md`, still the reference on the three filter modes and the store schema) went dormant at delivery; the rejection of 2026-09-14 in `eds-prise/.claude/DESIGN-INDEX.md` turned the tool down for the register pass only.

**How to apply**: do not re-evaluate the tool, and never re-propose the hand-written OOXML injection script, measured and set aside on 2026-10-23. A straight-apostrophe linter was considered and rejected: the filter's own stderr reports every broken anchor completely, where a linter would be a proxy with false positives on every apostrophe no comment anchors to. Store placement, the YAML of `csi.qmd`, the gitignore line and each re-anchored span are a `/design` pass.

Related: [[reference_quarto_custom_format_render_target]], [[reference_quarto_extension_install_resolution]], [[reference_positron_extension_registries]].
