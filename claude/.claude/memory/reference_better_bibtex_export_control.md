---
name: Better BibTeX export control
description: What can and cannot be controlled in a Better BibTeX export (Better CSL JSON and friends): the seven honoured prefs, skipFields being flat, the postscript signature, no formatting pref, and the local API refusing translator names
metadata:
  type: reference
---

Measured 2026-09-28 in the source of Better BibTeX 9.0.64 on Zotero 10.0.3, by unzipping the `.xpi` from `~/.zotero/zotero/*/extensions/` and reading `content/better-bibtex.js`. The installed translators live in `~/Zotero/translators/`, whose headers give priorities and display options.

**A Better BibTeX translator honours only a fixed subset of preferences, declared as a map in the bundle.** Better CSL JSON and Better CSL YAML honour seven: `automaticTags`, `baseAttachmentPath`, `cache`, `journalAbbreviation`, `parseParticles`, `postscript`, `skipFields`. Better BibLaTeX and Better BibTeX honour a much longer list (`strings`, `verbatimFields`, `separatorNames`, `skipWords`, …). Anything outside a translator's list does not reach it, so there is no point setting it.

**`skipFields` is a single flat list with no notion of item type.** It is honoured by the CSL translators, so it is the only declarative way to drop fields from a CSL-JSON export. Not established: whether it takes CSL variable names (`abstract`) or Zotero field names (`abstractNote`); the application logic is in the bundle, not in the translator file. Settle it by setting the pref, re-exporting and running `jq 'keys'`.

**`postscript` is JavaScript run once per entry, and it is the only way to branch on type.** Signature built by the `postscript(kind, main, guard)` factory:

```
new Function("target", "source", "Translator", "Zotero", "extra", body)
  reference === entry === target   the output object (the CSL entry on the CSL route)
  item === zotero === source       the Zotero item
  Translator.BetterCSL             true on Better CSL JSON / YAML
  Translator.BetterBibLaTeX, .BetterBibTeX, .BetterTeX
```

`reference.type` carries the CSL type, so `delete reference[field]` under a `switch` on it gives per-type field selection. Returning an object sets `{ cache, write }`. The preference pane warns separately about postscripts using `Translator.options.exportPath`, which interacts with the export cache. A postscript lives in a Zotero preference, so it is machine-local and unversioned: on a repo whose point is reproducibility, prefer `skipFields` unless the per-type branch is genuinely needed.

**There is no formatting preference.** Better CSL JSON writes a valid JSON array with one entry per line (5 lines for 3 entries); `jq .` on the same file gives 130. Pandoc renders both identically, whitespace being free in JSON, so indentation is a diff-readability question only, and the auto-export will always rewrite the compact form. A git `clean` filter is the way to get an indented blob while leaving the working file alone.

**Zotero's local API cannot emit a Better BibTeX format.** `format=` rejects the translator UUID, its label and a slug alike with `400 Invalid 'format' value`, and only its own fixed list answers (`bibtex`, `csljson`, …); the error does not enumerate valid values and `include=csljson,bibtex` opens no other door. Only the Better BibTeX JSON-RPC's `item.export` produces the exact production artifact, which is moot once an auto-export writes that artifact to a file on disk.

Related: [[reference_citeproc_bib_vs_csl]] for why a CSL route is chosen over `.bib` in the first place, [[project_zotero_agent_access]] for the read-access decision and the JSON-RPC rule.

Open at the time of writing: a `/workflow:reco` pass on the clean way to restrict emitted fields, prompt in `eds-prise/.claude/PROMPT-CSL.md`. Read its outcome before treating the `skipFields` question as settled.
