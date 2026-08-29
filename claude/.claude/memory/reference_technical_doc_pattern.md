---
name: "Documentation technique des scripts : plan de document réutilisable"
description: Pattern for a per-script technical doc (hebstr-doc Quarto, `{{< filetree >}}` + `{{< script >}}`), where comments leave the code and become titled callouts; carries the section plan, the CSS block and the traps
metadata:
  type: reference
---

Pattern established in `eds-prise` on 2026-08-23, when 271 lines of comment left 13 R scripts for a single document. Its perimeter has since grown past R: 37 files as of 2026-08-25, including nine Python modules, a Streamlit entry point and a shell launcher.
Reuse it whenever a project wants its scripts documented outside the code.
The project record, with its measurements and its scope decisions, stays in that project's `.claude/DESIGN-TECHNIQUE.md`.

## What it is

`technique.qmd` at the project root, `format: hebstr-doc-html`, one section per script.
Written for the author, not published with the study: `*.html` is normally gitignored, so only the source is versioned.

Prerequisite: the `hebstr-doc` extension, which contributes the two shortcodes `{{< filetree >}}` and `{{< script path >}}`.
`{{< script >}}` reads the file at render time, so the code shown never drifts. The prose does.

## Section plan, fixed

1. An informative H2 title, saying what the script does. **Not the path**: the folded code block's summary already shows it, and the filetree shows it again.
2. `{{< script chemin >}}`, placed before the prose. It costs one line: `code-fold: true` collapses every block behind a `Code` toggle.
3. The presentation: principle, what it consumes, what it feeds, what it produces (named output files), or the absence of output.
4. One H3 sub-section per `### SECTION ----` separator in the script, titled `` `SEPARATEUR` Titre informatif ``, the label first because that is how the reader arrives from the script. The separator is an R idiom but the rule is language-agnostic: a Python module carrying the same marker gets the same sub-sections, and it may be indented inside a function, where a `^###`-anchored grep misses it.
5. Inside a sub-section: one to three sentences, then one titled callout per migrated note.

Sub-sections follow the script's separators and are never invented, but they follow **all** of them: a separator whose content is obvious still gets its sub-section, carrying one or two sentences of presentation and nothing else. A reader arriving from the script by a separator must find something, and a silent gap says nothing about whether the block was obvious or the upkeep was skipped. A script with no separator stops at the presentation followed by its callouts.
Prose exists only where it adds to the callout; otherwise the sub-section is the callout alone.

## Callouts

Two natures, and two only, or the reader stops reading the nature as a signal.

- `.callout-note` carries the reasoning: why a value is measured rather than asserted, why an object lives here, what a column means.
- `.callout-warning` carries the trap: what breaks silently. A guard that fails without erroring, a sort whose loss only costs speed, a series readable in one direction only.

One callout per note, the title naming one object. Title format `objet : principe`, body developing it.

**Write the title as a level-3 heading, first line of the callout.** Quarto's filter consumes it (`-- the first heading is the title`): it emits no heading, stays out of the TOC, takes no section number, and section numbering continues across it, all verified.
Level 3 and not 4: a level 4 skips the hierarchy from `h2` to `h4` for callouts placed directly under a script title, which `panache lint` reports as `heading-hierarchy`, the linter not knowing Quarto consumes the heading.
The `title=` attribute renders identical HTML and escapes the formatter, but it locks the title inside a string where a straight quote needs escaping.

## What stays in the scripts

The `### SECTION ----` separators, and nothing else. They are a table of contents, and the document mirrors them. Count them with a leading `\s*`, never `^###`: an indented separator inside a Python function is still a separator, and missing it is how two real sub-sections got deleted as "invented" in `eds-prise` on 2026-08-25.
The narrow exceptions of the global CLAUDE.md (non-obvious regex, external-bug workaround, subtle invariant) do not survive: they become notes.
A commented-out block is not a comment in this sense. It holds a reserve, it stays in the script, it does not go to the document.

The migration is editorial, not a copy: pointer comments vanish into the presentation, neighbouring comments merge. Measured yield: about one note per three lines of comment.

## Document header and CSS

```
---
engine: markdown
toc-depth: 2
format:
  hebstr-doc-html: {}
---
```

`engine: markdown` because there is no computation: the document renders with no R session and no data.
`toc-depth: 2` because the sub-sections would otherwise add some sixty entries and the TOC would stop being a map; they stay numbered and anchored.

```css
h3 code:not(.sourceCode) {
  color: var(--code-comment-color) !important;
  background-color: var(--code-background-color) !important;
  font-size: 1rem !important;
  vertical-align: 0.08em !important;
}
.callout-title-container code {
  font-size: 1rem;
  font-weight: inherit;
}
```

The separator label borrows the code blocks' own tokens, so it reads as what it points at and follows the theme; both tokens hold the same value in the light and dark sheets, so no `.quarto-dark` variant is needed.
`h3 code:not(.sourceCode)` at `(0,1,2)` is the minimum that beats the theme's `code:not(.sourceCode)` at `(0,1,1)`, which marks `background-color` and `padding` `!important`; a plain `h3 code` wins on `color` and `font-size` and loses on the other two, which reads as half a rule applying.
`vertical-align` and not a margin: `code` is inline, vertical margins are inert there, and the inline box includes the monospace descender, which sinks the pill.
The callout title is bold except its inline code, which `code { font-weight: 400 }` resets; `inherit` restores it without `!important`.

## filetree.yml

Sidecar at the project root, top-level `filetree` key, then `paths` mapping relpath to a three-to-six-word annotation, plus `root`, `depth`, `exclude`, `highlight`, `hidden`, `mode`.
Exclude the render artefacts (`%.html$`, `_files$`), the data, the vendored trees and the user's personal files.
The filter warns on any `paths` key matching nothing rendered: that is the only automatic freshness guard of the whole device, and it covers the tree alone.

## Upkeep

Nothing links a section to its script. **Any edit to a script updates its section in the same response**, a rule that belongs in the project's `.claude/CLAUDE.md`, which carries only the delta from the global one.

See [[feedback_verify_quarto_theming]] for measuring computed styles before iterating on CSS, and [[reference_quarto_lua_shortcodes]] for the shortcode internals.
