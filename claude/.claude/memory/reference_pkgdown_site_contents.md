---
name: What reaches a published pkgdown site, and what stays on it
description: "Two pkgdown traps about the contents of docs/: it ignores .Rbuildignore entirely, so every *.md at the package root becomes a page and every vignette an article, with no config key to exclude them, only the file's location; and build_site() writes but never deletes, so a renamed or removed export keeps a live page until clean_site() runs"
metadata:
  type: reference
---

## `.Rbuildignore` does not keep a file off the site

`pkgdown:::package_mds()` globs every `*.md` at the package root plus `.github/`, and drops only `README.md`, `NEWS.md`, `LICENSE.md`/`LICENCE.md` and three hardcoded names (`issue_template.md`, `pull_request_template.md`, `cran-comments.md`). It never reads `.Rbuildignore`, and `build_home_md()` consults no `_pkgdown.yml` key, so **there is no configuration escape hatch**: a working file left at the root is published to the site. Same family of trap as vignettes, which pkgdown builds as articles regardless of `.Rbuildignore` (see [[project_edstr_vignettes_pkgdown_articles]]).

Symptom that reveals it: the published page is titled `NA` (`<title>NA • pkg</title>`, `<h1>NA</h1>`) when the source file carries no level-1 heading, since pkgdown has nothing to derive a title from.

The only lever is location. Move dev-only markdown into `dev/` and buildignore the directory (`^dev$`), which also covers anything added there later and pre-empts the "Non-standard file/directory found at top level" NOTE. Deleting the generated `docs/<name>.html` and `docs/<name>.md` is not enough: `search.json` and `sitemap.xml` keep indexing the page until `pkgdown::build_site()` reruns.

Verified empirically in hebstr on 2026-07-22 against pkgdown 2.2.0 (a root `TODO.md`, already `.Rbuildignore`d and gitignored, was being served as a site page).

Side effect when the moved file is a `TODO.md`: [[reference_todo_sync]] still finds it (`fdfind` at any depth, `--no-ignore-vcs`, so gitignoring `dev/` does not hide it), but its project label is derived from the last two path segments, so the row shows `<pkg>/dev` instead of `<parent>/<pkg>`. Cosmetic only.

## `build_site()` never removes a dead page

`pkgdown::build_site()` writes and overwrites, it never removes: the reference page of a topic that no longer exists survives every rebuild, so a renamed or deleted export leaves a live page on the published site with nothing in the build log about it.

Measured on hebstr on 2026-09-15: `clean_site()` followed by `build_site()` dropped the pages of `add_code_file`, `easy_out_map` and `easy_view`, which repeated bare `build_site()` runs had kept. Run `clean_site()` first whenever a rebuild follows a rename or a removal, and check the published site rather than the log.

The same build emits three `[WARNING] Deprecated: --mathml`: `rmarkdown:::pandoc_math_args` (rmarkdown 2.32) still passes `--mathml` to pandoc 3.10. Upstream defect, no effect on the output, nothing to fix locally.

Other pkgdown trap, on the assets rather than the pages: [[reference_pkgdown_assets_extra_css]].
