---
domain: quarto
author: canouil
topic: extensions
sources:
  - kind: repo
    repo: mcanouil/quarto-code-window
    url: https://github.com/mcanouil/quarto-code-window
    ref: "1.5.0"
    captured: 2026-09-20
    files:
      - _extensions/code-window/_extension.yml
      - _extensions/code-window/_schema.yml
      - _extensions/code-window/_dependencies.yml
      - _extensions/code-window/main.lua
      - _extensions/code-window/code-window.lua
---

# Quarto: Lua filter extension (multi-format code window)

Reference pattern for a Quarto extension that ships a Lua filter, a CSS file, and per-block options, and renders the same result across HTML, Reveal, and Typst.
Source: [mcanouil/quarto-code-window](https://github.com/mcanouil/quarto-code-window) (captured 2026-09-20, version 1.5.0). Tags carry no `v` prefix.

## Layout

```
_extensions/code-window/
├── _extension.yml              # filter registration
├── _schema.yml                 # user-facing options + per-block attributes
├── _dependencies.yml           # vendoring manifest (origin, version, sha256 per file)
├── main.lua                    # entry point: loads modules, returns filter list
├── code-window.lua             # core filter logic
├── style.css                   # HTML chrome
├── _modules/
│   ├── language.lua            # auto-filename from code language
│   ├── cell-output.lua         # marks blocks holding an executed cell's output
│   └── hotfix/
│       ├── typst-title-fix.lua
│       ├── code-annotations.lua
│       └── skylighting-typst-fix.lua
└── _vendor/
    ├── quarto-lua-modules/     # html, logging, metadata, pandoc-helpers,
    │                           # schema-check, string
    └── quarto-wizard/          # schema.lua
```

## `_extension.yml`: filter registration

```yaml
title: Code Window
author: Mickaël Canouil
version: 1.5.0
quarto-required: ">=1.9.36"
contributes:
  filters:
    - at: pre-quarto
      path: main.lua
    - at: post-quarto
      path: _modules/hotfix/typst-title-fix.lua
```

`at: pre-quarto` runs the filter **before** Quarto's own AST processing, which is what you need when you want to mutate code blocks before Quarto's syntax highlighter sees them.
`at: post-quarto` runs after, and is used here only for hot-fixes that patch Quarto's Typst output.

## `main.lua`: filter assembly

The entry point loads submodules and assembles a filter list (Pandoc applies filters in order):

```lua
local filters = {
  { Meta = code_window.Meta },            -- read document options
  { Pandoc = mark_cell_output },          -- mark executed-cell output to leave alone
  { CodeBlock = language.CodeBlock },     -- inject auto-filename
  { Pandoc = code_window.Pandoc },        -- inject CSS/JS deps
  { CodeBlock = code_window.CodeBlock },  -- transform each code block
}
```

The order is load-bearing: `Meta` runs first because the cell-output pass needs the configuration, and that pass runs before the language pass so a marked block is never relabelled.
Optional hot-fix filters are appended conditionally, wrapped so they read `code_window.CONFIG()` at runtime and no-op when the user disables them.

## User API (from `_schema.yml`)

Document-level options under `code-window:` in YAML front matter:

```
| Option              | Type                  | Default       | Notes                                   |
|---------------------|-----------------------|---------------|-----------------------------------------|
| `enabled`           | bool                  | `true`        | Master switch.                          |
| `style`             | `default\|macos\|windows` | `macos`   | Window decoration.                      |
| `auto-filename`     | bool                  | `true`        | Generate filename label from language.  |
| `cell-output`       | bool                  | `false`       | Frame an executed cell's output too.    |
| `collapse`          | bool or `open\|closed` | `false`      | Wrap in `<details>` (HTML/Reveal only). |
| `lines-label`       | bool                  | `true`        | Chip showing the highlighted-line spec. |
| `wrapper`           | string                | `code-window` | Typst wrapper function name.            |
| `hotfix.<name>`     | bool or object        | `true`        | One key per hot-fix: `code-annotations`, `skylighting`, `typst-title`. The object form takes `enabled` and `quarto-version`. |
```

Per-block override via attributes:

````markdown
```{.python code-window-style="windows"}
print("hi")
```
````

Other per-block attributes: `code-window-enabled`, `code-window-no-auto-filename`, `code-window-collapse`, `code-window-lines` (highlighted-lines spec such as `1,3-5`, falling back to Quarto's `code-line-numbers`).

## Multi-format rendering

The same filter handles HTML and Typst differently inside `code-window.lua`, which emits either HTML wrappers (consumed by `style.css`) or a Typst function call wrapping the code in `#code-window(...)`.
The format is resolved once, in the `Meta` pass, through the vendored `pandoc-helpers.get_quarto_format()`, and stored in a `CURRENT_FORMAT` upvalue that the later passes compare against `'html'` or `'typst'`.
That helper folds `html:js` into `html`, which is what makes Reveal.js fall out of the HTML branch with no separate case.

Runtime CSS classes injected by JS (HTML output): `code-window-macos`, `code-window-windows`, `code-window-default`, `code-window-auto`.

## Hot-fixes (intentionally temporary)

The `hotfix/` directory contains patches for current Quarto Typst limitations. The schema documents them as **temporary** and tied to upstream issue [quarto-dev/quarto-cli#14170](https://github.com/quarto-dev/quarto-cli/issues/14170). Each hot-fix accepts a `quarto-version` field: once the user's Quarto reaches that version, the fix self-disables.

Pattern worth copying when you ship a workaround: don't pretend it's permanent. Tag it, document the upstream issue, and let it self-deprecate.

## Vendored modules and schema checking

Shared Lua helpers are copied into `_vendor/` rather than required from a sibling extension, and `_dependencies.yml` records where each copy came from:

```yaml
sources:
  quarto-lua-modules:
    origin: "https://github.com/mcanouil/quarto-lua-modules"
    fetch: "{origin}/releases/download/{version}/{file}"
    version: "2.2.0"
    files:
      logging.lua:
        sha256: "1a8339db434d4cc8f794a2e2526ffe002124b3f71df3e3ef47eb9db3a3b24296"
```

Pinning the release plus a per-file `sha256` is what makes a vendored copy auditable: the manifest answers "which upstream release is this, and has it been touched since" without a network call at render time.

`main.lua` also builds a checker from `_schema.yml` once per render and reports the keys under `extensions.code-window` that the extension does not accept. A schema that cannot be read is reported and the render carries on: a fault in the configuration must not remove the document.
