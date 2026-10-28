# Read a rendered docx, xlsx, pptx or PNG in a git diff

A render rewrites its binary outputs with no content change, and git reports each one as `Bin X -> Y bytes` with nothing to inspect.
On md-nesrine, 16 files churned after a re-render on already committed content, 4,1 Mo of them, and the only way to tell noise from a real change was to unzip both versions and diff them member by member.

The remedy is a `textconv` diff driver, `out-textconv`, which renders the file as stable text for `git diff`, `git show` and `git log -p`.
It reads only: stored bytes are untouched, unlike the `html-id` clean filter beside it (`git-html-id-filter.md`), which is what makes it safe on a deliverable Word refuses at the slightest OOXML breach.
An empty diff then means the content did not move, and that is the whole signal.

Applied to md-nesrine on 2026-09-12.
`_meta/profiles/gitattributes` carries the four lines a next project needs.

## What moves on every write, and what the driver does with it

```
| Source                                     | Reaches                                  | Treatment                                 |
| ------------------------------------------ | ---------------------------------------- | ----------------------------------------- |
| `dcterms:modified`, `dcterms:created`      | every OOXML package                      | element content emptied                   |
| `TotalTime`                                | `docProps/app.xml`                       | element content emptied                   |
| `cp:lastModifiedBy`                        | every OOXML package                      | element content emptied                   |
| `w:fontKey` GUID                           | `word/fontTable.xml`                     | attribute value emptied                   |
| ODTTF obfuscation header, 32 bytes         | `word/fonts/font*.odttf`                 | digest of the payload past byte 32        |
| PNG `tIME` chunk                           | standalone PNG and PNG members           | chunk dropped                             |
| PNG recompression, IDAT splitting          | standalone PNG and PNG members           | digest of the decompressed scanlines      |
| ZIP header mtimes                          | every OOXML package                      | never read, members are read by name      |
```

Each is neutralised rather than dropped, the `tIME` chunk excepted since it carries nothing but the time, so a real change in the same part stays visible: a font subset that actually moves, a `w:altName` alternative, a document title.
The PNG digest reads the scanlines before unfiltering, so the same pixels under another filter byte still read as a change: measured 2026-09-12 on a 2-pixel image, None against Sub.
One encoder is deterministic, so that shows only when the encoder or its filter strategy moves.
XML members are emitted one line per tag, so a diff lands on the element that moved rather than on a single 60 000-character line.
Members are walked in sorted order, which makes the output independent of the order the writer happened to use.
Anything that is neither a ZIP nor a PNG, and anything that fails to parse, falls back to a digest and exits 0: a driver has no right to break `git diff`.
Inside a package the fallback is per member, so one member that fails to parse, a JPEG under a `.png` name or a UTF-16 part, is digested alone and leaves the other members' timestamps neutralised.

A truncated member raises nothing the tuple in `main` is missing, which settles an open question of 2026-09-12.
Measured 2026-10-12 on `python3` 3.12.3, the interpreter of the `uv run --script` shebang, over the two shapes a truncation can take: with the local and central `compress_size` corrected to the shortened data, `zipfile` raises `BadZipFile` on the CRC, and with both headers left claiming the original size it raises `BadZipFile` on the overlap guard, "possible zip bomb".
`zipfile.BadZipFile` is already in the tuple, so both forms print the digest and exit 0.
That overlap guard is also what keeps the reader from ever being starved of bytes, which is the condition that would raise `EOFError`.
Bounded negative: the two shapes above, not a zip64 member nor a `stored` one.

## Why a script rather than pandoc

`gitattributes(5)` prefers an existing program as the filter, and pandoc reads `docx`, `pptx` and `xlsx` as input, so `textconv = pandoc -t plain` is the shorter and more idiomatic route.
Measured 2026-09-12 on md-nesrine, it also works as a noise filter: 0 line on the three churning pairs, docx per table, report docx and xlsx.

What it cannot do is see anything outside the prose.
On the real v4.2.5 to v4.2.6 change it reports nothing of the figure extents (0 line against 24) and nothing of the template reference moving from `chazard_modele_these_medecine_2022.dotx` to `template.dotx` (0 against 2), since `-t plain` emits no geometry.
Fonts, styles, relationships and media bytes go the same way, which are the parts that had to be opened to classify the churn in the first place: a pandoc driver would have concluded "no change" without ever reading the `w:fontKey`.
It agrees here by ignoring more, not by measuring the same thing.
Standalone PNG are out of its reach entirely, and it costs 1,23 s against 0,41 s on the report docx.

The deciding argument is local: the recurring docx defects of this project are layout, cell mapping, `gt` column widths, a line break swallowed inside a footnote, and a prose projection is blind to that class.
The pandoc lens stays available per invocation, without touching the config:

```
git -c diff.out-textconv.textconv='pandoc -t plain' diff -- <file>
```

## Setup

`.gitattributes`, tracked, at the repo root:

```
*.docx diff=out-textconv
*.pptx diff=out-textconv
*.xlsx diff=out-textconv
*.png diff=out-textconv
```

The driver and its program both ship in the `git` stow package, so `stow git` is the whole setup on a new machine:

```ini
[diff "out-textconv"]
    textconv = ~/.config/git/out-textconv.py
```

The real line in `git/.gitconfig` is tab-indented, where the excerpt shows four spaces: panache rewrites a tab inside a fence whatever its language tag, re-measured on 3.17.0 on 2026-10-24, so the excerpt cannot carry the tab and the divergence is not a defect of the note.

The program sits at `git/.config/git/out-textconv.py`, beside the config that calls it, rather than on the PATH: git is its only caller, and git runs the value through `sh`, which expands the `~`.
It carries a `.py` extension so that `pyrefly check` and the editor recognise it as Python: both skip an extensionless file, whatever its shebang says.

Broad extension globs are deliberate, where `html-id` is scoped narrowly: a clean filter rewrites bytes and earns its narrow scope, a textconv driver only changes what a diff prints.

## Verification

`git check-attr diff -- <file>` and `git config --get diff.out-textconv.textconv` settle whether the driver is actually wired.
Then the diff itself, on md-nesrine, 2026-09-12:

- the 16 files churning after a re-render of committed content: 0 lines of patch, 1,6 s for the set.
- the same driver on the real v4.2.5 to v4.2.6 change: 439 lines, all in `docs/<date>_rapport-stat.docx`, the template moving from `chazard_modele_these_medecine_2022.dotx` to `template.dotx`, hebstr from 0.18.1 to 0.18.2, and every figure extent widening.
- the twelve other docx of that commit: 0 lines, so they were already noise in history.

`bats _meta/tests/out-textconv.bats` covers the classification itself, 29 tests in 7,6 s on battery: one per noise source of the table above, the font key and its obfuscation header sharing one and PNG recompression or IDAT splitting having none, a body change, a font subset payload and an embedded PNG pixel still visible, the output shape, a PNG trailer neutralised and still visible, the six fallbacks and the two usage errors.
The comparison helpers assert both renderings non-empty, since a driver that crashes on both sides renders identically and a bare `diff` of two empty streams reports agreement.
Six mutations were run against the suite to check it tests what it claims, measured on 2026-09-12 against the 28 tests: dropping the embedded-PNG branch, dropping `dcterms:created`, dropping the member sort and zeroing the obfuscation offset each fail exactly one test, dropping the one-line-per-tag split fails two, since the title assertion reads the split as well, and a driver replaced by `exit 0` fails all 28.

## Ways to lose it in silence

`cachetextconv` is off, and that is not an oversight.
It caches the rendered text per blob, indefinitely, and git invalidates that cache when the `textconv` **config value** changes, not when the program it names is edited (`gitattributes(5)`, git 2.55.0).
Here the config value stays `~/.config/git/out-textconv.py` across every edit of the script, so the cache survives each one: observed on the way in, a driver fix reading 37 lines of stale patch where the new code produces none.
The manual documents the same case, an updated `exif` producing better output, and the same remedy: `git update-ref -d refs/notes/textconv/out-textconv`, the ref being named after the driver.
That is what a cache ref written before the setting was dropped needs; with `cachetextconv` off it is inert but present.
What caching would buy back is part of the 1,6 s an uncached pass over 16 files costs, which does not pay for a stale answer on a driver still moving.

`git status`, `git diff --stat` and `--numstat` keep reporting the file as binary, git deciding that from the blob rather than from the driver's output.
So the signal is the patch body, never a line count from `--stat`.

A machine where the `git` package is not stowed: the `diff=out-textconv` attributes then name a driver defined nowhere, and git prints `Binary files a/... and b/... differ` with no error.
Verified 2026-09-12 by pointing an attribute at an undefined driver.
Config and program ship in the same package, so they are present or absent together, and `git config --get diff.out-textconv.textconv` is the check.

An in-body element whose content a writer stamps per run and that is not in the table above.
The tell is a diff limited to one element under `### docProps/`; the fix is one entry in `VOLATILE_ELEMENTS`.

## What it does not do

It does not reduce the weight of the repository: a commit still stores the full new blob.
It makes the decision possible, restoring the noise instead of committing it, and that decision was manual until 2026-10-24.
The `metadata-only` prek hook (`bin/.local/bin/metadata-only`, declared in `_meta/profiles/prek.toml`) enforces it at commit: a staged, modified binary with an empty patch body fails the commit and the hook points to `metadata-only --restore`, while restoring stayed the user's act until 2026-10-24, when the `out-meta` clean filter took the common case: see "A clean filter keeps the noise out of the index" below.

## The hook's failure message prints once and ends on a short command

Decided and implemented 2026-09-16: the hook runs with `require_serial = true`, prints one header counting the files, the file list, and ends on `metadata-only --restore`, a mode that recomputes the noise set and applies the restore-or-unstage split when it runs.
Plain text, no colour, no symbol.

The trigger was a real commit on md-nesrine the same day: 14 files reported under 5 repeated headers, each followed by a `for` loop of at least 208 characters, its length with a single path.
The repetition is prek's, not the script's: without `require_serial`, prek 0.5.3 splits filenames into batches of `max(4, ceil(n / CPU count))` (`Partitions::split` in `crates/prek/src/run.rs`) and runs the script once per batch, each invocation printing its own header and command.
With `require_serial` the whole list goes to one invocation, ARG_MAX permitting, which is also how ruff-pre-commit declares its hooks.
The flag belongs in `_meta/profiles/prek.toml` and in every project copy of the hook.
Measured 2026-10-24, eds-prise's `prek.toml` is the only copy still without it, md-nesrine's having been aligned since: the condition to check is that `rg -c require_serial` answers on all five of eds-prise, md-nesrine, crpv-ciclo, crpv-aod and eds-avc.

The shape follows clig.dev (read in full 2026-09-16): same-type errors grouped under one explanatory header, the most important information last, a suggested next command that stays short, as its own examples `chmod +w file.txt` and `git restore <file>...` do.
The layout mirrors `sys-orphans`, which lists findings under a counted header and closes on the reminder that fixes are the user's to run.

### Why a recomputing mode rather than a printed command

The restore is conditional per file: a working copy re-rendered after staging is only unstaged, never overwritten, and `_meta/tests/metadata-only.bats` pins that with a render made between the hook's message and the `--restore` run.
A printed command can only keep that guarantee by carrying the condition, which is what made the loop unreadable.
`--restore` keeps it by deciding at execution time, and costs a second mode in the script with its own tests.

### Ways rejected

- Reformatting around the existing loop: the loop stays a compound shell construct to read before running, the exact complaint.
- Splitting the files at hook time into `git restore -s@ -SW -- <paths>` for clean working copies and `git restore --staged -- <paths>` for the others: two plain commands, but a snapshot, so a render landing between message and paste is overwritten by the first.
  It drops the guarantee the bats test pins.
- Installing a CLI-design agent skill: none is installed and none is official; `kergoth/dotfiles` `cli-design` fits shell tools best and `citypaul/.dotfiles` `cli-design` is the deepest, but clig.dev alone covers one hook message.
  Worth revisiting if more CLI tools get written.

### `--restore` acts on a property, so drift since the message is harmless

Decided 2026-09-16, the three points left open by the first pass.

`--restore` takes no argument: it recomputes over every staged, modified file routed through `out-textconv` whose patch is empty.
Paths would repeat the list already printed and bring back the quoting of spaces and brackets that made the loop unreadable.
The set is defined by a property rather than a snapshot, so the worst case of an index that moved since the message is restoring a file whose only change is write metadata, which loses nothing.
It prints one line per file it acts on, `restored  <path>` or `unstaged  <path> (working copy re-rendered, kept)`, after clig.dev's "If you change state, tell the user", so a set that drifted is visible.
Without the driver configured it refuses with the hook's message, having no way to classify; a file not routed through `out-textconv` is left alone.

A file staged between the message and the command is in scope when it is noise, and two bats tests pin both sides: a noise file staged late is restored, a file with a real content change staged late is untouched.
The second is the load-bearing one, since it guarantees drift never destroys content.

The 3, 3, 3, 4, 1 grouping, which does not match batches of 4 on 12 CPUs, is closed without investigation: `require_serial` leaves one invocation and makes the discrepancy moot, and a `prek run -vvv` on md-nesrine would cost an index manipulation on a live project to explain a behaviour about to disappear.
The check after implementation is a single header on md-nesrine's next metadata-only commit.
The grouping explained itself on the first run of the new message, 2026-09-16, before md-nesrine's `prek.toml` carried the flag: 17 matching staged files, 16 modified and 1 added, split 4, 4, 4, 4, 1, and the three files that pass (two content changes and the added one) fell one in each of the first, second and third batches, hence 3, 3, 3, 4, 1 listed.

## A clean filter keeps the noise out of the index

Decided 2026-10-24, on the user's request to automate the `--restore` step.
That reopens the manual decision of "What it does not do" above, and reinstates a shape rejected on 2026-09-12 for want of the measurements below (`git-html-id-filter.md`, "Settled elsewhere: the same churn on the OOXML artifacts").

The decision is `[filter "out-meta"]` in `git/.gitconfig`, whose program is `git/.config/git/clean-out-meta.py`, attached per project by anchored patterns in that project's `.gitattributes`.
Git normalises the package on its way into the index, so a re-render that moved nothing else produces a blob identical to the stored one: no hunk, nothing staged, no command to type.
The precedent is `[filter "html-id"]` and the three-step shape `comment-hash` and `positron-theme` both follow (`git-html-id-filter.md`, "Step 2: the driver"), down to declaring no `smudge` and no `required`.
The second half is taken in one project: eds-prise declared the four lines on 2026-10-25, so the filter runs there and nowhere else, and every count below that speaks of what the pattern would reach counts files no filter runs on outside it (`rg -uu -l --glob '.gitattributes' 'filter=out-meta' ~/Documents ~/admin ~/dotfiles` answers `eds-prise/.gitattributes` alone, 2026-10-25; the glob is what keeps the condition checkable, every note quoting the string being a hit without it).

Measured the same day over every tracked binary of eds-prise, md-nesrine and eds-avc, each paired with a simulated re-render that moves every field the writers were measured to move: 112 of 112 pairs collapse to the same bytes, 0 differ, the three `.pptx` of eds-avc among them at 111, 71 and 147 members preserved.
A pass costs 79 ms per file on battery, so about 4,4 s over eds-prise's 56 tracked binaries, of which the anchored attribute reaches the 43 that sit under an `output/` tree.
`_meta/tests/clean-out-meta.bats` pins the contract in 27 tests, and six mutations of the program each fail between one and four of them, measured on the 23 the suite carried before 2026-10-24.
Three of those tests came out of the `/audit:walkthrough` pass of 2026-10-24, which then measured every class of the handler's exception tuple to be pinned by exactly one test, dropping `NotImplementedError` excepted: that mutation fails nothing, `RuntimeError` already covering it by inheritance.

### The index goes quiet, `git status` does not

The filter normalises on the way into the index and never on disk, and the raw render is not byte-stable, so the cached stat keeps diverging.
Measured 2026-10-25 on eds-prise: `output/tbl-concept/tbl-concept.docx` went from 14 572 to 14 571 bytes between two renders, and `git status` listed every re-rendered docx as modified while `git diff`, `git diff --cached` and `git hash-object -w --path` against `HEAD:<f>` all three returned identity.
`git update-index --refresh` does not clear the mark, answering `needs update` on the size mismatch; only a `git add` over the output trees re-runs the filter, refreshes the stat cache and stages nothing.
So "no hunk, nothing staged, no command to type" above is about the index alone: what tells a real output change from write-metadata noise is `git diff`, never `git status`, and prek's stash is unaffected either way, reading git's own diff rather than the bytes.
That residual noise reaches the commit skill: `writes.sh` appends every `git status --porcelain` entry to the `WRITES` list without reading the status code, so a re-render puts the sixteen docx in front of the verifier.
Filtering them there is rejected, 2026-10-25: a filter keyed on `git diff` returning identity would also drop the untracked `??` entries, which appear in no diff and are what the list exists to surface, so it would owe a discrimination on the status code plus one `git` call per entry.
The noise costs tokens in the verifier pass rather than correctness, since the `git add` over the output trees stages nothing, so that command stays the remedy and the question reopens only if a real closure shows the verifier derailed by the sixteen.

### The volatile value is pinned to what its own type accepts, because the package declares them

`dcterms:created` and `dcterms:modified` carry `xsi:type="dcterms:W3CDTF"` and `TotalTime` holds an integer, so an empty element breaks the type the package declares, and Word enforces the content model by refusing to open a file rather than by degrading it (`rules/docx.md`, "Structural validity, which a render never tests").
Stability is the whole requirement and any fixed value gives it, so those three are pinned to `1980-01-01T00:00:00Z`, `1980-01-01T00:00:00Z` and `0`, and the ZIP entry dates to the 1980 epoch the format floors at.
`cp:lastModifiedBy`, added to both tuples on 2026-10-28, declares no type and holds a plain string, so the empty element is itself a value the package accepts and the pin is `""`.
The `out-textconv` driver empties the same four, which costs it nothing: it renders text and stores no bytes.

`dc:creator` stays out of both tuples, decided on a measurement rather than by symmetry with the author field (2026-10-28, over the tracked `docx`, `xlsx` and `pptx` of eds-prise, md-nesrine and eds-avc).
All 27 files the filter reaches carry an empty one, so the filter would pin nothing.
The driver's broad globs do reach 13 non-empty ones, and 6 of those are a person's name or Word's `Author` placeholder rather than an account a writer stamped, `GAUTHIER Victoria` on eds-prise's timeline workbook and on an eds-avc deck, `Elices-Diez J, Geay C., Ficheur G., Theis D.` on an eds-avc abstract: blanking it would hide content on exactly the hand-authored files the filter was anchored away from.
The churn case is openxlsx2, which stamps the account into `dc:creator` as well as into `cp:lastModifiedBy`; none of the files it wrote is routed to the filter, so the remedy there is a `creator` argument at write time rather than a blind spot in the driver.

### The filter normalises strictly less than the driver beside it

The `w:fontKey` GUID and the 32-byte ODTTF obfuscation header are left alone, since blanking the key without re-keying the payload it XORs produces a file Word refuses.
PNG payloads are never re-encoded either: a PNG loses its `tIME` chunk and keeps every other one byte for byte, verified on `word/media/rId36.png` of md-nesrine's report, whose three IDAT chunks come through identical at 74 352 bytes.
So no rendering engine can read the cleaned package differently from the raw one: on that report the only members that move are `docProps/core.xml`, `docProps/app.xml` and that one dropped chunk.
The standalone `*.png` route normalises nothing on the current corpus: none of the 139 PNG sitting under an `output/` tree the pattern would match carries a `tIME` chunk or a byte past `IEND`, so a `git add --renormalize` that touches no PNG blob is the expected reading rather than a sign the filter failed (measured 2026-10-24).

### What a licensed Word still owes

Two questions no tool reachable from here settles, each about an Office save rather than a render, and neither reached by the measurements above (`/audit:walkthrough`, 2026-10-24).
The 2026-10-25 pass does not reach them either, and cannot: the Word of ju-TP2 is unlicensed, so it lays out and paginates but writes no file, which is what `word-render` reports on every capture and what [[project_word_render_control]] records; no save can be performed there to measure.
`cp:revision` is not pinned, and 27 of the 28 tracked outputs the pattern would reach carry `9`, the 28th carrying no `cp:revision` element at all.
That `9` is inherited verbatim and stable across renders rather than counted per write: `officer`'s own `template/template.docx` carries `<cp:revision>9</cp:revision>` (measured 2026-10-28), so the filter's own goal is unaffected, and the case for pinning it rests on whether a Word open-and-save that changed no content moves it while bringing the rest of the package back identical.
If it does not, the pin buys nothing.
`docProps/thumbnail.jpeg` and `ppt/printerSettings/printerSettings1.bin` pass through byte for byte, neither occurs in any of the 28 files the pattern would reach, and whether Office rewrites them on such a save is unestablished.

`cp:lastModifiedBy` left this list on 2026-10-28, and the measurement that moved it concerns the render, not an Office save: the same template carries `David Gohel` while no output does, because `officer`'s `print.rdocx` assigns `Sys.getenv("USER")` to the field on every write.
The value is therefore the Unix account of whoever rendered, which is why the 27 outputs carrying `julien` all restage as `edjulien` on the CHU machine, one changed line each, and it is pinned in both tuples rather than waiting on a licensed Word.
Blanking it for privacy had been weighed and declined, a reviewer's Word round trip putting the same name in the `w:author` of `word/comments.xml`, which is content the filter must not touch: that ground is untouched, the pin happening for stability despite it rather than against it.

### The stored blob carries the deflate implementation

Every member is recompressed at level 6, so identical input bytes yield identical output only under an identical deflate.
The exposure is narrower than it reads: the uv-managed CPython bundles zlib statically, so the system library is not a factor, and the two builds present here, zlib 1.3 under the system `python3` and 1.3.2 under the shebang's 3.14.8, produce byte-identical output on a 16 kB docx, a 34 kB xlsx and a 1.9 MB pptx of 147 members (measured 2026-10-24).
A patch bump is therefore not the trigger, a materially different implementation such as zlib-ng is, and it would rewrite every stored blob at once.
Copying the original compressed bytes for the members left unchanged has no public `zipfile` API and would mean hand-writing local headers, so the property is recorded rather than engineered around.

### The fallback is a passthrough, since here the output is what git stores

Anything that is neither a ZIP nor a PNG, and anything that fails to parse in one of the six ways a malformed input produces, is written through byte for byte at exit 0.
Where the driver may fall back on a digest, a mangled output here destroys content git has no way to recover.
The handler names those six classes, `zipfile.BadZipFile`, `zlib.error`, `struct.error`, `ValueError`, `NotImplementedError` and `RuntimeError`, rather than catching `Exception`, and the difference is the diagnostic: git reads a non-zero exit as a no-op passthru (`gitattributes(5)`, "a filter driver that exits with a non-zero status, is not an error but makes the filter a no-op passthru"), `out-meta` declares no `required`, and the write to stdout sits outside the `try`, so a programming error that propagates stores the original bytes exactly as a blanket handler would while leaving a trace rather than a binary that re-diffs on every render with no clue why.
A member reaches `png_bytes` on its suffix and its magic together, since that function opens its output on a literal PNG signature: on the suffix alone, a non-PNG member named `*.png` whose chunk walk lands exactly on EOF came back with its first eight bytes replaced, at exit 0 and with git storing the result (measured 2026-10-24).
The archive comment and each member's `compress_type`, `external_attr`, `internal_attr` and `create_system` are preserved; trailing bytes past the central directory are dropped, which a valid package never carries.

### The attribute is anchored, where the driver's globs are broad

A clean filter rewrites bytes and earns its narrow scope, as "Setup" above already says of the contrast with `html-id`.
`_meta/profiles/gitattributes` carries four `**/output/**/*` lines, which reach a render tree at any depth and leave hand-authored sources out by construction.
Verified 2026-10-24 against the real layouts: `output/tbl-a/t.docx`, `docs/snds/output/tbl-b/t.png` and `docs/timeline/output/timeline.docx` route through the filter, while eds-prise's three hand-edited workbooks (`collect/`, `docs/snds/dict-snds-source.xlsx`, `docs/timeline/2026-09-29_prise_timeline.xlsx`), its `.streamlit/shots/` captures and md-nesrine's dated deliverable in `docs/` stay out.
A deliverable outside a render tree takes its own line in that project, the way `html-id` carries `*_rapport-stat.html` beside its `output/**` glob.

### The hook stays the backstop for what the filter cannot reach

Four cases, and the hook's behaviour is unchanged on all of them:

- a fresh `w:fontKey` with its ODTTF header, which the filter must not touch;
- a PNG whose encoder recompressed or whose IDAT split moved, which the filter must not re-encode;
- a path the project routed through the diff driver without the filter attribute, or one outside the anchor;
- a stamped element present in one of the two lists and missing from the other.

The last case is what makes the two programs safe to keep separate: they share only the volatile element names and the `tIME` chunk, and the hook fails the commit precisely when they disagree.
Cases one and two are dormant guards rather than current needs: measured 2026-10-24, no tracked docx of eds-prise or md-nesrine embeds a font subset (0 of 16 and 0 of 14), so nothing exercises the font branch today.
The `.pptx` line of the template is not dormant: eds-avc tracks three decks, and they sit under `docs/slides/` rather than in a render tree, so the anchored patterns do not reach them and that project owes a line of its own.

### Open: each adopting project owes its attribute lines

The stored bytes now change, which is what the `out-textconv` route was built to avoid, and with no `smudge` a `checkout` writes the rebuilt package into the worktree.
LibreOffice settles nothing on Word fidelity (`rules/docx.md`, "What nothing on this machine settles"), so adoption waited on `word-render --capture` opening a cleaned docx on ju-TP2 without a repair dialog.
Attempted 2026-10-24 and refused before reaching Word, the interactive session being locked, then run on 2026-10-25: Word 16.0.20430 opened a cleaned `tbl-branche.docx`, its three stamps pinned and every ZIP entry at the 1980 epoch, counted one page and laid the table out whole with no repair dialog and no error banner.
The pinned form is therefore accepted by the real Word, and the different literal this decision held in reserve against a refusal is not needed.
Each adopting project then owes one `git add --renormalize` over its binary trees, as `html-id` already required, plus the attribute lines themselves.
**That first renormalise does not pass the `metadata-only` hook**, which reads the staged blobs through the diff driver and sees outputs differing in write metadata alone, the very shape it exists to refuse: it cannot tell a normalisation migration from a noise re-render, so the one commit that arms a project runs under `SKIP=metadata-only` (measured on eds-prise, 2026-10-25, sixteen docx listed and the hook pointing at `metadata-only --restore`, which would have undone the staging).
Every later commit passes it untouched, the noise no longer reaching the index at all.
eds-prise took them on 2026-10-25, its `git add --renormalize .` moving 16 docx of the 43 binaries its anchors reach and leaving the 27 PNG byte-identical, none of them carrying a `tIME`.
Growing the pinned set reopens that renormalise for every project already armed, under `SKIP=metadata-only` for the same reason: adding `cp:lastModifiedBy` restaged the 27 docx eds-prise now tracks under its four anchors, for an empty textconv patch across all 27 since the driver blanks the field as well (2026-10-28, in two commits for the reason the last entry of "Ways to lose it in silence" records).
Everywhere else the filter stays inert, and the state to check is which `.gitattributes` under `~/Documents` carries `filter=out-meta`: the entry in `git/.gitconfig` and the program beside it change nothing on their own.

### Ways rejected

- **The hook repairing itself**, running the restore instead of printing it and then failing as prek expects: it keeps the stored bytes untouched, but the noise still reaches the index and the commit still fails once per re-render, so the round trip the user asked to remove survives. Exiting 0 after restoring would drop content under `git commit -a` or `git commit -- <paths>`, where git builds a temporary index, which is why pre-commit and prek fail rather than exit 0.
- **Normalising at the writer**: `hebstr::easy_out()` funnels `ggsave`, `openxlsx2::wb_save` and officer (read 2026-10-24 in its `R/easy_out.R`), so one pass there would make the file stable at birth with no git machinery at all. It covers nothing Quarto renders, so the report docx and any pptx keep churning, and it puts the pinned date in the file handed to a human reader rather than only in the index.
- **A `post-index-change` hook**: it fires on a no-op `git add` and on `git status`, and a hook that writes the index re-fires itself, git applying no reentrancy guard, measured at 6 fires with a counter to stop it.
- **Doing nothing**: the driver and the hook detect the noise and leave one command per re-render, which is the cost the request names.

### Ways to lose it in silence

- A change in zlib's or CPython's deflate output. The filter recompresses at level 6 on both sides, so the comparison holds within one toolchain and every stored blob moves at once when that toolchain does, costing one `git add --renormalize` per project. Nothing pins it today.
- A machine where the `git` package is not stowed: git warns and stores the raw file, the same failure `html-id` carries.
- A writer stamping an in-body element absent from the pinned list. The tell is a diff limited to one element under `### docProps/` on a file the filter already covers; the fix is one entry in `VOLATILE_ELEMENTS` of `clean-out-meta.py` and the matching one in the driver.
- A renormalise commit taken while prek stashes unstaged changes. Measured 2026-10-28 on eds-prise: `git diff --cached --name-only` showed the 27 docx the author pin restaged, prek's stash-and-restore round trip brought 5 of those index entries back to `HEAD` before git built the temporary index of `git commit -- <paths>`, and the commit took 22. The stat cache then reports those five as clean, so `git status` lists nothing and `git diff` returns identity on a migration that is half done. The tell is the commit's own file count against the count staged before it, the check is the author field of each stored blob, and the remedy is a second `git add --renormalize` over the same trees, which re-filters whatever the stat says.
