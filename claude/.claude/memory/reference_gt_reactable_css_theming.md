---
name: gt refuses CSS variables, reactable accepts them
description: "Aligning HTML tables on a Quarto dark theme: gt validates every colour option and rejects var()/currentColor/inherit, so only an !important override reaches it, while reactable passes theme strings straight through"
metadata:
  type: reference
---

Measured 2026-09-04 in eds-prise, on `gt::tab_options(table.background.color = )` via `as_raw_html()`.

`gt` runs every colour option through `html_color()` before compiling its SCSS. Rejected with `An invalid color name was used`: `var(--x, #333)`, `currentColor`, `inherit`. Accepted: hex including 8-digit alpha, CSS3 colour names, and `transparent`. So a gt table can be told to paint nothing, but it can never be told to follow a theme token, and `theme_gt(base =, color =, bg =)` cannot carry a `var()`.

`reactable` does not validate: `reactableTheme(color = "var(--bs-body-color)")` lands verbatim in the widget payload and resolves in the DOM. Alignment at the source is therefore open on reactable and closed on gt, which is why one goal legitimately takes two mechanisms.

Overriding gt from a stylesheet always needs `!important`. It emits `#<generated id> .gt_table`, specificity (1,1,0), and no id-free selector can outrank an id whatever its class count. Contrast [[reference_hebstr_gt_table_width]], where the cap needs no marker because `max-width` and `width` are different properties.

The surface is small: a gt style block carries 24 colour declarations for 5 distinct values, 3 of them visible, the other 2 sitting on borders whose style is `none`. Under `hebstr`'s `theme_gt()` they are `#333333` (`base`: text and the visible rules), `#F0FAFF` (`color`: table background) and `#FFFFFF` (`bg`: headers, striped rows, footnotes).

Placement under Quarto: a rules block in the dark theme file needs no `.quarto-dark` scope, since Quarto keeps both compiled sheets in the page and marks the inactive one `rel="disabled-stylesheet"`. `body.quarto-dark` / `body.quarto-light` do exist, set by the toggle, for rules that must live in a shared sheet.

Unrelated trap found in the same pass: `gt::as_raw_html()` calls `juicyjuice::css_inline()`, which loads V8. On a machine whose V8 build wants a missing `libnode.so.109` the call dies, while a Quarto render is unaffected, knitr printing gt through a `<style>` block rather than inlined styles.
