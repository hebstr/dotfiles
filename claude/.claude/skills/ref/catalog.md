# Ref Catalog

Index of available reference notes.
Each entry is `<domain>/<author>-<topic>.md`, followed by a one-line description of what the note covers and the upstream source it draws from.

When `/ref` is invoked without arguments, summarize the domains below and ask the user which one applies.

## Scope

`ref` only covers patterns **not already well covered** by an installed skill or MCP.
Currently it carries advanced patterns from named practitioners across two domains:

- **Quarto**: theming SCSS, Lua filters, RevealJS, multi-format extensions, academic manuscript templates, advanced authoring snippets (Pingfan, Canouil, Hvitfeldt, Heiss).
- **Biostat**: Bayesian modeling deltas beyond `r-skills:r-bayes` (Heiss); clinical summary tables with `gtsummary` (Sjoberg, Larmarange).

For general Quarto authoring, use `quarto:quarto-authoring`.
For R package development, lifecycle, testing, style, performance, see `r-lib:*` and `r-skills:*`.
For systematic reviews, see `litrev:*`.
For brand.yml and accessibility, see `quarto:brand-yml` and `quarto:quarto-alt-text`.

`ref` exists for the niches those skills do not cover: very specific patterns from named practitioners, with verbatim extracts and source citations.

## quarto/

- [pingfan-scss](quarto/pingfan-scss.md): Dark code-window patterns (traffic lights, header bar, line numbers, copy button). Source: `pingfan-hu/website`.
- [canouil-extensions](quarto/canouil-extensions.md): Multi-format Lua filter pattern with HTML, Reveal, and Typst code-window styling. Source: `mcanouil/quarto-code-window`.
- [hvitfeldt-revealjs](quarto/hvitfeldt-revealjs.md): RevealJS slide patterns: SCSS theming, fragments (CSS + JS), layout, `r-fit-text` traps, per-slide themes, fonts, ~25 `quarto-revealjs-*` extensions. Source: Hvitfeldt's Slidecraft 101.
- [hvitfeldt-extensions](quarto/hvitfeldt-extensions.md): Hvitfeldt's non-revealjs Quarto extensions (arrows, timeline, tegaki, designmode, color-classes) with verbatim usage and target formats. Source: `EmilHvitfeldt/quarto-*` repos.
- [heiss-extensions](quarto/heiss-extensions.md): Heiss's multi-format extensions (`quarto-wordcount`, `quarto-output-styling`, `fancy-epigraphs-quarto`, `quarto-footnote-styles`) with target formats, `_extension.yml`, activation patterns. Source: `andrewheiss/*` repos.
- [heiss-templates](quarto/heiss-templates.md): Heiss's `hikmah-academic-quarto` starter: 5 formats (PDF, manuscript-PDF/docx/odt, response-Typst), fancy multi-author title block, biblatex-chicago integration. Source: `andrewheiss/hikmah-academic-quarto`.
- [heiss-snippets](quarto/heiss-snippets.md): Heiss's advanced Quarto patterns: separate bibliographies via `multibib`, programmatic chunk generation with `knitr::knit(text=...)`, TikZ → SVG with embedded fonts. Source: andrewheiss.com blog posts.
- *planned*: `multiformat` (`_extension.yml` patterns for shipping HTML + Typst + docx in one extension; sources: `mcanouil`, `posit-dev/quarto-cli`).

## biostat/

- [heiss-bayes](biostat/heiss-bayes.md): Heiss delta on `r-skills:r-bayes`: conditional vs marginal in multilevel brms, `re_formula` (NA/NULL/synthetic), linpred/epred/predicted taxonomy, Beta + Hurdle Lognormal families. Source: andrewheiss.com blog posts.
- [sjoberg-gtsummary](biostat/sjoberg-gtsummary.md): Clinical summary tables with `gtsummary` v2.5.0: Table 1 idioms, journal themes (JAMA/Lancet/NEJM/qjecon), `tbl_regression`/`tbl_uvregression`/`tbl_survfit`/`tbl_svysummary`, `inline_text()`, multi-backend output (gt/flextable/kableExtra/huxtable). Larmarange angle: `broom.helpers` escape hatch, `labelled` workflow, survey-weighted reporting, `ggstats::ggcoef_model`. Pharma/ARD axis: `cards`/`cardx` (de la Rua), `crane`/`tern` (insightsengineering/Roche), `tfrmt` (Fillmore/GSK) for CDISC submissions. Sources: ddsjoberg/gtsummary, larmarange/{broom.helpers,labelled,ggstats}, insightsengineering/{cards,cardx,crane,tern}, GSK-Biostatistics/tfrmt.
- *planned*: `epirhandbook` (R idioms from the Epidemiologist R Handbook, covering clinical epidemiology workflows).

## Out of scope (covered elsewhere, do not add)

The following topics were considered for `ref` but are well covered by installed skills.
Listed here to prevent re-considering.

- R package lifecycle, testing, style, performance, OOP, rlang, tidyverse → `r-lib:*` and `r-skills:*` cover these.
- Quarto authoring (YAML, callouts, citations, layout, conversion) → `quarto:quarto-authoring`.
- Bootstrap / frontend general → `frontend-design:frontend-design`.
- Systematic reviews, meta-analyses → `litrev:*`.
- Bayesian basics (brms setup, priors, multilevel formulas, AME via `avg_slopes`) → `r-skills:r-bayes` covers fundamentals; `ref` only carries advanced deltas (e.g. `heiss-bayes` for `re_formula` regimes, linpred/epred/predicted taxonomy, Beta/Hurdle families).
- R clinical tables alternatives to `gtsummary` (`tableone` by Yoshida; `compareGroups` by Subirana; `arsenal`/`tableby` by Heinzen, Mayo; `finalfit` by Harrison, Edinburgh; `bstfun` MSK theme by Lavery) → considered 2026-04-25, all skipped: either redundant with `gtsummary` (the chosen primary, see `sjoberg-gtsummary`), too narrow (institutional themes), or stagnant (no new patterns since 2022). Reconsider only if a project requires a non-`gtsummary` idiom (formula-first, Word-native, or institutional MSK theme).

---

## Adding a note

1. Place the file at `<domain>/<author>-<topic>.md`.
2. Start the file with a YAML front-matter declaring `domain`, `author`, `topic`, and a `sources:` list, required for `/ref --check` and `/ref --update` to audit the note. See `update.md` for the schema.
3. Add a one-line entry above under the matching `## <domain>/` section.
4. Format: `- [<author>-<topic>](<domain>/<author>-<topic>.md): <one-line summary>. Source: <repo>.` Use `Sources:` (plural) followed by a comma-separated list when the note aggregates several upstream repos/blogs.
5. Before creating a note, check the "Out of scope" list: if an installed skill already covers the topic, don't duplicate.

### Naming convention

- `<domain>`: top-level bucket (`quarto`, `biostat`, …). Lowercase, no hyphen, single word.
- `<author>`: single lowercase ASCII token identifying the primary author, no diacritics. Use whichever name is the recognized signature in the upstream community: usually family name (`heiss`, `hvitfeldt`, `sjoberg`, `canouil`, `larmarange`), occasionally given name when more recognizable (`pingfan`). One author per filename, and multi-author work uses the principal author; co-authors go in the note's frontmatter or first paragraph.
- `<topic>`: **single word, lowercase ASCII**, no hyphens, no redundant domain prefix (`extensions`, not `quarto-extensions`; `bayes`, not `bayes-marginaleffects`). Pick the angle that best summarizes the note (e.g. `scss`, `revealjs`, `templates`, `snippets`, `gtsummary`). If two notes from the same author would collide on a single-word topic, split them into more specific single-word topics rather than reaching for hyphens.
- A note must always have an author. If a pattern truly has no identifiable author, it is out of scope for `ref`: point to upstream docs instead.
