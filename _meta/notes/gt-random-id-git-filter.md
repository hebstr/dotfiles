# Silence the gt random id in git diffs

`gt` draws a fresh table identifier on every render, so the HTML written to `output/` differs from one run to the next with no data change, while the PNG and SVG come back to the same sha1.
A diff bearing on those files alone signals nothing, and it drowns the real changes: on the md-nesrine report, 934 of 940 diff lines were the identifier.

The remedy is a `clean` filter declared in `.gitattributes` and configured out of repo, which normalizes the identifier on its way into the index.
No `smudge`: the working tree keeps what `gt` writes, so the rendered page is untouched and the browser still sees a unique id per table.

Applied in eds-prise (2026-09-02) and md-nesrine (2026-09-02).

## The identifier and its two forms

`gt` emits ten lowercase letters and uses them twice, on the wrapping div and on every CSS selector scoping that table's style block:

```html
<div id="xjrgvihqto" style="padding-left:0px;...">
  <style>#xjrgvihqto table { ... }
#xjrgvihqto thead, #xjrgvihqto tbody, ... { ... }
```

## Step 1: declare the attribute

`.gitattributes`, tracked, at the repo root:

```
output/**/*.html filter=gtid
*_rapport-stat.html filter=gtid
```

The second line covers a Quarto document embedding its tables, and mirrors the glob `_quarto.yml` already uses so a re-dating of the report does not break it.
Scope the patterns: an extension's HTML or a vendored asset has no business going through the filter.

## Step 2: configure the filter

Two variants, both out of repo, so both are lost on a clone that does not repeat the command.

**One table per file** (eds-prise, where only `output/**` is tracked and each file holds a single `gt` table):

```bash
git config filter.gtid.clean 'sed -E '\''s/id="[a-z]{10}"/id="gt"/; s/#[a-z]{10}\b/#gt/g'\'''
```

**Several tables in one document** (md-nesrine, whose report embeds 17):

```bash
git config filter.gtid.clean 'perl -0777 -pe '\''my %m; my $n = 0; while (/<div id="([a-z]{10})" style="padding-left/g) { $m{$1} //= "gt" . ++$n } for my $k (keys %m) { s/(id="|#)\Q$k\E\b/$1$m{$k}/g }'\'''
```

The perl version subsumes the sed one and is the safer default.
It collects the identifiers from the `gt` div alone, numbers them in document order, then rewrites each on its two forms, which buys two things the sed cannot give.
Collapsing every table onto a single `id="gt"` would make the 17 style blocks apply to all 17 tables at once, and the anchoring on the div spares any other ten-letter identifier in the page.
That second point is not hypothetical: the md-nesrine report carries `<section id="discussion">`, ten lowercase letters, which the sed would rewrite into `id="gt"` alongside the tables and merge with them.

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
git config --get filter.gtid.clean          # exact stored value
git check-attr filter -- <file>...          # mapping, including a file meant to stay out
git diff --numstat -- '*.html'              # after the commit: real changes only
```

To measure the gain before committing, pass both sides through the filter by hand and diff them:

```bash
f=<tracked-html>
CLEAN=$(git config --get filter.gtid.clean)
git show "HEAD:$f" | sh -c "$CLEAN" > /tmp/a.html
sh -c "$CLEAN" < "$f" > /tmp/b.html
diff /tmp/a.html /tmp/b.html
```

On md-nesrine this took the report from 940 diff lines to 6 (two prose edits, their echo in the code annex, the `sessioninfo` date) and each of the 15 `output/` tables from 55 to 0.
Idempotence is worth one check as well, two passes over the same file yielding the same sha1.

## Two ways to lose it in silence

- A clone that has not repeated the `git config`: git then stores the raw file without warning.
- A `gt` upgrade changing the identifier length, or the shape of the div the perl variant anchors on.

## Deferred: the same churn on the OOXML artifacts

Diagnosed on md-nesrine 2026-09-02, nothing applied, the decision being to wait.
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

Shape to give it before use: an `ooxml-normalize` script in the stow package `bin`, beside `prose-lint`, so eds-prise and the next project can reach it; an unconditional pass-through when the input is empty or not a valid ZIP, a `clean` filter having no right to damage a file; `bats` tests on the three formats; then `output/**/*.{docx,xlsx,pptx} filter=ooxml` and `git config filter.ooxml.clean ooxml-normalize`.

Two things to weigh before spending that.
The archive handed over is one no `officer` or `openxlsx2` run produced, even with every member intact, and `dcterms:created` of a `.docx` holds `2017-02-28` from the `officer` template, which the normalization flattens to the epoch along with the rest.
With no `smudge` the working copy keeps its real date, so only a clone or a `checkout` surfaces the flattened one.

One point stayed unverified for want of two samples: whether `officer` varies anything besides `core.xml`, `rsid` values for instance.
The first `export_docx()` run after a commit settles it.
