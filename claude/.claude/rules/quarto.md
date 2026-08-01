---
paths:
  - "**/*.qmd"
  - "**/_quarto.yml"
  - "**/_quarto.yaml"
  - "**/_metadata.yml"
  - "**/_metadata.yaml"
  - "**/_brand.yml"
  - "**/_extension.yml"
  - "**/_quarto-*.yml"
---

# Quarto toolchain

## CLI tools

| Tool | Role |
|---|---|
| `quarto render` | Render a document or project to its output (HTML, or PDF via Typst) |
| `quarto check` | Verify the installation. Targets: `install`, `knitr`, `jupyter`, `julia`, `versions`, `all` (no `typst` target; the bundled Typst version shows under `versions`) |

Quarto ships no formatter or linter of its own. `panache` (Rust LSP + formatter + linter for Markdown/Quarto/Rmd) fills that gap when installed: it formats Pandoc/Quarto prose and delegates embedded chunks to `air`/`ruff` for formatting and to `jarl`/`ruff` for linting (`[formatters]` and `[linters]` in the config). Global config is stowed at `~/.config/panache/config.toml` with `wrap = "semantic"` (one sentence per line, no reflow). A project `panache.toml`, discovered by walking up from each file, **replaces** the global config wholesale instead of merging with it: every key it omits falls back to panache's own defaults, so a delta-only project config silently reverts `wrap` to `reflow` and destroys the one-sentence-per-line convention. Copy `_meta/profiles/panache.toml` from the dotfiles repo in full and edit from there; never write a project config that carries only the keys that differ. Directory traversal honors `.gitignore` inside a git repo and a built-in exclude base (`.git`, `node_modules`, `target`, `dist`, `build`, `_site`, `_freeze`, `renv`, `.venv`, `.cache`, `.Rproj.user`, `_book`, `**/LICENSE.md`), so a project config should use `extend-exclude` for extra paths: a bare `exclude` replaces that base instead of adding to it. Exclude patterns govern traversal only; a file named explicitly on the command line bypasses them unless `--force-exclude` is passed. That flag honors whichever config is in force, but exclude patterns anchor to the directory holding that config, so the global copy anchors at `~/.config/panache/` and matches nothing inside a project tree: the flag applies and finds no pattern to hit. Only a config sitting at the project root makes it bite, whether discovered as `panache.toml` or named with `--config`. Pointing `--config` at the global copy therefore changes nothing, its location being the variable rather than its content. The LSP hands panache one open document, the same shape as an explicit command-line path, so the anchoring rule above governs it too: a global-only exclude protects nothing on save, and only a config at the project root does. Positron sets `editor.formatOnSave` with `jolars.panache` in the `[markdown]` and `[quarto]` blocks, filters format-on-save by language id rather than by path glob, and the extension exposes no ignore setting of its own, so there is no editor-side way to spare a directory short of turning the language's `formatOnSave` off. Both shipped configs still carry `**/.claude/**`, which covers a traversal sweep; the glob needs its `**/` prefix, since exclude patterns are root-anchored and a bare `.claude/**` misses a nested `.claude/`, and the right-hand `**` is what reaches a nested `memory/` or `skills/` where a `*.md` would stop at depth one. A config change reaches the LSP only after a window reload. The `format-on-edit` PostToolUse hook runs `panache format --force-exclude` in place on authored `.md`/`.qmd` files (guarded by `command -v`, so `prose-lint` still runs if panache is absent); it deliberately skips any `.claude/` tree at any depth (Claude-facing markdown, the same scope `prose-lint` gets below), instruction files (`CLAUDE.md`, `rules/*.md`, matched at any path, not just the curated dotfiles copies), transient Claude notes (`memory/`, `PLAN.md`, `DEFERRED.md`, `*-context.md`), verbatim captures compared against a re-run (testthat snapshots under `_snaps/`, showboat traces under `_meta/notes/`), and any `.md` sitting beside a same-named `.Rmd`/`.qmd` (knitr/Quarto `github_document` output, desynchronised from its source by a reflow). The basename patterns are not redundant with the tree one: they catch a `PLAN.md` or a `CLAUDE.md` sitting outside any `.claude/`. That skip list is what protects those files, since the hook's own `--force-exclude` stays inert until the edited file's project ships a `panache.toml`; from then on the hook additionally honors that project's `extend-exclude` on the explicit path it passes. The hook gates `prose-lint` too: the stowed global config (`~/dotfiles/claude/.claude/`, i.e. this `CLAUDE.md` and `rules/*.md`) stays checked, but a project's own `.claude/` tree and root-level `*-context.md` notes are exempt from `prose-lint` as well (Claude-facing, not user prose). panache does NOT handle Typst, so a Typst-raw `.qmd` gains little and its `{=typst}` blocks should be checked to survive verbatim. The render gate is unchanged: a clean render plus the language gate on chunk code, plus `prose-lint` on a user-facing `.qmd` for the always-on dash rules (mechanical enforcement, not optional polish: see Prose conventions below). `prose-lint` stays mandatory; panache covers Markdown structure, not the em/en dash anti-AI-slop rules.

### What panache damages, and the escape hatches

Three constructs do not survive a format, all verified against panache 3.0.2 under `flavor = "quarto"`.

A pipe table whose cell holds a `|` inside a code span is **split into an extra column**, separator row included, which destroys the table. This is a panache defect, not a malformed source: Pandoc parses that cell correctly and emits `<code>|&gt;</code>` in two cells. Escaping as `\|` survives the format but leaks the backslash into Pandoc and Quarto output (GFM consumes it, Pandoc does not), so it trades a broken table for a wrong rendering. No extension toggle helps: `quarto-inline-code`, `rmarkdown-inline-code` and `inline-code-attributes` leave the break in place, and `pipe-tables = false` escapes every pipe and reduces the table to paragraphs. The escape hatch is the table syntax: a grid table and a raw HTML table both round-trip byte-identical with the pipe unescaped, and both render correctly.

A tab inside a fenced code block becomes four spaces, which breaks a `makefile` recipe and desynchronises a showboat ```` ```output ```` capture from what a re-run emits. Nothing escapes this one, fences included; only a skip covers it.

An em dash and an en dash in prose are rewritten to `---` and `--`. Pandoc's `smart` extension restores them on render, so output is unaffected, but the source character is gone, which matters in a file whose subject is the dash rule itself.

Everything else probed survives untouched: YAML front matter, `{=typst}` raw blocks, `{{< >}}` shortcodes, callouts, definition lists, line blocks, footnotes, inline math, links, and images with attributes. Inline `$$...$$` is promoted to a three-line block, which is cosmetic.

Fenced content is otherwise inert, including a fence nested inside a list item, so a table or an equation written inside ``` survives any reformat. That is the convention for Claude-facing markdown under `.claude/`, stated as a rule in `CLAUDE.md`, where nothing renders the file and the semantic loss costs nothing. Never apply it to a rendered document, where it would forfeit the real table.

The convention and the hook's `.claude/` skip are not redundant, they cover different callers. The skip stops panache on Claude's own edits; the editor's format-on-save reaches the same file through the LSP, which no skip and no global exclude can gate, and there the fence is what survives. Neither covers the other's gap either: a tab inside a fence is still rewritten, and prose cannot be fenced at all, so an em dash in a `.claude/` note is protected by the skip alone.

## Mandatory pipeline after every create/edit

```sh
quarto render <file>.qmd
```

Substitute `<file>.qmd` with the file being edited. When the edit is to `_quarto.yml`/`_quarto.yaml` or any project-level config (book, website, multi-file report), the gate is instead a full-project render from the project root:

```sh
quarto render
```

A single-file render does not exercise project config (sidebar, book chapters, cross-references), so it gives a false pass on the exact edit that triggered the rule.

Check the exit code: non-zero means a broken document (invalid YAML front matter, a failing code chunk, a missing dependency, or an unresolved cross-reference or citation such as an undefined `@ref` or a missing bib entry). A clean render is the pass condition for the document itself; the prose still goes through `prose-lint` separately (see Prose conventions below).

`quarto check` diagnoses the environment (missing R/Python/Jupyter/Typst, version mismatch), not document content. Run it only when a render fails for a toolchain reason or on a `command not found`-class error, never after every edit. Scope it with `quarto check knitr` (R engine) or `quarto check jupyter` (Python engine).

For a fast pass while iterating, `quarto render <file>.qmd --no-execute` skips code execution (it still validates YAML front matter, so it is not a pure prose-only check). A task is not done until a render *without* `--no-execute` exits 0; never report a Quarto task complete on the strength of a `--no-execute` render.

## Code chunks

R and Python chunks inside a `.qmd` follow their own language rules: see `rules/r.md` and `rules/python.md` (idioms, and the `air`/`ruff` format+lint gate). `panache` applies the format+lint half in place: `panache format <file>.qmd` reformats chunk bodies through `air`/`ruff`, and `panache lint <file>.qmd` reports `jarl`/`ruff` diagnostics against the chunk's own line numbers. Prefer it over a scratch-file round trip. It delegates formatters and linters only, so Python's type-checking step has no panache equivalent: a substantive Python chunk still owes the `pyrefly check` of `rules/python.md`, run against a scratch copy of the chunk body. Where panache is unavailable, copy a substantive chunk body (same threshold as the file-edit gate in `CLAUDE.md`) to a scratch `.R`/`.py` file, run the language gate from `rules/r.md`/`rules/python.md`, then paste the formatted result back. Either way, re-render *without* `--no-execute` afterwards to confirm the chunk still executes: reformatting can shift the chunk's indentation or disturb the fence boundaries, and a `--no-execute` pass validates YAML but not chunk execution, so it would give a false pass on exactly that breakage. Skip for trivial chunks (a single plot or `mutate` call). Do not duplicate those conventions here.

The engine is set per project or per document (`engine: knitr` for R, `engine: jupyter` for Python); read it from the document YAML front matter or the project `_quarto.yml` `engine:` key. Match `quarto check <engine>` to whichever the document uses.

## Stylesheets

A theme or extension stylesheet (`.scss`, `.css`) has its own gate: see `rules/css.md`, which also documents why the Quarto region markers (`/*-- scss:defaults --*/` and friends) constrain what the linter may be allowed to rewrite.
CSS written inside the `.qmd` itself, a `<style>` block or an inline chunk, stays under this file instead: the render is what validates it, and no stylesheet gate reaches it.
Generated CSS is out of both scopes: `_site/`, `*_files/libs/` and `_freeze/` are build output, never linted and never formatted.
A theme edit does not end at the CSS gate either. `stylelint` and `prettier` say nothing about whether a rule survives Quarto's own higher-specificity defaults, so the consuming document must still render and the compiled CSS be read back (see `feedback_verify_quarto_theming.md`).

## Prose conventions

- One sentence or logical unit per line; no manual soft wraps (matches the global Markdown rule). Quarto renders a single source newline as a soft break, so source line breaks do not change the output.
- On a user-facing `.qmd`, `prose-lint <file>` is the mandatory mechanical check (dashes); `panache` handles the soft-wrap reflow (`wrap = "semantic"`); `/workflow:write` is optional deeper polish and anti-AI-slop review. `panache` and `/workflow:write` apply to authored documents only, never to this rules file; `prose-lint` does cover it, since the stowed global config stays checked.

## Pre-commit hook (prek)

The dotfiles repo's root `prek.toml` carries a local `panache-format` hook (`entry = "panache format"`, `language = "system"`) scoped to `\.(md|qmd)$`.
It excludes `_meta/profiles/`, `claude/.claude/CLAUDE.md`, `claude/.claude/rules/`, and `claude/.claude/memory/`, so the hand-maintained instruction files and Claude's working notes keep their layout, plus `_meta/notes/` and `claude/.claude/skills/`, which hold verbatim content panache would corrupt: it rewrites every tab inside a fenced block to 4 spaces, which breaks a `makefile` recipe and desynchronises a showboat ```` ```output ```` capture from what a re-run emits.
That is close to, but not the same as, the skip set `format-on-edit.sh` applies: the edit hook additionally skips `PLAN.md`, `DEFERRED.md`, `*-context.md`, `_snaps/`, and `.md`-beside-source, and matches `CLAUDE.md`/`rules/*.md`, `_meta/notes/` and the whole `.claude/` tree at any path rather than under this repo's stow paths only, while prek is the only one of the two that excludes `_meta/profiles/`.
The tree-wide skip subsumes what prek spells out as `claude/.claude/skills/`, so a `SKILL.md` is now left alone by both gates, which is what the tab-rewriting hazard called for.
The hook rewrites in place, so a commit touching a drifted file fails once and leaves the reformat in the working tree, unstaged: `git add` it before the second commit attempt.
`prose-lint` stays a separate hook and covers the instruction files this hook excludes, `CLAUDE.md` and `rules/` (not `memory/`, which `prose-lint` self-skips): the two enforce different rules on different scopes.

The `_meta/profiles/prek.toml` scaffold carries the same hook for other projects, with `--force-exclude` added and with the exclude expressed in a generic project's layout (`.claude/`, `CLAUDE.md`/`PLAN.md`/`DEFERRED.md`/`LICENSE.md`, `*-context.md`) rather than this repo's `claude/.claude/` stow paths.
Its `(^|/)` anchoring makes each of those a basename match at any depth, so a `docs/CLAUDE.md` or a nested `LICENSE.md` is excluded too, where the root config's `^`-anchored patterns bind to one path.
`LICENSE.md` is listed even though the built-in base already covers `**/LICENSE.md`: that base governs traversal, prek names files explicitly, and `--force-exclude` stays inert until the adopting project ships its own `panache.toml`, so without the entry a licence body gets reflowed at commit. The dotfiles repo's own hook needs no such entry, holding no `LICENSE` file.
Its `prose-lint` hook excludes a project's `.claude/` tree and `*-context.md` for the same reason: the `prose-lint` script self-skips `.claude/memory/` and the working-file basenames, but not a project's `CLAUDE.md` or `rules/`, so the commit gate is where that scope is applied.
prek passes changed files explicitly, and an explicit path otherwise bypasses the config's exclude patterns, so the flag is what keeps `_extensions/**` out of the commit gate (it is committed by design, so `.gitignore` never covers it).
The flag stays off in this repo's root config, where it would be inert: it only takes effect once a project `panache.toml` is discovered, which is what the scaffold ships alongside.

## Feature syntax: defer to skills

Do not reconstruct Quarto feature syntax from memory (callouts, cross-references, citations, extensions, websites/books, theming, `_brand.yml`). Use the skills instead:

- `quarto:quarto-authoring` for authoring features, project types, and migration from R Markdown/bookdown/Jupyter
- `quarto:brand-yml` for `_brand.yml` branding
- `/ref quarto` for curated theming, extension, and academic-template snippets

## Useful flags

**quarto render**

| Flag | Effect |
|---|---|
| `--to FORMAT` | Render a single format (`html`, `pdf`, `docx`, ...) |
| `--no-execute` | Skip code execution (prose-only, faster while iterating) |
| `-P KEY:VALUE` | Pass an execution parameter |
| `-M KEY:VALUE` | Override a metadata value |
| `--cache` | Enable execution caching (`--no-cache` disables it; `--cache-refresh` forces a refresh of an existing cache) |
| `--output -` | Write rendered output to stdout |
| `--output-dir DIR` | Write output to a directory (input/project-relative) |

**quarto check**

| Flag | Effect |
|---|---|
| `--no-strict` | Do not fail on imprecise dependency-version matches |
| `--output PATH` | Write the report as JSON to a file (note: unlike `render`, `check` has no stdout `-` form) |

## References

- Quarto guide: https://quarto.org/docs/guide/
- Project config (`_quarto.yml`): https://quarto.org/docs/projects/quarto-projects.html
- Typst PDF backend: https://quarto.org/docs/output-formats/typst.html
