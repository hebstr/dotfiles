---
paths:
  - "**/*.css"
  - "**/*.scss"
---

# CSS / SCSS toolchain

## Scope

This file governs hand-authored `.css` and `.scss`, the dominant case being Quarto theme files under `_extensions/*/` and pkgdown's `extra.scss`.
It does not govern CSS written inside a `.qmd` (a `<style>` block or an inline chunk): that path stays under `rules/quarto.md`, whose render gate is what validates it.
It does not govern generated CSS either: compiled Bootstrap under `_site/`, `*_files/libs/`, or `_freeze/` is build output, never linted and never formatted.

Sass is a means, not a goal: prefer native CSS (custom properties, nesting, `@layer`, `color-mix()`, `light-dark()`) and keep Sass to what Quarto's theming actually requires, which is `!default` variable overrides and the region layering below.

## CLI tools

| Tool | Role |
|---|---|
| `stylelint` | Linter (`~/.local/bin/stylelint`, symlink into the pinned toolchain). Linter only: it deprecated its 76 stylistic rules in v15 and removed them in v16, delegating whitespace to a pretty printer. `--fix` corrects and still exits 2 on what it cannot fix |
| `prettier` | Formatter (`~/.local/bin/prettier`, same mechanism). `--write` rewrites in place, `--check` validates without writing |

Both binaries come from a pinned toolchain in the `css` stow package, at `~/.local/share/css-gate/`, with `package.json` and `package-lock.json` tracked and `node_modules/` ignored.
Update it with `css-toolchain-update`, wired as the `css-toolchain` module of `sys-update`.
The bootstrap is traced in `_meta/notes/css-scss-gate.md`.

The gate has the same three-step shape as Python's, role for role: `stylelint --fix` is the fixer where `ruff check --fix` is, `prettier --write` the formatter where `ruff format` is, and a bare `stylelint` the validating pass where the second `ruff check` is.

## Mandatory pipeline after every create/edit

```sh
CSS_CONFIG="$HOME/.local/share/css-gate/stylelint.config.mjs"
stylelint --config "$CSS_CONFIG" --fix FILE
prettier --write --log-level warn FILE
stylelint --config "$CSS_CONFIG" FILE
```

Run the three steps in that order, not a subset: the first corrects, the second owns whitespace, the third is the validating pass whose exit code decides.
Do not chain them with `&&`: `stylelint --fix` exits 2 when unfixable violations remain, which is expected churn rather than a hard failure, and `&&` would skip the formatter.
Stylelint writes its formatted report to stderr, not stdout, so redirect with `2>&1` when piping.

Exit codes: `1` fatal error, `2` lint problem, `64` invalid CLI usage, `78` invalid configuration file.

The `format-on-edit` hook already runs this pipeline on every hand-authored `.css` / `.scss` edit, skipping the generated paths named above; the sequence here is for a manual or batch run.

## Config resolution

`--config` is mandatory and always points at the shared config.
The reason is mechanical: stylelint resolves `extends` and `plugins` relative to the config file's own directory, and the shared config sits beside its own `node_modules`, so the reference resolves from there.
A config placed anywhere else (a project root, a temp directory) fails with `ConfigurationError: Could not find "stylelint-config-standard-scss"` unless `--config-basedir ~/.local/share/css-gate` is added.
A project that needs its own rules should therefore either add that flag or vendor the packages itself.

Prettier needs no flag: a project-local `.prettierrc` wins when present, defaults apply otherwise, which is the intended behavior.

## Quarto region markers: the constraint that shapes the config

A Quarto theme file is split on comment markers that Quarto treats as layer boundaries: `/*-- scss:uses --*/`, `/*-- scss:functions --*/`, `/*-- scss:defaults --*/`, `/*-- scss:mixins --*/`, `/*-- scss:rules --*/`.
At least one must be present or the file is invalid, and each type is compiled into a separate layer, so the markers are load-bearing syntax wearing a comment's clothes.

`stylelint-config-standard-scss` enables `comment-whitespace-inside: "always"`, which flags those markers and, under `--fix`, rewrites them to `/* -- scss:defaults -- */`.
Quarto then rejects the file with `doesn't contain at least one layer boundary` and the render fails.
The shared config therefore sets `comment-whitespace-inside: null`, and that entry is a correctness requirement, not a style preference: removing it breaks every theme in the repo.

Two further consequences for any tooling added later:

- Never enable a declaration-sorting rule (`stylelint-order` and its order configs): moving a declaration across a region boundary changes its compilation layer and its `!default` override semantics.
- Never let a formatter reorder top-level nodes. Prettier does not, verified on a real 745-line theme where all markers survive byte for byte.

## Shared config

At `~/.local/share/css-gate/stylelint.config.mjs`, extending `stylelint-config-standard-scss` with three deviations:

| Entry | Why |
|---|---|
| `comment-whitespace-inside: null` | Quarto region markers, above |
| `selector-class-pattern` widened to camelCase | Pandoc emits `.sourceCode` and `.numberSource`, which cannot be renamed. The pattern stays strict on everything else rather than disabling the rule |
| `at-rule-disallowed-list: ["import"]` | Sass `@import` is deprecated since Dart Sass 1.80.0 and removed in 3.0.0. A Quarto render swallows the compiler's deprecation warning, so the gate is the only signal. Use `@use` |

Legacy Sass color functions need no rule of their own: `scss/no-global-function-names`, active in the preset, already reports `lighten`, `darken`, `transparentize`, `adjust-hue`, `map-get` and `nth` with the exact module replacement to use.

Known gap: legacy `/` division, deprecated in favor of `math.div()`, is caught by no rule in this gate, and a Quarto render does not surface the compiler warning either. It has to be caught by review.

## Positron

`esbenp.prettier-vscode` is the `[css]` and `[scss]` default formatter, with `editor.formatOnSave` on for those two languages only (the global setting is off).
It is not the gate's prettier: the extension resolves a workspace-local install when one exists and otherwise falls back to the copy it bundles, so it never reaches `~/.local/bin/prettier` unless `prettier.prettierPath` is set, and it is not.
A save therefore runs a possibly different prettier version and neither stylelint pass. Format-on-save is not a substitute for the pipeline above.

The `SomewhatStationery.some-sass` extension provides the SCSS language server: cross-file `@use` / `@forward` navigation, workspace-wide rename, SassDoc on hover.
Do not disable Positron's built-in CSS language features: in a VS Code fork, Some Sass defers by default to whatever `vscode-css-language-server` already covers, and that pairing is the supported arrangement.
Outside a VS Code fork, the opposite holds: run `some-sass-language-server --stdio` alone for `scss`/`sass` and do not also attach a CSS server, or go-to-definition and color decorators come back doubled.

Running stylelint through an LSP is not the practice here: the CLI is what the gate uses.

## PATH caveat

`~/.local/bin/stylelint` and `~/.local/bin/prettier` are stow symlinks into the pinned toolchain, so a bare `stylelint` resolves to the machine-wide version even in a repo that carries its own `node_modules/.bin`.
`quarto-hebstr-doc` is such a repo. In any repo holding its own install, invoke `node_modules/.bin/stylelint` (or `npx stylelint`) to stay on that repo's pinned versions; the machine-wide pair is for repos with no local install.

## Commit gate (prek)

There is no usable upstream hook: stylelint publishes no `.pre-commit-hooks.yaml`, `pre-commit/mirrors-prettier` is archived, and `awebdeveloper/pre-commit-stylelint` is unmaintained.
Local system hooks are the only option, and one constraint decides their shape.

**prek execs `entry` without a shell, so it performs no tilde or variable expansion.**
An `entry` containing `~/.local/share/css-gate/...` reaches stylelint verbatim and resolves against the repo root, failing with `ENOENT`.
Any path inside `entry` must therefore be absolute, which makes it machine-specific and unfit for a committed config.

Repo-relative paths do work, because prek runs hooks with the repo root as working directory.
So the shape to use points at the repo's own toolchain and lets stylelint discover a config at the repo root:

```toml
{ id = "stylelint", name = "stylelint (.css/.scss)", entry = "node_modules/.bin/stylelint --fix", language = "system", files = '\.s?css$', exclude = '^(_site/|_freeze/)|_files/' },
{ id = "prettier", name = "prettier (.css/.scss)", entry = "node_modules/.bin/prettier --write --log-level warn", language = "system", files = '\.s?css$', exclude = '^(_site/|_freeze/)|_files/' },
```

Pinning the repo's own binaries rather than the PATH ones means a collaborator running `npm ci` gets the same versions, and it sidesteps the PATH shadowing below entirely.

The `--fix` hook doubles as the validator: it rewrites what it can and exits non-zero on the rest, the same shape as Python's `ruff check --fix`.

That shape requires the repo to carry both a `stylelint.config.mjs` and the packages its `extends` resolves against, which means a repo-local `package.json` plus `package-lock.json`.
`node_modules/` goes in the repo's `.gitignore`.
Two consequences worth knowing before wiring a repo:

- Anything that runs the hooks on a clean checkout must restore the toolchain first. A CI job calling `prek --all-files` fails without an `npm ci` step, because the binaries the `entry` points at are not committed.
- A contributor needs the same `npm ci`, so the repo's contributing docs have to say so.

The alternative, an `extends` pointing at an absolute path into `~/.local/share/css-gate/node_modules/`, skips the install but only works on this machine, and the `entry` then has to name the machine-wide binary instead. Reserve it for a private repo that never sees CI.

This does not belong in `_meta/profiles/prek.toml`: unlike `typstyle` or `stylua`, whose hooks come from pinned upstream repos that provision the binary themselves, a CSS hook seeded into a new project would depend on a config and an npm install that project does not have.
The only CSS the `~/dotfiles` repo tracks is a vendored Obsidian theme, never hand-authored, so its own `prek.toml` carries no such hook either.
Wired so far: `quarto-hebstr-doc` (repo-local install, `npm ci` step in `render.yml`).

Edit-time coverage has none of these constraints: the `format-on-edit` hook runs under bash, where `$HOME` expands, so it uses the shared config directly and needs nothing per project.

## Biome: not an option yet

Biome would unify format and lint in one binary, but its own support matrix marks SCSS parsing and formatting as in progress and SCSS **linting** as not in progress, with Sass and Less absent from the table entirely.
Pointing it at a `.scss` file is a no-op by design.
Revisit at Biome v2.6, the milestone on its SCSS tracking issue, and even then for formatting only.

## References

- Stylelint getting started (SCSS via a community config): https://stylelint.io/user-guide/get-started/
- Stylelint CLI (flags, exit codes, stderr): https://stylelint.io/user-guide/cli/
- Stylelint v15 migration (why formatting is delegated to Prettier): https://stylelint.io/migration-guide/to-15
- Prettier documentation (SCSS support, `--check` / `--write`): https://prettier.io/docs/
- Quarto theme regions and layering order: https://quarto.org/docs/output-formats/html-themes-more.html
- Sass `@import` deprecation and removal target: https://sass-lang.com/documentation/at-rules/import/
- Biome language support matrix: https://biomejs.dev/internals/language-support/
- Biome SCSS tracking issue: https://github.com/biomejs/biome/issues/8732
- Some Sass language server: https://wkillerud.github.io/some-sass/language-server/getting-started.html
