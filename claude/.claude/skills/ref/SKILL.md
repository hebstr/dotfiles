---
name: ref
description: "Invoke ONLY when the user explicitly types `/ref`: do not auto-trigger on mentions of 'reference', 'documentation', 'example', author names, or related vocabulary. Curated external reference library of patterns for niches not covered by installed skills: currently Quarto (theming, extensions, academic templates, advanced snippets) and biostatistics (Bayesian modeling deltas beyond r-skills:r-bayes; clinical summary tables with gtsummary). Without arguments: read `catalog.md` and ask the user what they're working on. With arguments (canonical form `/ref <domain> <author> [<topic>]`, e.g. `/ref quarto pingfan scss`): read the matching note directly. Supports `/ref --check` and `/ref --update` to audit and refresh notes against their upstream sources."
allowed-tools: Read, Edit, Glob, Grep, Bash, WebFetch
---

# Ref

Curated reference library.
Each note is a short markdown file (30–250 lines, see "Extending the library") that **inlines real extracts** from public repositories of active practitioners and **cites the source** (repo + file path).

The point: ground design choices on the work of people who actually ship, not on training memory.

## Invocation

This skill only runs when the user types `/ref ...` explicitly; it is not auto-triggered by semantic description matching.
If you arrived here through anything other than an explicit `/ref` invocation, stop and ask the user what they actually want.

Canonical form: `/ref <domain> <author> [<topic>]`. The author always sits between the domain and the topic.

- `/ref`: read `catalog.md`, summarize the available domains and topics, then ask what the user is working on before reading any note.
- `/ref <domain>`: list authors and topics available in that domain (from `catalog.md`), then ask which one.
- `/ref <domain> <author>`: if exactly one fiche is prefixed `<author>-`, open it. Otherwise list the matching fiches as `<topic>: <one-line summary from catalog.md>` and ask. If no fiche is prefixed `<author>-`, grep the author name across the frontmatter and body of the domain's notes: co-authors and secondary contributors live in the body of a primary fiche (e.g. `larmarange` is treated as a co-author angle inside `biostat/sjoberg-gtsummary.md`, not a separate fiche). When found by grep, point the user to the section, not the whole note.
- `/ref <domain> <author> <topic>`: open `<domain>/<author>-<topic>.md` directly. Examples: `/ref quarto pingfan scss`, `/ref quarto heiss extensions`, `/ref biostat heiss bayes`.
- `/ref --check [filter]`: audit notes against their upstream sources (no edits). Read `update.md` for the protocol.
- `/ref --update [filter]`: audit + propose diffs and metadata bumps fiche by fiche. Read `update.md` for the protocol. Add `--batch` to skip per-fiche confirmation.

When the requested `<topic>` does not match a filename exactly, fall back to fuzzy matching against the catalog entries for `<domain>/<author>-*.md` (substring match on the topic suffix) and confirm the chosen note with the user before reading.

When invoked with `--check` or `--update`, do not summarize `catalog.md` or display note bodies to the user: read `update.md` and follow that protocol instead. The protocol itself reads each note's YAML front-matter to perform the audit; that is required, not forbidden.

## Applying a pattern from a note

- Always cite the source (repo + file path) when applying a pattern. The user wants traceability, not paraphrase.
- If a note inlines an extract, apply that extract verbatim and adapt only what the user's context requires. Do not rewrite from memory.
<!-- Vendored repos: future feature, not implemented. When a note's frontmatter declares `vendored: <repo-path>`, read referenced files from `~/.claude/references/<repo>/` instead of fetching upstream. No repos are vendored yet: all current notes are self-contained. -->

## Extending the library

Adding a note is three steps:

1. Create `<domain>/<author>-<topic>.md` with a YAML front-matter (`domain`, `author`, `topic`, `sources:` list) followed by the inlined extract and cited sources. The front-matter is required for `/ref --check` and `/ref --update` to audit the note: see `update.md` for the schema.
2. Add a one-line entry under the matching domain in `catalog.md`.
3. Verify with `/ref --check <domain> <author>` (or `<domain> <author>-<topic>`) that the note's sources resolve correctly.

No build, no code: pure markdown.
Keep notes between 30 and 250 lines. The ceiling is there so a note stays one angle on one author's work, readable in a single pass when `/ref` opens it; a note that runs past it is usually covering several angles and should be split by sub-topic, under the single-word topic rule above. Inlined extracts are what make these notes worth reading, so length alone is not the trigger: a long note covering one angle is fine, a short one covering three is not.

### Naming convention

Filenames follow `<domain>/<author>-<topic>.md`:

- `<author>`: single lowercase ASCII token identifying the primary author, no diacritics. Use whichever name is the recognized signature in the upstream community: usually family name (`heiss`, `hvitfeldt`, `sjoberg`, `canouil`, `larmarange`), occasionally given name when more recognizable (`pingfan`). One author per filename: co-authors go in the note's first paragraph.
- `<topic>`: **single word, lowercase ASCII, no hyphens**. Pick the angle that best summarizes the note (`scss`, `revealjs`, `extensions`, `templates`, `snippets`, `gtsummary`, `bayes`). No redundant domain prefix (`extensions`, not `quarto-extensions`). If two notes from the same author would collide on a single-word topic, split them into more specific single-word topics rather than reaching for hyphens.
- Every note must have an author. A pattern with no identifiable author is out of scope: point to upstream docs instead.

## Layout

```
~/.claude/skills/ref/
├── SKILL.md
├── catalog.md
├── quarto/
│   ├── pingfan-scss.md
│   ├── canouil-extensions.md
│   ├── hvitfeldt-revealjs.md
│   ├── hvitfeldt-extensions.md
│   ├── heiss-extensions.md
│   ├── heiss-templates.md
│   └── heiss-snippets.md
└── biostat/
    ├── heiss-bayes.md
    └── sjoberg-gtsummary.md
```

Active domains: `quarto/` (theming, extensions, multi-format, academic templates, advanced snippets) and `biostat/` (Bayesian modeling deltas, clinical epidemiology, summary tables). See `catalog.md` for the current list of notes and the "Out of scope" section listing topics already covered by installed skills.
