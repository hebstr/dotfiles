# Read a rendered docx, xlsx, pptx or PNG in a git diff

A render rewrites its binary outputs with no content change, and git reports each one as `Bin X -> Y bytes` with nothing to inspect.
On md-nesrine, 16 files churned after a re-render on already committed content, 4,1 Mo of them, and the only way to tell noise from a real change was to unzip both versions and diff them member by member.

The remedy is a `textconv` diff driver, `out-textconv`, which renders the file as stable text for `git diff`, `git show` and `git log -p`.
It reads only: stored bytes are untouched, unlike the `html-id` clean filter beside it (`git-html-id-filter.md`), which is what makes it safe on a deliverable Word refuses at the slightest OOXML breach.
An empty diff then means the content did not move, and that is the whole signal.

Applied to md-nesrine on 2026-09-12. `_meta/profiles/gitattributes` carries the four lines a next project needs.

## What moves on every write, and what the driver does with it

```
| Source                                     | Reaches                                  | Treatment                                 |
| ------------------------------------------ | ---------------------------------------- | ----------------------------------------- |
| `dcterms:modified`, `dcterms:created`      | every OOXML package                      | element content emptied                   |
| `TotalTime`                                | `docProps/app.xml`                       | element content emptied                   |
| `w:fontKey` GUID                           | `word/fontTable.xml`                     | attribute value emptied                   |
| ODTTF obfuscation header, 32 bytes         | `word/fonts/font*.odttf`                 | digest of the payload past byte 32        |
| PNG `tIME` chunk                           | standalone PNG and PNG members           | chunk dropped                             |
| PNG recompression, IDAT splitting          | standalone PNG and PNG members           | digest of the decompressed scanlines      |
| ZIP header mtimes                          | every OOXML package                      | never read, members are read by name      |
```

Each is neutralised rather than dropped, the `tIME` chunk excepted since it carries nothing but the time, so a real change in the same part stays visible: a font subset that actually moves, a `w:altName` alternative, a document title.
The PNG digest reads the scanlines before unfiltering, so the same pixels under another filter byte still read as a change: measured 2026-09-12 on a 2-pixel image, None against Sub. One encoder is deterministic, so that shows only when the encoder or its filter strategy moves.
XML members are emitted one line per tag, so a diff lands on the element that moved rather than on a single 60 000-character line.
Members are walked in sorted order, which makes the output independent of the order the writer happened to use.
Anything that is neither a ZIP nor a PNG, and anything that fails to parse, falls back to a digest and exits 0: a driver has no right to break `git diff`.
Inside a package the fallback is per member, so one member that fails to parse, a JPEG under a `.png` name or a UTF-16 part, is digested alone and leaves the other members' timestamps neutralised.

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

```
[diff "out-textconv"]
	textconv = ~/.config/git/out-textconv.py
```

The program sits at `git/.config/git/out-textconv.py`, beside the config that calls it, rather than on the PATH: git is its only caller, and git runs the value through `sh`, which expands the `~`.
It carries a `.py` extension so that `pyrefly check` and the editor recognise it as Python: both skip an extensionless file, whatever its shebang says.

Broad extension globs are deliberate, where `html-id` is scoped narrowly: a clean filter rewrites bytes and earns its narrow scope, a textconv driver only changes what a diff prints.

## Verification

`git check-attr diff -- <file>` and `git config --get diff.out-textconv.textconv` settle whether the driver is actually wired.
Then the diff itself, on md-nesrine, 2026-09-12:

- the 16 files churning after a re-render of committed content: 0 lines of patch, 1,6 s for the set.
- the same driver on the real v4.2.5 to v4.2.6 change: 439 lines, all in `docs/<date>_rapport-stat.docx`, the template moving from `chazard_modele_these_medecine_2022.dotx` to `template.dotx`, hebstr from 0.18.1 to 0.18.2, and every figure extent widening.
- the twelve other docx of that commit: 0 lines, so they were already noise in history.

`bats _meta/tests/out-textconv.bats` covers the classification itself, 28 tests in 7,6 s: one per noise source of the table above, the font key and its obfuscation header sharing one and PNG recompression or IDAT splitting having none, a body change, a font subset payload and an embedded PNG pixel still visible, the output shape, a PNG trailer neutralised and still visible, the six fallbacks and the two usage errors.
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
It makes the decision possible, restoring the noise instead of committing it, and the decision stays manual.
The `metadata-only` prek hook (`bin/.local/bin/prek-metadata-only`, declared in `_meta/profiles/prek.toml`) enforces it at commit: a staged, modified binary with an empty patch body fails the commit and the hook points to `prek-metadata-only --restore`, while restoring stays the user's act.

## The hook's failure message prints once and ends on a short command

Decided and implemented 2026-09-16: the hook runs with `require_serial = true`, prints one header counting the files, the file list, and ends on `prek-metadata-only --restore`, a mode that recomputes the noise set and applies the restore-or-unstage split when it runs.
Plain text, no colour, no symbol.

The trigger was a real commit on md-nesrine the same day: 14 files reported under 5 repeated headers, each followed by a `for` loop of at least 208 characters, its length with a single path.
The repetition is prek's, not the script's: without `require_serial`, prek 0.5.3 splits filenames into batches of `max(4, ceil(n / CPU count))` (`Partitions::split` in `crates/prek/src/run.rs`) and runs the script once per batch, each invocation printing its own header and command.
With `require_serial` the whole list goes to one invocation, ARG_MAX permitting, which is also how ruff-pre-commit declares its hooks.
The flag belongs in `_meta/profiles/prek.toml` and in every project copy of the hook, md-nesrine's `prek.toml` being one that does not follow the scaffold.

The shape follows clig.dev (read in full 2026-09-16): same-type errors grouped under one explanatory header, the most important information last, a suggested next command that stays short, as its own examples `chmod +w file.txt` and `git restore <file>...` do.
The layout mirrors `sys-orphans`, which lists findings under a counted header and closes on the reminder that fixes are the user's to run.

### Why a recomputing mode rather than a printed command

The restore is conditional per file: a working copy re-rendered after staging is only unstaged, never overwritten, and `_meta/tests/prek-metadata-only.bats` pins that with a render made between the hook's message and the `--restore` run.
A printed command can only keep that guarantee by carrying the condition, which is what made the loop unreadable.
`--restore` keeps it by deciding at execution time, and costs a second mode in the script with its own tests.

### Ways rejected

- Reformatting around the existing loop: the loop stays a compound shell construct to read before running, the exact complaint.
- Splitting the files at hook time into `git restore -s@ -SW -- <paths>` for clean working copies and `git restore --staged -- <paths>` for the others: two plain commands, but a snapshot, so a render landing between message and paste is overwritten by the first. It drops the guarantee the bats test pins.
- Installing a CLI-design agent skill: none is installed and none is official; `kergoth/dotfiles` `cli-design` fits shell tools best and `citypaul/.dotfiles` `cli-design` is the deepest, but clig.dev alone covers one hook message. Worth revisiting if more CLI tools get written.

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
