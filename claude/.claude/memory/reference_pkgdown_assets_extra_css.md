---
name: pkgdown copies only pkgdown/assets/, and extra.css lands where extra.scss does not
description: In a pkgdown site, only `pkgdown/assets/` is copied to the site root, and `extra.css` is copied verbatim while `extra.scss` compiles into `deps/`; any relative `url()` written in the scss is broken by construction, silently
metadata:
  type: reference
---

Two mechanisms that look interchangeable and are not. Any rule holding a relative `url()` (a `@font-face`, a `background-image`) belongs in `pkgdown/extra.css`, never in `pkgdown/extra.scss`.

```
| Source file          | Handled by                          | Lands at                        | `url('fonts/x.woff2')` resolves to |
|----------------------|-------------------------------------|---------------------------------|------------------------------------|
| `pkgdown/extra.css`  | copied verbatim, linked from `head` | `<site>/extra.css`              | `<site>/fonts/x.woff2`   correct   |
| `pkgdown/extra.scss` | compiled into the bslib stylesheet  | `<site>/deps/bootstrap-N/*.css` | `<site>/deps/bootstrap-N/fonts/…`  |
```

The copy is `pkgdown:::data_template()`, filling `out$extra$css` from `path_first_existing(pkg$src_path, "pkgdown", "extra.css")`. Both files can coexist, and do in hebstr: the `@font-face` rules sit in `extra.css`, everything consuming a Sass variable (`$primary`, `$secondary`) stays in `extra.scss`.

**Only `pkgdown/assets/` is copied to the site root.** The customisation article states it outright ("Any files in `pkgdown/assets` will be copied to the website root directory"). No other directory under `pkgdown/` is recognised for this: a `pkgdown/fonts/` or `pkgdown/img/` is simply never copied, with no warning, and `pkgdown/favicon/` is a separate special case pkgdown handles itself. Subdirectories inside `assets/` are supported, so `pkgdown/assets/fonts/` serves at `<site>/fonts/`.

A Google font needs none of this: `template.bslib.base_font` / `code_font` in the object form `{google: "Fira Code"}` reaches `bslib::bs_theme()`, which bundles the family into `<site>/deps/<Family>-<ver>/` through `bs_theme_dependencies()`, downloaded at build time and served from the site afterwards, so no visitor reaches Google. The bare string form `code_font: "Fira Code"` is a plain CSS family name and bundles nothing. A font outside Google Fonts (Luciole) has to go through `pkgdown/assets/` plus `extra.css`; `sass::font_face()` via the YAML `{face: {...}}` shorthand does not help, it emits the rule and carries no html dependency, so it copies no file.

**Why this is worth a memory rather than a look at a sibling repo.** The failure is silent on both ends. pkgdown warns about nothing, and a `@font-face` whose `src` opens on `local("Family-Name")` renders correctly on the author's machine while 404ing for every visitor without the font installed. Measured in edstr on 2026-09-20: broken since 2026-03-26, five months, while hebstr sitting next to it carried the correct pattern the whole time. Looking sideways for the precedent only works when something prompts the look.

Verified 2026-09-20 against pkgdown 2.2.1, bslib 0.11.0, sass 0.4.10, by a real `pkgdown::build_site()`. Full record, rejected options and the CI consequence of the Google route: `R-edstr/.claude/DESIGN-FONTS.md`. Other pkgdown trap in the same family: [[reference_pkgdown_ignores_rbuildignore]].
