---
paths:
  - "**/*.typ"
---

# Typst toolchain

## Scope: standalone `.typ` vs Quarto `.qmd`

This file governs standalone `.typ` files: Typst templates (`typst-template.typ`, `typst-show.typ`), show-rules, and local Typst packages.
It does **not** govern the body of a `.qmd`: Quarto generates a transient `.typ` from the `.qmd`, compiles it with its own bundled Typst, then deletes it.
A `.qmd` edit follows `rules/quarto.md` (the `quarto render` gate); the Typst editor tooling and the gate below never apply to the `.qmd` source itself.
To inspect the generated Typst from a Quarto doc, set `keep-typ: true` in the front matter, then open the preserved `.typ` under the editor tooling.

## CLI tools

| Tool | Role |
|---|---|
| `typstyle` | Formatter (`cargo install typstyle --locked`, at `~/.cargo/bin/typstyle`). `--check` to validate, `-i`/`--inplace` to rewrite |
| `typst` | Compiler (`/snap/bin/typst`). `typst compile <file>.typ` (smoke test), `typst watch` (live recompile). No `lint`/`check` subcommand exists. Snap-confined: it only reads paths under `$HOME`, so compile a smoke test in the project dir, not in `/tmp` |
| `tinymist` | Language server, bundled inside the Positron extension `myriad-dreamin.tinymist` (LSP, preview, completion, the linter, formatting via typstyle). Editor-only; not a CLI gate step |

There is no standalone Typst linter CLI: diagnostics live in `tinymist`, which surfaces them in-editor (config `tinymist.lint.enabled`).
The gate below therefore has no report-only lint step, unlike `rules/r.md` / `rules/rust.md`.

## Mandatory pipeline after every create/edit of a `.typ`

Run the gate when the edit meets the non-trivial threshold in `CLAUDE.md` (new file, new top-level `#let` function, logic change beyond ~10 lines or adding a branch); skip for one-line typo fixes.

Fixer-first ordering, matching the shared principle in `CLAUDE.md`:

```sh
typstyle -l 100 -i <file>.typ        # format in place
typstyle -l 100 --check <file>.typ   # confirm formatted (non-zero if not)
typst compile <file>.typ             # smoke test: does it compile?
```

The `-l 100` line width is not typstyle's default (80): it is set to match the editor and the commit gate (see Line width below).
For a no-mutation CI gate, run `typstyle -l 100 --check` alone (it exits non-zero when a reformat is required, mutating nothing).
A *hard failure* is `typst compile` exiting non-zero, or `typstyle --check` still reporting after `-i` ran.
On a hard failure, fix and re-run from the top at most once; if the second pass still fails, surface the residual error to the user.

`typst compile` writes a `<file>.pdf` next to the source; for a template or fragment not meant to render on its own, the compile step may legitimately fail on missing context.
In that case the format steps still apply, and the compile check is satisfied by rendering the consuming document instead (the `.qmd` via `quarto render`, or the entry-point `.typ`).

## Line width

typstyle's line width must agree across the three places it runs, or one reverts the other (the failure mode `rules/shell.md` calls out for shfmt).
The chosen value is **100**, set in all three:

- editor: `tinymist.formatterPrintWidth` in the active Positron profile (typstyle's default is 80, so this must be set explicitly)
- manual gate: `typstyle -l 100` (see the pipeline above)
- commit hook: `args = ["-i", "-l", "100"]` in `_meta/templates/prek.toml`

Changing the width means changing all three together.

## Pre-commit hook (prek)

The `_meta/templates/prek.toml` scaffold carries a `typstyle` hook (`typstyle-rs/pre-commit-typstyle`, scoped to `\.typ$`).
It runs `-i -l 100` (format in place at width 100; see Line width above), matching the formatter convention of the other hooks (`ruff-format`, `air-format`, `shfmt -w`), not a non-mutating `--check`.
Do not copy its `rev` here (it drifts; the template is the source of truth).
The dotfiles repo's own root `prek.toml` has no typstyle hook by design: that repo contains no `.typ` files.

## Editor tooling

Positron uses Open VSX; the `myriad-dreamin.tinymist` extension is published there and bundles its own server binary (no separate install, no `serverPath` config).
The legacy `nvarner.typst-lsp` and `typst-preview` are deprecated and folded into tinymist; never install them alongside it (two LSPs for one language conflict).
Settings live in the active Positron profile (`tinymist.formatterMode: "typstyle"`, `tinymist.lint.enabled: true`, plus a `[typst]` `formatOnSave` block).

## References

- Typst docs: https://typst.app/docs/
- typstyle: https://github.com/typstyle-rs/typstyle
- tinymist: https://github.com/Myriad-Dreamin/tinymist
- Quarto Typst backend: https://quarto.org/docs/output-formats/typst.html
