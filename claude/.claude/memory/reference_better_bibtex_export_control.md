---
name: Better BibTeX export control
description: What can and cannot be controlled in a Better BibTeX export (Better CSL JSON and friends): the seven honoured prefs, how skipFields really matches (per-type, CSL names, lowercase-only), per-directory override files that put the config in the repo, the postscript signature, no formatting pref, and the local API refusing translator names
metadata:
  type: reference
---

Measured 2026-09-28 in the source of Better BibTeX 9.0.64 on Zotero 10.0.3, by unzipping the `.xpi` from `~/.zotero/zotero/*/extensions/` and reading `content/better-bibtex.js`. The installed translators live in `~/Zotero/translators/`, whose headers give priorities and display options.

**A Better BibTeX translator honours only a fixed subset of preferences, declared as a map in the bundle.** Better CSL JSON and Better CSL YAML honour seven: `automaticTags`, `baseAttachmentPath`, `cache`, `journalAbbreviation`, `parseParticles`, `postscript`, `skipFields`. Better BibLaTeX and Better BibTeX honour a much longer list (`strings`, `verbatimFields`, `separatorNames`, `skipWords`, …). Anything outside a translator's list does not reach it, so there is no point setting it.

**`skipFields` is comma-separated, per-type capable, and matches CSL variable names.** Settled 2026-09-28 by replaying the pattern builder of `translators/lib/translator.ts` on node, verified identical in the installed 9.0.64 bundle and upstream. On the CSL route `translators/csl/csl.ts` tests each output key against `` `csl.${csl.type}.${field}` ``, so the names are CSL variables (`abstract`), never Zotero fields (`abstractNote`), and the type is the CSL type (`article-journal`), never the Zotero one. Three behaviours the docs do not state:

```
abstract                       -> ^((csl[.][-a-z]+[.]abstract))$          every type
article-journal.abstract       -> ^((csl[.]article-journal[.]abstract))$  that type only
csl.article-journal.abstract   -> ^(([.]article-journal[.]abstract))$     matches nothing (broken branch)
issn / ISSN                    -> ^((csl[.][-a-z]+[.]issn))$              matches nothing
```

The whole pref is lowercased and the regex carries no `i` flag, so CSL variables spelled in capitals (`ISSN`, `DOI`, `URL`, `ISBN`, `PMID`) are unreachable and need a postscript. A name matching nothing is inert, without warning. The `skipFields` pass runs *after* the postscript. A 2017 maintainer reply saying `skipFields` is Bib(La)TeX-only (issue 641) is obsolete.

**`postscript` is JavaScript run once per entry, and it is the only way to branch on type.** Signature built by the `postscript(kind, main, guard)` factory:

```
new Function("target", "source", "Translator", "Zotero", "extra", body)
  reference === entry === target   the output object (the CSL entry on the CSL route)
  item === zotero === source       the Zotero item
  Translator.BetterCSL             true on Better CSL JSON / YAML
  Translator.BetterBibLaTeX, .BetterBibTeX, .BetterTeX
```

`reference.type` carries the CSL type, so `delete reference[field]` under a `switch` on it gives per-type field selection, but the idiom in the docs and in BBT's own test corpus is `csl.type` or `item.itemType`. Returning an object sets `{ cache, write }`. The preference pane warns separately about postscripts using `Translator.options.exportPath`, which interacts with the export cache.

**The config does not have to be machine-local: `preferencesOverride` puts it in the export directory, hence in the repo.** Set the hidden pref `extensions.zotero.translators.better-bibtex.preferencesOverride` to a filename, drop that file beside the export target holding `{"override": {"preferences": {"skipFields": "abstract, source"}}}`, and it wins. Only the hidden pref stays per-machine. Any preference of the bundle's `defaults` can go in that file, `postscript` included, so a postscript needs no second file and no `postscriptOverride`. Two traps: BBT first probes a file named after the export target with the extension swapped for `.json` (so an export to `references.json` probes `references.json` itself, harmlessly, then falls through), so do not name the override after the target; and the override requires `exportDir`, which auto-exports do set (`exportItemsByWorker`).

**The export cache is not a trap.** `postscript` and `skipFields` are in Better CSL JSON's `affects` map, so changing either drops that translator's cache and re-queues the auto-exports that depend on it, with no manual purge. The export preference pane says so ("Making any change here will drop your entire export cache") and `content/translators.ts` does it on `preference-changed`. An override file disables caching for that export outright.

**There is no formatting preference.** Better CSL JSON writes a valid JSON array with one entry per line (5 lines for 3 entries); `jq .` on the same file gives 130. Pandoc renders both identically, whitespace being free in JSON, so indentation is a diff-readability question only, and the auto-export will always rewrite the compact form. A git `clean` filter is the way to get an indented blob while leaving the working file alone.

**Zotero's local API cannot emit a Better BibTeX format.** `format=` rejects the translator UUID, its label and a slug alike with `400 Invalid 'format' value`, and only its own fixed list answers (`bibtex`, `csljson`, …); the error does not enumerate valid values and `include=csljson,bibtex` opens no other door. Only the Better BibTeX JSON-RPC's `item.export` produces the exact production artifact, which is moot once an auto-export writes that artifact to a file on disk.

Related: [[reference_citeproc_bib_vs_csl]] for why a CSL route is chosen over `.bib` in the first place, [[project_zotero_agent_access]] for the read-access decision and the JSON-RPC rule.

The `/workflow:reco` pass on restricting emitted fields ran 2026-09-28 and is closed; its outcome is folded in above, and the project-side decision (which fields eds-prise drops and why) is in that repo's `.claude/DESIGN-BIB.md`, section "L'élagage des champs exportés".
