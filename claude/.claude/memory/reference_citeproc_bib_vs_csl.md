---
name: citeproc title casing differs between .bib and CSL bibliographies
description: Measured asymmetry in pandoc citeproc between a BibTeX/BibLaTeX bibliography (titles are recased at read time, so proper nouns need `langid` or braces) and a CSL-JSON/YAML one (no case transformation at all), plus the YAML boolean hazard on single-letter initials
metadata:
  type: reference
---

Measured on pandoc 3.10 with a Vancouver CSL (which calls for sentence case), 2026-09-17/18.

**From a `.bib`, citeproc recases titles at read time.** Pandoc's MANUAL documents the mechanism ("citeproc stores titles internally in sentence case, and converts to title case in styles that require it"), so an unprotected proper noun in a sentence-case French title is lowercased: `title = {... en France}` prints "en france". Two fixes, both documented in the manual's "Capitalization in titles": brace the word (`{France}`), or set `langid = {french}` on the entry. **The legacy `language` field is ignored by pandoc's biblatex reader; only `langid` maps to CSL `language`.**

**From a CSL-JSON (or YAML) bibliography, citeproc applies no case transformation whatsoever.** A title in Title Case prints in Title Case, one in sentence case prints unchanged, under the same style that lowercases from a `.bib`. So the defect class is structurally impossible on the CSL route, and no `langid`, braces or per-entry annotation are needed. The cost is symmetric: an English title stored in Title Case will not be corrected to sentence case either.

**`pandoc -t csljson` on a `.bib` fossilizes the casing rather than fixing it**: the reader applies the transformation before the writer runs, so the already-lowercased string lands in the JSON. Migrating a hand-maintained `.bib` to CSL therefore means re-exporting from the reference manager, never converting the file.

**`.bib` defaults to BibLaTeX, not BibTeX.** The manual's table maps `BibLaTeX → .bib`, `BibTeX → .bibtex`, `CSL JSON → .json`, `CSL YAML → .yaml`, `RIS → .ris`, and "use the extension `.bibtex` to force interpretation as BibTeX". On a file written with the common subset the two parsers produce byte-identical CSL-JSON, so the distinction only shows up on BibLaTeX-only fields.

**CSL-YAML silently drops a single-letter initial `N` or `Y` when unquoted** (YAML 1.1 boolean coercion): `given: N` yields "Bonnevialle" with no warning, `given: 'N'` yields "Bonnevialle N". Fatal for biomedical bibliographies that reduce given names to initials, so prefer CSL-JSON over CSL-YAML. Whether Better BibTeX's exporter quotes such values is unverified.

Entry-type mapping worth knowing: `@misc` produces an **empty** CSL type (styles fall through to a generic branch by luck), `@online` gives `webpage`, and on `@report` the biblatex `institution` maps to CSL `publisher` and `type` to `genre`.

Typst reads only Hayagriva `.yaml` and BibLaTeX `.bib`, never CSL-JSON, so a project that wants Typst-native citation handling cannot move its bibliography to CSL. See [[user_quarto_typst_only]] and [[reference_quarto_custom_format_render_target]].

Zotero exports BibTeX and CSL JSON both ways but BibLaTeX only as an export. Since Zotero 8 citation keys live in a native, always-pinned, syncing field, so the old "pin your key in the Extra field" advice is obsolete; changing a Better BibTeX key formula does not regenerate existing keys without an explicit Refresh.
