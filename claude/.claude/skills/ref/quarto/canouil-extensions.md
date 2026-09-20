---
domain: quarto
author: canouil
topic: extensions
sources:
  - kind: repo
    repo: mcanouil/quarto-code-window
    url: https://github.com/mcanouil/quarto-code-window
    ref: v1.1.5
    captured: 2026-04-25
    files:
      - _extensions/code-window/_extension.yml
      - _extensions/code-window/_schema.yml
      - _extensions/code-window/main.lua
      - _extensions/code-window/code-window.lua
---

# Quarto: Lua filter extension (multi-format code window)

Reference pattern for a Quarto extension that ships a Lua filter, a CSS file, and per-block options, and renders the same result across HTML, Reveal, and Typst.
Source: [mcanouil/quarto-code-window](https://github.com/mcanouil/quarto-code-window) (captured 2026-04-25, version 1.1.5).

## Layout

```
_extensions/code-window/
├── _extension.yml              # filter registration
├── _schema.yml                 # user-facing options + per-block attributes
├── main.lua                    # entry point: loads modules, returns filter list
├── code-window.lua             # core filter logic
├── style.css                   # HTML chrome
└── _modules/
    ├── language.lua            # auto-filename from code language
    ├── logging.lua
    └── hotfix/
        ├── typst-title-fix.lua
        ├── code-annotations.lua
        └── skylighting-typst-fix.lua
```

## `_extension.yml`: filter registration

```yaml
title: Code Window
author: Mickaël Canouil
version: 1.1.5
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
  { CodeBlock = language.CodeBlock },     -- inject auto-filename
  { Meta = code_window.Meta },            -- read document options
  { Pandoc = code_window.Pandoc },        -- inject CSS/JS deps
  { CodeBlock = code_window.CodeBlock },  -- transform each code block
}
```

Optional hot-fix filters are appended conditionally, wrapped so they read `code_window.CONFIG()` at runtime and no-op when the user disables them.

## User API (from `_schema.yml`)

Document-level options under `code-window:` in YAML front matter:

| Option              | Type                  | Default       | Notes                                   |
|---------------------|-----------------------|---------------|-----------------------------------------|
| `enabled`           | bool                  | `true`        | Master switch.                          |
| `style`             | `default\|macos\|windows` | `macos`   | Window decoration.                      |
| `auto-filename`     | bool                  | `true`        | Generate filename label from language.  |
| `wrapper`           | string                | `code-window` | Typst wrapper function name.            |
| `hotfix.*`          | bool or object        | `true`        | Per-hotfix toggle (see below).          |

Per-block override via attributes:

````markdown
```{.python code-window-style="windows"}
print("hi")
```
````

Other per-block attributes: `code-window-enabled`, `code-window-no-auto-filename`.

## Multi-format rendering

The same filter handles HTML and Typst differently inside `code-window.lua`: it inspects `quarto.doc.is_format(...)` and emits either HTML wrappers (consumed by `style.css`) or a Typst function call wrapping the code in `#code-window(...)`.

Runtime CSS classes injected by JS (HTML output): `code-window-macos`, `code-window-windows`, `code-window-auto`.

## Hot-fixes (intentionally temporary)

The `hotfix/` directory contains patches for current Quarto Typst limitations. The schema documents them as **temporary** and tied to upstream issue [quarto-dev/quarto-cli#14170](https://github.com/quarto-dev/quarto-cli/issues/14170). Each hot-fix accepts a `quarto-version` field: once the user's Quarto reaches that version, the fix self-disables.

Pattern worth copying when you ship a workaround: don't pretend it's permanent. Tag it, document the upstream issue, and let it self-deprecate.
