---
name: Personal prescription template (pro-ordo)
description: "~/admin/pro-ordo ordo.qmd: Quarto/Typst prescription letterhead, dual blank/filled mode driven by Typst `#let` params; design record in .claude/DESIGN.md (gitignored), open item is the print check and the missing service phone / MSSanté address"
metadata:
  type: project
---

Started 2026-08-20. Structure mirrors `~/admin/pro-cv`: root `.qmd`, one `{=typst}` block, `font-paths: assets/fonts`, `.gitignore` covering `/.quarto/`, `/.claude/`, `/*.pdf`. Not a git repo yet; initialising it is the user's call.

The full design record is `~/admin/pro-ordo/.claude/DESIGN.md`. Read it before touching the project; it is gitignored, so nothing else carries these decisions.

Three points that cost time to establish and should not be re-derived:

- Parameters are Typst `#let` bindings in a `PARAMS` section, deliberately not YAML front matter. See [[reference_quarto_meta_shortcode_typst]] for the measurement that rules YAML out.
- The strikeout bar prints only in filled mode and sits **below** the signature. Pre-printing it on the blank letterhead would cross the handwriting area. It is a `block(height: 1fr)` with `layout(size => line(...))`, verified working.
- `ordo.qmd` ships with every parameter empty and stays that way. Filling it puts patient health data on disk, so a filled render is a transient edit reverted after printing.

Open: the service phone and MSSanté address are unknown and their header lines are omitted while `phone`/`mssante` stay empty (no placeholder ships). The paper print check (legibility of dosages, pharmacy stamp room, 2.4 cm signature gap) is the user's step.
