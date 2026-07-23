---
name: pkgdown publishes root *.md and vignettes regardless of .Rbuildignore
description: pkgdown ignores .Rbuildignore entirely — every *.md at the package root becomes a published page and every vignette becomes an article; no config key excludes them, only the file's location does
metadata:
  type: reference
---

`pkgdown:::package_mds()` globs every `*.md` at the package root plus `.github/`, and drops only `README.md`, `NEWS.md`, `LICENSE.md`/`LICENCE.md` and three hardcoded names (`issue_template.md`, `pull_request_template.md`, `cran-comments.md`). It never reads `.Rbuildignore`, and `build_home_md()` consults no `_pkgdown.yml` key, so **there is no configuration escape hatch**: a working file left at the root is published to the site. Same family of trap as vignettes, which pkgdown builds as articles regardless of `.Rbuildignore` (see [[project_edstr_vignettes_pkgdown_articles]]).

Symptom that reveals it: the published page is titled `NA` (`<title>NA • pkg</title>`, `<h1>NA</h1>`) when the source file carries no level-1 heading, since pkgdown has nothing to derive a title from.

The only lever is location. Move dev-only markdown into `dev/` and buildignore the directory (`^dev$`), which also covers anything added there later and pre-empts the "Non-standard file/directory found at top level" NOTE. Deleting the generated `docs/<name>.html` and `docs/<name>.md` is not enough: `search.json` and `sitemap.xml` keep indexing the page until `pkgdown::build_site()` reruns.

Verified empirically in hebstr on 2026-07-22 against pkgdown 2.2.0 (a root `TODO.md`, already `.Rbuildignore`d and gitignored, was being served as a site page).

Side effect when the moved file is a `TODO.md`: [[reference_todo_sync]] still finds it (`fdfind` at any depth, `--no-ignore-vcs`, so gitignoring `dev/` does not hide it), but its project label is derived from the last two path segments, so the row shows `<pkg>/dev` instead of `<parent>/<pkg>`. Cosmetic only.
