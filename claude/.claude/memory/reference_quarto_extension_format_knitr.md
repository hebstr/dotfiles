---
name: Format-scoped knitr options in a Quarto extension
description: A Quarto extension can put `knitr: opts_chunk:` under a single format (not only under `common:`), which is how hebstr-doc scopes `dev: svglite` to HTML; plus svglite vs cairo evidence and the font-family caveat
metadata:
  type: reference
---

`knitr: opts_chunk:` placed under one format in an extension's `contributes.formats.<format>:` block reaches knitr, it is not restricted to `common:`.
Verified 2026-08-01 with a throwaway extension (`dev = svglite` read back from `knitr::opts_chunk$get()` in the rendered output) and again through `quarto-hebstr-doc` 1.3.0.

This is what makes a device choice scopeable. Putting `dev:` under `common:` would push it onto typst and docx too, where hebstr-doc sets `default-image-extension: png` and where docx cannot embed SVG without `rsvg-convert`.

## svglite vs the built-in cairo device

`fig-format: svg` alone resolves to `dev = svg`, R's cairo device. Same plot, both devices:

```
                 size     <text>   baked glyph paths
svglite         5.4 Ko      13             0
grDevices::svg 22.5 Ko       0            63
```

Cairo converts every label to vector paths: not selectable, not searchable, ~4x heavier, which compounds under `embed-resources: true`.

## `!expr` does not evaluate in `_extension.yml`

The tag survives literally and knitr hands the device `list(value = "...", tag = "!expr")`, which aborts the render with `unused arguments (value = ..., tag = "!expr")`. It does evaluate as a *cell* option in a `.qmd`. In extension metadata write a plain YAML map instead, which already converts to an R list:

```yaml
dev.args:
  system_fonts:
    sans: Luciole
```

Verified end to end: the generated SVG carries `font-family: "Luciole"`.

## Font traps

**svglite does not pick up `mainfont`.** It names R's own font family, so a default plot writes `font-family: "Liberation Sans"` even when the document is set to Luciole.

**A figure never reaches the page's webfonts, so no font work on the R side makes it self-contained.** Quarto inserts each SVG as `<img src="data:image/svg+xml;...">`, and an `<img>`-loaded SVG is an isolated document that the page's `@font-face` rules do not cross into (verified on `index_stat.html`: 19 `font-family` references, zero `@font-face`, all figures in `<img>`). Figure text resolves against the **reader's** installed fonts. Everything below settles what the SVG *claims* and how wide it lays out, never what a reader sees. Making figures self-contained needs the font embedded in the SVG (`svglite::font_face(..., embed = TRUE)` via `web_fonts`), measured at ~743 KB for one figure in `md-nesrine`, hence rejected there. svglite's own docs state this obliquely: web fonts mean "viewers of the final SVG will not need the font".

**svglite writes the family it MATCHED, not the one requested.** Asking for a font absent from the machine silently emits the fallback's name (verified: `sans = "NonexistentFontXYZ"` produced `font-family: "Noto Sans"`), along with its metrics, so even a reader who has the font sees the fallback. A format-level `system_fonts` alias is therefore a hard dependency on the render machine's installed fonts, degrading silently. Its worst case still equals the no-alias baseline, so it cannot regress a consumer.

**A `system_fonts` alias only moves the GENERIC families, it overrides nothing.** Verified four ways: under `sans: Luciole`, `par(family = "Fira Code")` writes `Fira Code`, while a plot naming nothing writes `Luciole`; with no alias, `par(family = "Luciole")` writes `Luciole` and a plot naming nothing writes `Liberation Sans`. An explicit family resolves through another path, so aliasing is safe for a theme extension.

**Naming the family explicitly does NOT survive a missing font.** Verified with an absent family: `par(family=)`, ggplot `base_family=` and the `system_fonts` alias all three write `Noto Sans`. Explicitness settles which family is asked for, never whether the machine can supply it, so it is no defence against an uninstalled font. Do not describe it as the robust route.

**`systemfonts::register_font()` is the route that survives**, and it is the current API (both svglite arguments are superseded in its favour). Verified with a family absent from the machine: registering the file makes the glyphs and metrics available. But svglite writes the font file's INTERNAL family name, not the registration alias (registering Font Awesome as `ZZTestFam` emitted `font-family: "Font Awesome 7 Free"`). That is harmless when the two agree, which is the case for the woff2 files hebstr-doc ships. Every face must be registered; an unregistered one falls back alone, usually visible on a bold title. Registration serves plots that name the family, not the generic: `system_fonts` does not consult the registry, so a plot naming no font still needs a real install.

**Both `system_fonts` and `user_fonts` are `[Superseded]`** in svglite, in favour of `systemfonts::register_font()`.

**An extension cannot execute R, but it can ship R.** Do not conflate the two: no Quarto hook runs R from an extension, yet a script shipped inside it and sourced by the consuming project works end to end (verified with a family absent from the machine, `.Rprofile` → source → knitr device, the SVG naming the bundled font instead of the fallback). `quarto-hebstr-doc` ships `fonts/register.R` on that basis. A sourced script locates itself by scanning `sys.frame(i)$ofile`, which keeps every font path internal to the extension and leaves the project one `source()` line; resolve paths against that directory, not against a hardcoded `fonts/` subpath, or moving the script silently doubles the segment.

**`register_font()` behaviour, all verified:**
- It **errors** on a family the system already provides (`A system font called 'Luciole' already exists`), so unconditional registration is impossible and a `%in% system_fonts()$family` guard is mandatory, not a design preference.
- Re-registering an already-*registered* family is a clean overwrite: no error, registry count stable. The two cases look alike and behave oppositely.
- A registered font never appears in `system_fonts()`, so the guard above does not catch it on a second pass. Idempotence comes from the overwrite, not the guard.
- A bad path fails only when the guard lets the call through, and argument laziness means the paths are not even evaluated when it does not. A path bug is therefore invisible on a machine that has the fonts and fatal on one that does not.

**`system_fonts` is a name→name alias, never a path.** Only `user_fonts` takes files, in the form `{name: <written in the SVG>, file: <path>}`, per face (verified: supplying only `plain` left the bold title on the fallback). It needs a path relative to the document, which differs between an extension's own repo (`_extensions/<name>/`) and a consuming project (`_extensions/<org>/<name>/`), so one value cannot be right in both.

**`dev.args` is replaced wholesale, not merged.** Verified with two chunks under a format-level alias: the one setting `dev.args` for another reason fell back to `Liberation Sans`. A chunk needing the transparent background that [[project_hebstr_doc_adaptive_figures]] requires must repeat `system_fonts` in the same call.

## Web font formats are not a font source for R or Typst

`quarto-hebstr-doc` ships `fonts/` as `.woff`/`.woff2` only, for `fonts.css` `@font-face`. Neither Typst nor systemfonts can browse that directory: `typst fonts --ignore-system-fonts --font-path <fonts/>` lists only Typst's four built-ins, and `systemfonts::add_fonts()` on it adds 0 rows to `system_fonts()`. Only `register_font()` / `user_fonts`, handed an explicit *file* path, decode a woff2 (`font_info()` then reports family Luciole with real metrics).

Consequence for the extension: its typst block's `font-paths: fonts` is inert, and PDF output silently relies on a system-installed Luciole.

## Dependency consequence

A Quarto extension cannot declare an R dependency, so a format-level `dev:` makes that package a silent render-time requirement for every consumer. Document it in the extension README and add it to each consuming project's `rproject.toml`; a machine where the package merely happens to sit in the user library will hide the breakage until a fresh checkout.
