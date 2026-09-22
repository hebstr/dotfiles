---
name: A top-level crossref in a document drops the extension format's crossref keys
description: "`crossref:` at the top of a document's front matter replaced the extension format's crossref (lost `title-delim`, captions \"Tableau 1:\"), although `quarto inspect` showed the keys merged; nesting it under the format keeps them"
metadata:
  type: reference
---

Measured 2026-09-18 on Quarto 1.10 with the `hebstr-doc` extension, whose `common:` format declares `crossref: { title-delim: "\\.", tbl-title: "Table", custom: [...] }`.

- A document front matter with a top-level `crossref: { tbl-title: "Tableau" }` rendered docx captions as "Tableau 1: …": the extension's `title-delim` was gone.
- `quarto inspect` on that same document reported `title-delim` merged in, so inspect is not proof of what the render uses.
- Moving the key under the format (`format: hebstr-doc-docx: crossref: tbl-title: "Tableau"`) kept the extension's delimiter: "Tableau 1. …".

Check a crossref override on the rendered caption text, never on `quarto inspect` alone.

See also [[project_quarto_custom_crossref_float]] and [[reference_quarto_file_outside_render_list]].
