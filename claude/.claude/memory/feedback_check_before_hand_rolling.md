---
name: feedback_check_before_hand_rolling
description: Before hand-rolling a generic helper, query the installed library for an existing one; training memory has a directional bias toward stale idioms and the lint/test gate never catches the duplicate
metadata:
  type: feedback
---

Before writing a helper whose body is generic mechanics, query the installed dependency for a function that already does it. The rule itself is unconditional and lives in `~/.claude/CLAUDE.md` (Coding preferences); the per-language commands are in `rules/r.md` and `rules/python.md`. This memory holds the why and the failure shape.

## Why

Incident, 2026-08-29, hebstr `easy_out()`. I wrote a `.kebab()` helper by hand (`str_replace_all` + `str_remove_all` + `tolower`) to normalise a filename. stringr, already in the package `Imports`, exports `str_to_kebab()` since 1.6.0 (packaged 2025-11-03), alongside `str_to_snake()` and `str_to_camel()`. My prior held that stringr stopped at `str_to_upper`/`lower`/`title`/`sentence` and that kebab conversion lived in `snakecase`/`janitor`. The user caught the duplicate, not me, after the feature had shipped through the full gate.

Four properties make this failure mode specific:

1. **The bias has a direction.** Training memory under-knows what shipped recently and over-trusts the idiom that was current when it formed. It is not random noise to be hedged against; it is a systematic tilt toward the older answer, which the user names as "réchauffé de slop stackoverflow-ish à son prime en 2012".
2. **The failure is silent.** The hand-rolled version works, passes `air`/`jarl`, passes the tests, passes `R CMD check`. No linter reports "this duplicates a library function". Absent a deliberate check, nothing surfaces it, which is why the trigger has to be mechanical rather than a judgement call at review time.
3. **On-disk absence is not absence.** The local check covers the installed packages and nothing else, so stopping there reproduces the reasoning-from-absence failure of [[feedback_verify_before_claiming]] (rule 2) in a new place: not a false claim this time, a hand-rolled helper justified by a search that could not have found the answer. The escalation is ordered rather than parallel, because disk and web answer different questions: disk says "already in my dependencies" and licenses immediate use, web says "elsewhere in the ecosystem" and licenses a proposal only.
4. **The ground truth is local and free, in R.** The installed package carries both its export list and its own `NEWS.md`, so two commands, roughly a second, answer both "does it exist" and "when did it arrive" without a single web request. In this incident the NEWS grep returned the exact release line and date. A Python wheel usually ships the export list alone, so only the first question has a local answer there and the currency half costs a web request.

Distinct from [[feedback_verify_before_claiming]], which governs *stating* a fact. Here nothing false was asserted; code was written without asking a question that had a local answer. Both share one root: recall is a pointer to where to look, never a source.

## How to apply

- **Trigger**: about to define a function whose body is generic mechanics (string casing or normalisation, path manipulation, date arithmetic, set/dedup/sort operations, type coercion, validation, retry/backoff). Domain logic (a statistical pipeline, a business rule) has no library equivalent and needs no check.
- **Order**: grep the project first (an internal helper may already exist), then the libraries already in the dependency list, then the ecosystem indexes below. Each step is only entered when the previous one comes up empty, and only the first two license using what they find without asking.
- **Divergence is a legitimate outcome.** In this incident `str_to_kebab()` turned out to split letter-digit boundaries (`fig_km_5y` to `fig-km-5-y`, `suffix = "v2"` to `-v-2`), which the user rejected, so the hand-rolled rule stayed. What changed is its status: a comment names the divergence, a test pins it, and the surrounding code was still rewritten to use the library where it did coincide (`str_to_lower()` over base `tolower()`). Keeping your own version after the check is a decision; keeping it without checking is an oversight, and the two are indistinguishable in the diff.
- **Web escalation, ranked by source.** A bare search is worse than useless here: its top hits are years-old forum answers, which is the very stale idiom the discipline exists to defeat, laundered as research. Function-level documentation index first where the language has one, then the candidate library's own API reference. R has real cross-package indexes and Python has none, so the two rules files route differently; read the one for the language in hand rather than assuming a shared step. Measured on this incident: `search.r-project.org` queried for `str_to_kebab` returns the stringr NEWS entry directly, so that single request would have caught it even had stringr been absent from the library.
- **A hit outside the dependencies is a proposal, never an action.** Name the function, price it as one more dependency, put the hand-rolled alternative beside it, recommend, and let the user decide. Adding a dependency to save a few lines is not a call to make alone, and an escalation whose findings cannot be acted on is theatre.
- **A miss is a bounded negative.** Report "not found in <sources searched>", never "it does not exist"; a search yields no proof of non-existence. When the web is unreachable, write the helper and flag the unverified assumption explicitly rather than letting the check look done.
- **When the library function diverges, say so with measurements**, a comparison table over the real inputs, not an impression. That is what let the user rule in one round.
