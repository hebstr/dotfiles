# collab-comments: carrying a reviewer's Word comments back into a Quarto docx

2026-10-23. Decision asked: can `docx-comments: true` put the 24 points of a reviewed `.docx` back into the render of `docs/csi/csi.qmd`, so the reviewer gets an up-to-date Word in which her remarks are still answerable?

Supersedes the dormant recommendation of `~/Documents/services/md-nesrine/.claude/archive/NOTE-COLLAB-COMMENTS.md` (bench of 2026-09-07) without replacing that note, which stays the reference on the three filter modes, the store schema and the bench protocol.
The rejection of 2026-09-14 in `eds-prise/.claude/DESIGN-INDEX.md`, section "La relecture externe du 2026-09-14 se dépouille dans un registre", stands for what it decided: the register pass, not the return trip.

## Restating the question

Three questions whose answers can diverge.

1. Does the docx round trip answer the delivery, and at what manual cost?
2. Does the one-directional typographic guard (a root `panache.toml` with `smart = false`) deserve a check of its own, now that a straight apostrophe typed later would break an anchor in silence?
3. What is the editor half worth here, beyond writing the store once?

Done means: the reviewer receives a re-rendered Word carrying her remarks in place, and every later render reproduces them without manual surgery.

Out of scope: the HTML export and the preview bridge (neither is asked for); store placement, the YAML of `csi.qmd`, the gitignore line and each hand-placed anchor (a `/design` pass, after this verdict); carrying her text edits back, which this tool never does and `/review-prose` already did at `c461e9c`.

## The tool

Forge, read 2026-10-23.

```
| Measure | Value |
| ------- | ----- |
| Repository | `MikeLydeamore/collab-comments`, MIT, not archived |
| Created / last push | 2025-10-29 / 2026-09-07 (`Fix old labelling`) |
| Non-bot contributors | 1 |
| Stars / watchers / open issues / milestones | 9 / 0 / 0 / 0 |
| Published releases | none; `releases/latest` returns 404 |
| Tags | `v1.1.0`, annotated |
| `v1.1.0` against `main` | `ahead_by` 0, `behind_by` 0, no files differ |
```

So `quarto add MikeLydeamore/collab-comments@v1.1.0` pins exactly today's `main`, and the pin buys nothing today and everything later: `quarto add` resolves to `main` otherwise, `@latest` included (memory `reference_quarto_extension_install_resolution`).

Registry, OpenVSX API on 2026-10-23: `MichaelLydeamore.collab-comments` 1.1.0, published 2026-09-07T07:21:51Z, 1331 downloads, `engines.vscode ^1.85.0`, `license` null in the registry metadata where the repository carries MIT. Note the publisher namespace is `MichaelLydeamore` while the forge owner is `MikeLydeamore`: the two install commands do not share a name.

The Quarto half installs as `_extensions/MikeLydeamore/collab-comments/`, `quarto add` nesting by owner, four files, 47.3 KB, `quarto-required: ">=1.4.0"`, and its `_extension.yml` declares `version: 0.1.0`, not 1.1.0.

The risk profile of the 2026-09-07 bench is unchanged: one author, no milestone, no published plan, a feature committed six weeks ago and silent since. What offsets it is unchanged too: the store is documented JSON, versionable, and nothing is captive.

## Protocol

Corpus: the real delivery, chosen before the tool was identified. `docs/review/2026-09-29_prise_review-manuscrit.docx`, 4.9 MB, 26 comments by one author of which 2 are replies, so 24 points; `docs/csi/csi.qmd`, 687 lines; the render `docs/csi/2026-10-03_prise_csi.docx`; the register `docs/review/2026-09-15_prise_review-notes.md`, 24 decisions.

The anchor arithmetic against that corpus was measured on 2026-10-23 before this pass and is recorded in `eds-prise/.claude/DESIGN-INDEX.md`. This pass does not re-measure it: it reads the implementation at `v1.1.0` and verifies the facts the arithmetic rests on.

Comparator: the incumbent, which is the `/review-comments` register plus a Word the reviewer re-reads stripped of her own remarks; and the hand-written OOXML injection script, measured and set aside on 2026-10-23.

Read at source: `_extensions/collab-comments/collab-comments.lua`, `src/wordComments.ts`, `src/quartoMapping.ts`, `src/anchors.ts`, `src/extension.ts`, `package.json`, `README.md`, the OpenVSX entry, and locally `/opt/quarto/share/pandoc/datadir/_format.lua`, quarto 1.10.19, pandoc 3.10.

## Results

### The filter's docx branch fires under `hebstr-doc-docx`: verified, not inferred

`Pandoc()` keys the branch on `quarto.doc.is_format('docx')`, and quarto's own `_format.lua` reduces that to `FORMAT == "docx"`, pandoc's writer name, with no pattern tolerance.
Probe rendered in the session scratchpad on a chunk-free document declaring `format: hebstr-doc-docx`, with the project's `_extensions/` copied beside it and a one-function filter of my own: `FORMAT=docx is_docx=true is_html=false`.
The md-nesrine bench had verified the HTML sibling; this is the docx one, on the same mechanism, and it closes the bound the brief asked to verify.

### Pandoc 3.10 writes real Word comment parts, and writes them flat

The filter emits the comment as a `comment-start` span carrying `id`, `author` and `date`, closed by a `comment-end` span.
Measured on the pandoc quarto bundles, which since 2026-09-29 is the machine's only pandoc: `word/comments.xml` with `w:id`, `w:author` and `w:date`, the part declared in `[Content_Types].xml` and related from `word/_rels/document.xml.rels`, and the body carrying the `commentRangeStart` / `commentRangeEnd` / `commentReference` triple.
No `word/commentsExtended.xml`, so no threading, which is what `rules/docx.md` already predicts of any writer that is not Word: each exported thread arrives as one read-only transcript.
One asymmetry met on the probe: a `comment-start` with no matching `comment-end` yields a `commentRangeStart` and no reference at all, so the comment is written and invisible. The filter always emits both markers, so it cannot happen here.

### 13 of 24 carry mechanically, 10 need a store entry written by hand, 1 cannot be anchored at all

The 13 and the 11 are the measurement of 2026-10-23, after the apostrophe normalisation of the source.
What this pass adds is the sort of the 11.

Ten are relocatable. `occurrences == 1` tests a string, never the reviewer's intent, so a stored `selectedText` may be trimmed to clear an inline R value or a line break, or extended to disambiguate a four-word selection, as long as it stays inside one source line and still points at the passage she was reading.

One is not. Comment 1 sits on the document subtitle, and the subtitle is metadata: probe on a document with `title` and `subtitle`, three blocks walked (two `Para`, one `Header`), neither of them the subtitle, `doc.meta.subtitle` present.
No store entry can anchor it, because the rewrite only ever touches blocks. It has to be carried outside the docx or re-aimed at the first paragraph of the body.

### The export is stricter than the import, so a comment can import cleanly and still be dropped

`mapRenderedSelection()` scores every occurrence of the selection in the source against 120 characters of context on each side, and refuses only an exact tie.
The filter's export has no context at all: `add_docx_comments()` counts occurrences over every rendered `Para`, `Plain` and `Header`, and drops anything that is not unique.
So the four short ambiguous spans ("n'est pas", "définition", "Annotation", "contre-indiquant") import without complaint and die at render.
The binding test for a delivery is the export's, never the import's, and a clean import reports nothing about what the reviewer will see.

### Only a top-level `Para`, `Plain` or `Header` can carry a comment

`rewrite_block()` returns the block untouched unless `block.t` is one of those three, and `add_docx_comments()` applies it to `doc.blocks` alone, with no recursion.
Ambiguity counting does the opposite: `rendered_block_texts()` walks into every container, table cells included.
A paragraph inside a Div is therefore counted against uniqueness and can never carry a comment itself. Exposure in `csi.qmd`: three Divs, two one-line `callout-warning` bodies and `#refs`.
The other half of the same constraint, `inline_text()` refusing a block holding any inline that is not `Str`, `Space`, `SoftBreak` or `LineBreak`, is still unmeasured against the 13; 38 of the 687 lines carry bold, a link, a citation, a crossref or an inline R value.

### A skipped comment leaves one stderr line and a render that exits 0

Every failure path calls `warning()`, which writes `[collab-comments] <input>:<line>: skipped Word comment <id>: <reason>` with six distinct reasons: stale or non-literal selection, selection spanning source lines, absent from supported rendered blocks, ambiguous in the rendered document, overlapping rendered selection, present only in an unsupported structure.
Nothing else marks it. The docx is produced, the exit code is 0, the comment is simply not there.
The HTML export's `UNPLACED COMMENTS` rubric has no docx equivalent.

### The store is the only artefact of this route that survives a re-render

This is what decides the question, and it is not a feature of the tool so much as a property of where the comments live.
A comment pasted into a rendered Word by hand dies at the next `quarto render`. `.comments/collab-comments.json` is re-read at every render and re-applied.
`exported_comments()` walks up from the input's directory looking for `.comments/collab-comments.json`, then matches `comment.filePath` against the input path relative to the directory holding the store, so a single store at the project root serves `docs/csi/csi.qmd` under exactly that path.
Limits read at source: 20 MiB per file the filter reads, 50 MiB for the imported docx, 20 MiB for the pandoc JSON, 500 comments, 32 000 characters per body and per selection. The corpus sits two orders of magnitude inside all of them.
A malformed store is rejected whole, never in part.

### The editor half earns its place by re-anchoring, not by the import

`onDidChangeTextDocument` transforms every stored range on each edit, falls back to `locateAnchor()` on the stored context when the selection itself was touched, and records the edit as a tracked change on the comment; a file watcher on `.comments/collab-comments.json` reloads the store when something else writes it.
The user rewrites `csi.qmd` section by section, so a store written once and left alone rots: a line that moves makes `selected_source_text()` return "stale or not literal source text", and the comment disappears from the next delivery with one stderr line.
The import writes 13 entries once; the re-anchoring keeps all 24 alive for as long as the document keeps moving. The second is the larger service.
Activation is `onStartupFinished`, so the extension loads in every Positron window; `handleDocumentChange` returns at once for a file no comment names, so the cost outside this project is nil.

### The straight-apostrophe check would be a proxy for a test the filter already performs completely

The filter names, at every render, exactly the comments that failed, by id and by reason.
A linter on straight apostrophes would fire on every one of them in prose no comment anchors to, and would stay silent on the three other ways an anchor dies: a line that moved, a span that grew past a line break, a span that drifted onto an inline value.
There is nothing to build. What the delivery owes is reading the filter's stderr and comparing the skip count against the expected one.

### Footprint: no Claude Code surface, a small project one

The candidate touches no harness surface. It writes nothing under `~/.claude`, claims no hook event against the fourteen hooks on seven events already in use, ships no MCP server whose tool descriptions would be loaded in every session, and adds no skill, command or agent. There is nothing to weigh on that axis.

What it does write:

```
| Half | Writes | Managed how |
| ---- | ------ | ----------- |
| Editor | `~/.positron/extensions/michaellydeamore.collab-comments-1.1.0-universal/` plus one entry in the active profile's registry, `~/.config/Positron/User/profiles/-eb36ac2/extensions.json` for `hebstr-positron` | Machine-local, neither stowed nor Syncthing-replicated: only `_meta/profiles/*.code-profile` are versioned |
| Editor | Two settings of its own, `commentTracker.defaultAuthor` and `commentTracker.scrollSyncPanel` | Neither is needed here |
| Quarto | `_extensions/MikeLydeamore/collab-comments/`, four files: `quarto add` nests by owner, as it does for `_extensions/hebstr/hebstr-doc` | Committed by design, as `_extensions/hebstr` already is (95 tracked files) |
| Document | `filters: [collab-comments]` and a `collab-comments:` block in the YAML of `csi.qmd` | A `/design` pass |
| Project | `.comments/collab-comments.json` at the project root | A `/design` pass, gitignore line included |
```

The project's own gates are already clear of it: `prose-lint` and `panache-format` both exclude `^_extensions/` in `prek.toml`, `check-added-large-files --maxkb=1500` sits far above a 24-entry store, `metadata-only` never sees the docx deliverable (`.gitignore` excludes `docs/*/*.docx`), and the `html-id` clean filter has nothing to bite on, the installed subtree carrying no HTML. `check-yaml` will read the extension's `_extension.yml`, which parses.

### Gate, run 2026-10-24: Word accepts the package, and the prediction of 11 skips was wrong in both directions

Render taken 2026-10-23 at 23:54, Word pass 2026-10-24 at 00:01, on the corpus above and nothing else.

**The import wrote 13 store entries, not 24.** `.comments/collab-comments.json` holds exactly the 13 mechanically mappable points, all carrying `filePath: "docs/csi/csi.qmd"`. The 11 others never reached the store, so the render could not skip them: the predicted count of 11 skip lines measured a store this import never produced.

**The render logged 7 skips, and 6 of the 24 points carry, not 13.** `quarto render docs/csi/csi.qmd` exits 0 on both formats, with no `[WARNING]`, no `[ERROR]`, no `Could not fetch resource` and no `Could not convert image`. All seven skips carry one single reason of the six, `selection occurs only in unsupported rendered structure`, and each one is a block shape rather than a string problem:

```
| id | source line | block the selection lands in |
| -- | ----------- | ---------------------------- |
| `ff5b7303` | 51 | `Para` spanning lines 47-52, which carries the citation `@villatte2020` |
| `92c720d6` | 92 | `Para` spanning lines 91-94, which carries the citation `@has2023_snds` |
| `e2cb8393` | 101 | item of a `BulletList` |
| `4e385c3f` | 104 | item of a `BulletList` |
| `b23f3d50` | 108 | item of a `BulletList`, and wholly `Strong` |
| `cdc19946` | 130 | continuation paragraph of an `OrderedList` item |
| `3799fd76` | 188 | top-level `Para`, wholly `Strong` |
```

The six survivors are `135470a6` (line 54), `5ab9605e` (line 67), `048af7ed` (line 216, a `Header`), `bc99b6d3` (line 276, a `Header`), `39eb5e1b` (line 473) and `c96de565` (line 490): a top-level `Para` holding nothing but `Str`, `Space` and `SoftBreak`, or a `Header`. That is block mappability, which the pass left unmeasured and said could only lower the count. It did, by seven.

**None of the seven is repairable by resizing its selection**, and that is the finding that bears on the `/design` pass. `rewrite_block()` refuses the block, not the span, so a citation anywhere in the paragraph, a list item at any depth and a wholly bold paragraph are each fatal to every selection inside them. The ten points the pass called relocatable were sorted on uniqueness and line containment alone; each now has to clear block shape as well, and where it cannot, the point moves to a neighbouring supported block or leaves the docx, as comment 1 already does.

**Structural pass, `rules/docx.md`, on `docs/csi/2026-10-03_prise_csi.docx`**: zero cells failing to end on `w:p`, 21 `w:tbl`, 5 media parts, one `w:footerReference`, zero unresolved `?@`. `word/comments.xml` is present, declared in `[Content_Types].xml` and related from `word/_rels/document.xml.rels`; it holds 6 `w:comment`, and the id sets of `commentRangeStart`, `commentRangeEnd` and `commentReference` are equal to each other and to those six. No `word/commentsExtended.xml`, as predicted. Author `GAUTHIER Victoria` on all six, with her original timestamps. `git diff --numstat` over `output/`, `docs/snds/output/` and `docs/timeline/output/` returns no HTML line.

**Word opens the package and anchors every comment, so the adoption stands.** `word-render --capture` on `ju-TP2`, Word 16.0.20430, 39 pages all brought back, every declared family installed. No repair prompt, and the table of contents field updated, so Word parsed the document fully rather than degrading it. The six balloons sit on pages 5, 5, 12, 14, 23 and 24, each connected to its exact stored span, including the two that start mid-word (`binaison de branches.` and `notation de référence...`), which Word highlights from the stored offset and not from the word boundary. The kill condition is cleared.

**One measurement the reading did not predict: pandoc writes no `w:initials`**, so each balloon reads `Commented [1]:` where one the reviewer wrote herself reads `Commented [GV1]:`. Her name stays in `w:author` and surfaces in the review pane and on hover. The usage warning above, that nothing distinguishes a re-emitted comment from an original, is therefore too strong for the balloon label and right everywhere else.

### The export's refusal is a self-imposed shortcut, and lifting half of it is one line

Probe of 2026-10-24, run after the gate and reverted the same hour. It settles what the gate's seven skips cost to recover, and it opens a route the reading did not weigh.

Neither OOXML nor pandoc forces the refusal: pandoc places a comment span wherever an inline goes. Two shortcuts in the filter produce it, and the source names them, `rendered_block_texts()` carrying the comment "This is counting only: the separate rewrite pass remains limited to top-level simple blocks."

- `add_docx_comments()` walks `doc.blocks` with `ipairs` and never recurses, so no block inside a list, a Div or a table is ever rewritten.
- `inline_text()` returns `nil` on the first inline that is not `Str`, `Space`, `SoftBreak` or `LineBreak`, so a single `Cite`, `Strong`, `Link` or `Code` disqualifies the paragraph that holds it.

**Measured on the first shortcut alone**: replacing that loop with `doc:walk` over `Para`, `Plain` and `Header` takes the render from 7 skips to 4 and the delivered docx from 6 to 9 `w:comment`, the three marker kinds agreeing on nine ids, zero cell failing to end on `w:p`, exit 0 on both formats. The three recovered are two bullet items and an ordered-list continuation. The four left are the two paragraphs holding a citation and the two wholly bold ones, which need the second shortcut lifted: map inline offsets and split a `Str` at the boundary instead of refusing the block.

The patch was reverted and the vendored file is byte-identical to `2dc18c0` in `eds-prise`. What it costs, against hand-written store entries that must be re-derived whenever the prose moves: owning a patch over a vendored upstream with one author, which breaks the `quarto update collab-comments` route of the updater section above. Neither route touches the eleven that never reached the store, three of which (the subtitle, the two on a PNG in a table cell, the one on an inline R value) have no body block to anchor to at all.

## Decision

**1. Adopt, both halves, for this delivery.** The route works, the arithmetic is 13 mechanical and 10 by hand and 1 impossible, and no alternative reproduces itself at the next render: the register answers a different question, and manual docx surgery would have to be redone every time the user re-renders, which is precisely what he asked to stop doing. Ten store entries written once, in a versioned JSON, against a document that will be re-rendered several times, is the cheaper side of that trade by a wide margin.

**2. No apostrophe check, and the question is closed rather than deferred.** The guard that matters is already in place (`panache.toml` with `smart = false`, which stops the formatter from undoing the normalisation), and the residual risk is covered completely by the filter's own diagnostic. Build nothing; read the stderr at each delivery render.

**3. The editor half is adopted for the re-anchoring first, the import second.** Installing it for the import alone would be a close call, the import covering 13 of 24. Installing it to keep a hand-repaired store anchored under a document the user is still rewriting is not close.

**4. The fork, decided by the user on 2026-10-24, after the gate.** The docx branch alone is forked into `quarto-hebstr-doc`, patched there and reviewed there; the editor half stays upstream, a patch to it recovering only 6 of the 11 never-imported points (4 ambiguous selections, 2 spanning source lines), each of which a hand-written store entry also recovers, against a machine-local VSIX no repository of the user's versions. This overturns item 1 on its cost side and not the adoption: the patch is owned, with the loss of the `quarto update collab-comments` route of the updater section below. Three stairs, the first measured and reverted the same day: `doc:walk` over `Para`, `Plain` and `Header` instead of the `ipairs` over `doc.blocks` takes the render from 7 skips to 4 and the docx from 6 to 9 `w:comment`; recursion into formatting containers (`Strong`, `Emph`, `Link`, `Span`, `Quoted`) carries the two wholly bold paragraphs, where every inline is still pure text; atomic inlines (`Cite`, `Code`, `Math`, `Image`) as opaque runs that are never split carry the two holding a citation, for 13 of the 13 imported. **The ceiling is 20 of 24**, four points having no body block at any stair: the subtitle (metadata), the span whose headings were removed on 2026-10-03, and the two aiming at a PNG inside a flextable cell, which pandoc emits as a `RawBlock` of openxml; the last two can be re-aimed at the table caption, which is a `Para`.

**One defect the second stair has to fix, measured on pandoc 3.10 on 2026-10-24.** The filter keeps two text views and its own comment claims they agree ("this must agree with rewrite_block's literal scan above"): counting uses `pandoc.utils.stringify`, which renders a `SoftBreak` as a space, where rewriting uses `inline_text`, which renders it as `\n`. With one sentence per source line, every paragraph of that document carries `SoftBreak`, so the counting offsets and the rewrite offsets diverge. It is unreachable while `selected_source_text()` refuses a selection crossing a source line, no stored literal ever holding `\n`, and it stops being unreachable as soon as the rewrite view widens: the two views must become one function, or counting validates an occurrence that rewriting places elsewhere.

**One kill condition the reading cannot settle**: a real Word must open the package. Comments are new parts, and Word refuses a malformed part outright where LibreOffice converts it (`rules/docx.md`). The gate below tests it and nothing else can. **Run 2026-10-24, and cleared**: see "Gate, run 2026-10-24" above.

### Revisit trigger

Three, each recognisable when it lands.

- **Overturned the adoption, had it fired**: Word on `ju-TP2` refusing the commented package, or opening it with the comments detached from their ranges. The gate of 2026-10-24 ran it and neither happened, so this one is spent rather than pending.
- **Retires the ten hand-written entries**: an upstream docx branch that falls back to the stored `contextBefore` / `contextAfter`, which the store already carries and the export ignores, instead of requiring a literal single-line source slice. Watch `selected_source_text()`.
- **Retires the flattening**: an upstream export that writes `word/commentsExtended.xml`, which would give the reviewer a threaded conversation back.

### Revert path

```sh
# Quarto half and store, in the project
rm -rf /home/julien/Documents/des/eds/eds-prise/_extensions/MikeLydeamore
rm -rf /home/julien/Documents/des/eds/eds-prise/.comments
git -C /home/julien/Documents/des/eds/eds-prise checkout -- docs/csi/csi.qmd

# Editor half: uninstall MichaelLydeamore.collab-comments from Positron's
# Extensions pane. It owns ~/.positron/extensions/michaellydeamore.collab-comments-1.1.0/
# and one entry in that directory's extensions.json, both machine-local,
# neither stowed nor replicated.
```

This pass installed nothing: it fetched read-only copies of the sources into the session scratchpad, which dies with the session.

### Updater

Per `rules/install.md`, and neither half gets a `sys-update` module.

The editor half rides Positron's own extension auto-update: `~/.config/Positron/User/settings.json` pins no `extensions.autoUpdate`, and `sys-update`'s `positron` module updates the application only, its script naming no extension.

The Quarto half is per-project and pinned on purpose: `quarto update collab-comments` by hand, in the project, when the revisit trigger fires. `quarto list extensions` will report `collab-comments 0.1.0` whichever tag is installed, so the installed version is read from the note or from git, never from quarto.

### Usage warning

- **A delivery render that loses comments exits 0.** The only report is the `[collab-comments] ... skipped Word comment` lines on stderr. A delivery that does not read them ships a Word missing an unknown number of the reviewer's points.
- **`quarto list extensions` reports 0.1.0** for a `v1.1.0` install, the extension's own manifest declaring that version.
- **Re-exported comments carry the reviewer's name and her original timestamps**, so nothing in the Word she receives distinguishes a comment the filter re-emitted from one she wrote herself. That is the point of the delivery, and it means a round trip can duplicate a point if the store ever holds two entries for it.
- **Replies are flattened in both directions**: the import ignores Word threading, the export writes one read-only transcript per thread with `—— Reply · author · timestamp ——` separators. She will not get a conversation back.
- **The editor half can corrupt the store it is kept for re-anchoring.** Measured on `eds-prise` on 2026-10-24, between a validated store of twenty entries and the next read: six of the twenty took a `trackedChanges` entry of author `julien` whose `previousText` was the stored selection and whose `newText` was the whole document, and a range of line 0 to the last line, taking the file from 20 KB to 1.33 MB. The fourteen others were untouched and the six share neither a shape nor a position; the document had been reformatted by panache in the same minute, no line moving. Nothing in the render catches it, the filter reporting only a selection that no longer matches the source, and the delivered balloon would carry the whole document as its transcript. So a store is verified against the source before any render that ships and before any commit, and the hazard disappears once the document is closed in the editor or the extension disabled, re-anchoring by hand being the fallback the filter's own diagnosis makes cheap.

## The contained-trial gate

The reading settles everything but Word's acceptance, so one trial remains, and the user runs it.

What it must exercise: the real document, the real reviewed docx and the real Word, not a fixture. A LibreOffice render would answer a different question (`rules/docx.md`: it converts packages Word refuses).

Containment is partial here and saying otherwise would be false: the Quarto half installs into the project tree and the store sits at the project root, so there is no scratchpad form of this trial. What stands in for containment is git (the tree is clean, the revert path above is three commands) and the filter's own inertia: without a store and without the YAML keys it is a no-op.

```sh
cd /home/julien/Documents/des/eds/eds-prise
quarto add MikeLydeamore/collab-comments@v1.1.0        # pinned, never @latest
# Positron: install MichaelLydeamore.collab-comments from OpenVSX
# csi.qmd YAML:
#   filters: [collab-comments]
#   collab-comments:
#     docx-comments: true
#     show-resolved: false
# Positron command palette: Collab Comments: Import Comments from Word…
#   -> docs/review/2026-09-29_prise_review-manuscrit.docx
quarto render docs/csi/csi.qmd 2>&1 | tee /tmp/csi-render.log
grep -c 'skipped Word comment' /tmp/csi-render.log    # expected: 11, one per unmapped point
grep 'skipped Word comment' /tmp/csi-render.log       # and their reasons, against the prediction
```

Then the structural pass of `rules/docx.md` on the produced docx, and a real Word on `ju-TP2` through `word-render --capture`.

A skip count above 11 is the block-mappability constraint showing up, not a failure: it names which of the 13 also need a hand-written entry.

## What stays uncovered

- **Block mappability against the 13: closed by the gate of 2026-10-24.** Seven of the 13 fall, and what the filter refuses is the block rather than the span. The md-nesrine figure of 95 % of prose words mappable was measured on another document and does not transfer.
- **Word's own acceptance of the package: closed by the gate of 2026-10-24.** Word 16.0.20430 opens it and anchors all six. Re-measured the same day on the twenty-entry store: twenty balloons over 39 pages, numbered 1 to 20 with no gap, **a float caption among them**, anchored on the caption text with Quarto's `Table N.` prefix outside the highlight; detail in `eds-prise/.claude/DESIGN-INDEX.md`, « Word carries the twenty ».
- **Comment 1.** It has no anchorable target, and where it goes instead is the user's call.
- **The reviewer's text edits.** This tool never carries them; `/review-prose` did, at `c461e9c`.
- **The HTML export and the preview bridge.** Out of the question asked, and the md-nesrine bench already measured both.
