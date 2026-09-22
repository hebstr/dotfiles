---
name: feedback_check_before_hand_rolling
description: Before hand-rolling a generic helper, or before pricing a route as "we would have to build X", query the installed library for an existing one; training memory has a directional bias toward stale idioms and the lint/test gate never catches the duplicate
metadata:
  type: feedback
---

Before writing a helper whose body is generic mechanics, query the installed dependency for a function that already does it. The rule itself is unconditional and lives in `rules/code.md` (Before writing a helper), loaded on every code file; the per-language commands are in `rules/r.md` and `rules/python.md`. This memory holds the why and the failure shape.

## Why

Incident, 2026-08-29, hebstr `easy_out()`. I hand-rolled a `.kebab()` helper while stringr, already in `Imports`, exports `str_to_kebab()` since 1.6.0; my prior held that kebab conversion lived in `snakecase`/`janitor`. The user caught the duplicate after it had shipped through the full gate. The check then showed `str_to_kebab()` splits letter-digit boundaries (`fig_km_5y` to `fig-km-5-y`), which the user rejected, so the hand-rolled rule stayed as a documented, tested divergence. `search.r-project.org` queried for `str_to_kebab` returns the stringr NEWS entry directly, so one request would have caught it even with stringr absent.

Distinct from [[feedback_verify_before_claiming]], which governs *stating* a fact; both share one root: recall is a pointer to where to look, never a source.

## How to apply

- **When the library function diverges, say so with measurements**, a comparison table over the real inputs, not an impression. That is what let the user rule in one round.

## The same omission inside an arbitration, not inside code

Incident, 2026-09-11, md-nesrine and hebstr. Framing the fix for `gt` tables rendering unusably in Word, I priced the route "return a `flextable` under docx" as costing "a second implementation of the style to maintain alongside the `gt` one", and recommended a Lua filter patching third-party OOXML instead. The user proposed the flextable route anyway. `theme_ft()` was already exported by the package, documented in its own roxygen as "the Word-facing twin of `theme_gt()`", and `tbl_format()` already carried the exact `.is_docx()` branch to copy. The cost I had invented was zero, the recommendation was wrong, and the note recording it had to be rewritten the same day.

What generalises: the check is owed to any route being **priced**, not only to a helper being **written**. A cost stated as "we would have to build X" is a factual claim about the dependency surface, and it falls under [[feedback_verify_before_claiming]] like any other. Grep the package's exported surface and its existing branches before attaching a price to a route, because an invented cost does not merely waste the route, it steers the recommendation and everything written downstream of it.

Two aggravating shapes to watch for. The alternative you are about to under-price is often the one the *user* proposes, so a route arriving from them deserves the check before the objection, not after. And a route already launched is not evidence it was right: reversing here cost three notes rewritten, which is still cheaper than shipping a filter that patches vendor XML to work around a branch the package already had.
