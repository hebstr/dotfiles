---
name: Personal prescription template (pro-ordo)
description: "~/admin/pro-ordo ordo.qmd: Quarto/Typst prescription letterhead, dual blank/filled mode driven by Typst `#let` params; design record in .claude/DESIGN.md, local unversioned sandbox, open item is the paper print check"
metadata:
  type: project
---

Started 2026-08-20. Structure mirrors `~/admin/pro-cv`: root `.qmd`, one `{=typst}` block, `font-paths: assets/fonts`, `.gitignore` covering `/.quarto/`, `/.claude/`, `/*.pdf`. Not a git repo yet; initialising it is the user's call.

The full design record is `~/admin/pro-ordo/.claude/DESIGN.md`. Read it before touching the project; the project is not under git, so nothing else carries these decisions.

Three points that cost time to establish and should not be re-derived:

- Parameters are Typst `#let` bindings in a `PARAMS` section, deliberately not YAML front matter. See [[reference_quarto_meta_shortcode_typst]] for the measurement that rules YAML out.
- The strikeout bar prints only in filled mode and sits **below** the signature. Pre-printing it on the blank letterhead would cross the handwriting area. It is a `block(height: 1fr)` with `layout(size => line(...))`, verified working.
- `ordo.qmd` carries filled trial values in every parameter, header and patient alike. The project is a local, unversioned sandbox (user, 2026-09-22), so filled parameters are not a finding.

The header parameters are `phone` and `email` (formerly `mssante`); a header line is omitted while its parameter is empty. Open: the paper print check (legibility of dosages, pharmacy stamp room, 2.4 cm signature gap) is the user's step.
