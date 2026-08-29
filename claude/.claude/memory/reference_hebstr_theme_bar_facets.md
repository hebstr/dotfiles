---
name: hebstr theme_bar and faceted figures
description: hebstr's theme_bar(grid = FALSE) blanks strip.text and cannot be overridden through its own dots (argument collision); its palette is 3 colors so a 5-category ramp needs a darkened anchor
metadata:
  type: reference
---

Two things bite when building a faceted figure on the hebstr stack. Both verified 2026-08-07 in `eds-prise`, against the hebstr pinned in that project's `rv.lock`. The two scripts that carried the measurement have since been deleted, so they read through `git show` only: `2cfb009:scripts/fig_tte_delai.R` and `0ad59e5:scripts/fig_recueil_uf.R`.

## `grid = FALSE` blanks the facet strips, and `...` cannot put them back

`theme_bar(grid = FALSE)` is the house look (white panel plus `axis.line`, since the theme is additive over `theme_grey` and would otherwise keep the grey panel). Its body builds

```r
bg <- list(panel.background = element_blank(), axis.line = element_line(), strip.text = element_blank())
```

then returns `... %+replace% inject(theme(!!!bg, ...))`.

So `grid = FALSE` silently erases every facet title. The obvious fix, passing `strip.text` through the dots, fails outright:

```
Error in theme(...) : formal argument "strip.text" matched by multiple actual arguments
```

`bg` already binds `strip.text`, and `inject()` splices both into a single `theme()` call, where two arguments of the same name is an error rather than an override. The dots therefore only ever *add* elements `bg` leaves unset; they cannot override the three it sets.

Re-arm the strips as a separate layer after the theme, where `+ theme()` merges normally:

```r
theme_bar(grid = FALSE, legend_position = "bottom") +
  theme(
    strip.text = element_text(size = 9, face = "bold", hjust = 0),
    strip.background = element_blank()
  )
```

Same escape hatch for `panel.background` and `axis.line`.

## The palette carries 3 colors, so a 5-category ramp needs a darkened anchor

`get_opts()$color` is `base = "#999"`, `cold = c("#F0FAFF", "#0099FF")`, `warm = c("#FFF5F5", "#FF0000")`. `cold[2]` is the *light* end of a usable ramp, not its dark end: `colorRampPalette(rev(cold))(5)` puts the first two tones close enough to be indistinguishable in a stacked bar. Darken `cold[2]` first, and stop the ramp before its last tone, which collides with `base`:

```r
.fonce <- opts$color$cold[2] |> col2rgb() |> (\(x) rgb(t(x * 0.5), maxColorValue = 255))()
colorRampPalette(c(.fonce, opts$color$cold[1]))(n + 1) |> head(n)
```

Related: [[reference_hebstr_outdec_locale_flag]], [[feedback_review_severity_hebstr]].
