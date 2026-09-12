# Silence random HTML ids in git diffs

`gt` draws a fresh table identifier on every render, and `htmlwidgets` a fresh widget one, so the HTML written to `output/` differs from one run to the next with no data change, while the PNG and SVG come back to the same sha1.
A diff bearing on those files alone signals nothing, and it drowns the real changes: on the md-nesrine report, 934 of 940 diff lines were the identifier.

The remedy is a `clean` filter declared in `.gitattributes` and driven by a config entry, which normalizes the identifier on its way into the index.
No `smudge`: the working tree keeps what `gt` writes, so the rendered page is untouched and the browser still sees a unique id per table.

Applied in eds-prise (2026-09-02) and md-nesrine (2026-09-02), under the name `gtid` then `outid`.
Since 2026-09-12 it is named `html-id`, it covers `reactable` as well as `gt`, and its driver ships in the `git` stow package, so `stow git` is the whole setup on a new machine.

## The identifiers and their forms

`gt` emits ten lowercase letters and uses them twice, on the wrapping div and on every CSS selector scoping that table's style block:

```html
<div id="xjrgvihqto" style="padding-left:0px;...">
  <style>#xjrgvihqto table { ... }
#xjrgvihqto thead, #xjrgvihqto tbody, ... { ... }
```

`htmlwidgets` emits `htmlwidget-` followed by twenty hexadecimal characters and uses it three times, on the container div and on the two `data-for` attributes:

```html
<div class="reactable html-widget" id="htmlwidget-48b3cdc65c5f381848a6" ...></div>
<script type="application/json" data-for="htmlwidget-48b3cdc65c5f381848a6">...
<script type="application/htmlwidget-sizing" data-for="htmlwidget-48b3cdc65c5f381848a6">...
```

## Step 1: declare the attribute

`.gitattributes`, tracked, at the repo root:

```
output/**/*.html filter=html-id
*_rapport-stat.html filter=html-id
```

`_meta/profiles/gitattributes` carries the first line as a template.
The second covers a Quarto document embedding its tables, and mirrors the glob `_quarto.yml` already uses so a re-dating of the report does not break it.
Scope the patterns: an extension's HTML or a vendored asset has no business going through the filter.

This half stays versioned with each project deliberately.
A global attributes file would apply the filter to every repository on the machine, third-party clones included, and rewrite their identifiers on `git add` with no warning.

## Step 2: the driver

It ships in `git/.gitconfig`, so a stowed machine already has it and a fresh clone needs nothing:

```
[filter "html-id"]
	clean = "perl -0777 -pe '...'"
```

Read the exact value with `git config --get filter.html-id.clean` rather than copying it from here; git escapes `\Q`, `\E` and the quotes when it writes the file, and a hand-edited copy is where that breaks.
Write it with `git config --file git/.gitconfig filter.html-id.clean '<value>'` and let git do the escaping.

The program collects the identifiers from the `gt` div and the `htmlwidget-` token alone, numbers each family in document order, `gt1` and `wdg1` upward, then rewrites every occurrence.
Numbering rather than collapsing onto a single token is what keeps the deliverable valid: the md-nesrine report holds fifteen `gt` tables in one file, and a shared id would make each style block apply to all fifteen at once.
Anchoring the collection on the div spares any other ten-letter identifier in the page, which is not hypothetical: that report carries `<section id="discussion">`, ten lowercase letters, untouched because it is never collected.

A `sed` one-liner did the job until 2026-09-12, collapsing instead of numbering.
Replacing it cost eds-prise 904 lines of pure renaming across twelve outputs, hidden from `git status` by git's stat cache until a render touched the files, and visible to `git add`, which re-reads and re-filters.

Numbering follows document order, so inserting a table upstream shifts the ones below it and produces a one-off churn.

## Step 3: renormalize the index

```bash
git add --renormalize -- '*.html'
git add .gitattributes
```

The normalization is itself a content change, so the tracked HTML land in the index modified and wait for a commit; the churn stops after it.
Restrict the pathspec: a bare `git add --renormalize .` also stages whatever else is modified.
The second command matters as much as the first, `.gitattributes` being untracked until then and therefore absent from a clone.

## Verification

```bash
git config --get filter.html-id.clean       # exact stored value
git check-attr filter -- <file>...          # mapping, including a file meant to stay out
git diff --numstat -- '*.html'              # after the commit: real changes only
```

To measure the gain before committing, pass both sides through the filter by hand and diff them:

```bash
f=<tracked-html>
CLEAN=$(git config --get filter.html-id.clean)
git show "HEAD:$f" | sh -c "$CLEAN" > /tmp/a.html
sh -c "$CLEAN" < "$f" > /tmp/b.html
diff /tmp/a.html /tmp/b.html
```

On md-nesrine this took the report from 940 diff lines to 6 (two prose edits, their echo in the code annex, the `sessioninfo` date) and each of the 15 `output/` tables from 55 to 0.
Idempotence is worth one check as well, two passes over the same file yielding the same sha1.

## Ways to lose it in silence

- A `gt` or `htmlwidgets` upgrade changing the identifier length, or the shape of the div the program anchors on.
- A machine where the `git` package is not stowed: git then stores the raw file without warning. That was the standing failure until the driver moved into the package on 2026-09-12, and it is what closed it.

## Settled elsewhere: the same churn on the OOXML artifacts

Diagnosed on md-nesrine 2026-09-02, and settled on 2026-09-12 by a `textconv` diff driver rather than by the clean filter this section prototypes.
The diagnosis below still holds; the remedy is `out-textconv`, documented in `git-out-textconv.md`.
Once the HTML are filtered, these files are the only remaining false signal after a render.

`.docx`, `.xlsx` and `.pptx` are ZIP archives, and a render rewrites them with no content change.
Comparing the tracked version against the rendered one, member by member, gives a single culprit each time:

```
| File   | Members | Differ | Cause                                       |
| ------ | ------- | ------ | ------------------------------------------- |
| .pptx  | 31      | 1      | dcterms:modified, plus the header mtimes    |
| .xlsx  | 8       | 1      | dcterms:created and modified, plus mtimes   |
```

Everything else is identical byte for byte, `ppt/slides/slide1.xml` and its 70 974 octets included.
The second source is the modification date the ZIP records in its headers for each generated member, which moves even when the payload does not.

The visible scope understates the real one.
On md-nesrine only the `.pptx` and the `.xlsx` show as modified, because `export_docx()` had not run since the last commit, but the 13 `output/tbl-*/*.docx` carry the same `dcterms:modified` and will churn together on its next run.

`sed` cannot reach inside a compressed member, so the remedy is a script rather than a one-liner.
Prototype, measured on the three formats: same sha1 from two renders of the same content, idempotent, ZIP integrity preserved, every member but `core.xml` round-tripping unchanged, member order kept.

```python
import re, sys, zipfile
from io import BytesIO

EPOCH = (1980, 1, 1, 0, 0, 0)
STAMP = re.compile(rb"(<dcterms:(?:created|modified)[^>]*>)[^<]*(</dcterms:)")

src = zipfile.ZipFile(BytesIO(sys.stdin.buffer.read()))
buf = BytesIO()
with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as dst:
    for item in src.infolist():
        data = src.read(item.filename)
        if item.filename == "docProps/core.xml":
            data = STAMP.sub(rb"\g<1>1980-01-01T00:00:00Z\g<2>", data)
        out = zipfile.ZipInfo(item.filename, EPOCH)
        out.compress_type = item.compress_type
        out.external_attr = item.external_attr
        dst.writestr(out, data)
sys.stdout.buffer.write(buf.getvalue())
```

That shape was never given, and the two reservations below are what dropped it.
The archive handed over is one no `officer` or `openxlsx2` run produced, even with every member intact, and `dcterms:created` of a `.docx` holds `2017-02-28` from the `officer` template, which the normalization flattens to the epoch along with the rest.
With no `smudge` the working copy keeps its real date, so only a clone or a `checkout` surfaces the flattened one.
Neither reaches a `textconv` driver, which rewrites nothing and only feeds `git diff`, so that is the route taken.

The point left unverified here is answered, and the answer is yes: `officer` varies more than `core.xml`.
`word/fontTable.xml` and the four `word/fonts/font*.odttf` move on every write, `officer::docx_embed_font()` drawing a fresh `w:fontKey` GUID that ODTTF obfuscation XORs into the first 32 bytes of each subset.
Measured 2026-09-12 on the eleven `output/tbl-*/*.docx` of md-nesrine: exactly 32 bytes differ per face, the payload identical, and `word/document.xml` byte-identical, so `rsid` values do not move.
