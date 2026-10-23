---
name: collab-comments evaluation (eds-prise, 2026-10-23)
description: collab-comments adopted on 2026-10-23 to put a reviewer's Word comments back into a Quarto docx: the 13/10/1 arithmetic, each half's role, the silent skip on stderr, the one trial left
metadata:
  type: project
---

`MikeLydeamore/collab-comments` (Quarto filter) plus `MichaelLydeamore.collab-comments` (Positron, OpenVSX 1.1.0) was evaluated on 2026-10-23 for `eds-prise`: carrying the 24 comment points of `docs/review/2026-09-29_prise_review-manuscrit.docx` back into the docx render of `docs/csi/csi.qmd`, so the reviewer receives an updated Word in which her remarks stay answerable.

**Adopted, both halves.** Full reading, arithmetic, revert path and trial gate in `~/dotfiles/_meta/notes/collab-comments-reco.md`. Four facts worth having before touching it:

- The decision rests on durability, not on coverage: 13 of the 24 points carry mechanically, 10 need a store entry written by hand, and 1 (on the subtitle, which is metadata and never a body block) cannot be anchored at all. A `.comments/collab-comments.json` entry is re-applied at every render, where a manual edit of a rendered Word dies at the next one.
- The editor half is installed for its re-anchoring (`onDidChangeTextDocument` rewrites every stored range as the source moves), not for its import. Under a document still being rewritten by hand, a repaired store rots silently otherwise.
- A render that loses comments **exits 0**; the only trace is `[collab-comments] ...: skipped Word comment <id>: <reason>` on stderr. Read it at every delivery render.
- The export is stricter than the import: the import disambiguates several occurrences by stored context, the export demands exactly one occurrence in the rendered document and rewrites only a top-level `Para`, `Plain` or `Header`.

Revisit trigger: an upstream docx branch falling back to the stored `contextBefore` / `contextAfter` instead of requiring a literal single-line source slice would retire the ten hand-written entries, and an export writing `word/commentsExtended.xml` would restore threading. The adoption itself is overturned only by a real Word refusing the commented package, which is the one trial left.

**Why**: two earlier verdicts exist and neither answers this question, so a pass unaware of them would redo both. The md-nesrine bench of 2026-09-07 (`~/Documents/services/md-nesrine/.claude/archive/NOTE-COLLAB-COMMENTS.md`, still the reference on the three filter modes and the store schema) went dormant at delivery; the rejection of 2026-09-14 in `eds-prise/.claude/DESIGN-INDEX.md` turned the tool down for the register pass only.

**How to apply**: do not re-evaluate the tool, and never re-propose the hand-written OOXML injection script, measured and set aside on 2026-10-23. A straight-apostrophe linter was considered and rejected: the filter's own stderr reports every broken anchor completely, where a linter would be a proxy with false positives on every apostrophe no comment anchors to. Store placement, the YAML of `csi.qmd`, the gitignore line and each re-anchored span are a `/design` pass.

Related: [[reference_quarto_custom_format_render_target]], [[reference_quarto_extension_install_resolution]], [[reference_positron_extension_registries]].
