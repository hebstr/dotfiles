---
name: "Quarto Lua shortcodes: kwargs are never nil, and the filesystem API that works"
description: Missing shortcode attributes arrive as empty Inlines (truthy), so presence tests silently discard fallbacks; Pandoc parses YAML metadata scalars as inline Markdown and silently mutilates Lua patterns; YAML 1.1 booleans reach Lua and crash pandoc.Plain; io.open on a named pipe hangs the render; plus the verified Pandoc filesystem/metadata primitives usable inside a Quarto shortcode
metadata:
  type: reference
---

**A missing shortcode attribute is not `nil`.** In a Quarto shortcode `function(args, kwargs, meta)`, reading a key that the author never wrote returns an empty `Inlines` table: `type` is `table`, `== nil` is false, `#value` is 0, and `pandoc.utils.stringify` gives `""`. Verified on Quarto 1.9.38.

**Why:** The table is truthy in Lua, so the natural precedence idiom silently breaks. `kwargs["exclude"] and split(kwargs["exclude"]) or from_config()` always takes the first branch and yields an empty result, discarding the fallback with no error. Encountered while making `{{< filetree >}}` read its options from a YAML sidecar with per-call attribute overrides: the sidecar's `exclude` and `highlight` were silently ignored, and the only symptom was a tree containing entries that should have been filtered.

**How to apply:** Never branch on the presence of a `kwargs` key. Normalize first, then test the normalized value:

```lua
local function kw(kwargs, name, default)
  local v = kwargs[name]
  if v == nil then return default end
  local s = pandoc.utils.stringify(v)
  if s == "" then return default end
  return s
end
```

Then `local override = kw(kwargs, "exclude", nil); if override then ... else ... end`. The same trap applies to any code treating an absent attribute as falsy, including `if kwargs.foo then`.

**Filesystem and metadata primitives available inside a shortcode**, all verified by render on Quarto 1.9.38, no external package or shelled-out CLI:

- `pandoc.system.list_directory(path)` lists a directory, relative to the project directory (`pandoc.system.get_working_directory` confirms it is the project root, not a temp dir).
- There is no `is_directory`, and no stat call anywhere in `pandoc.system` / `pandoc.path` / plain Lua. The file kind must be read off the *error message* of `pcall(pandoc.system.list_directory, p)`, which does separate the cases (measured on Linux, identical strings on pandoc 3.1.3 and 3.10): success = directory ; `inappropriate type (Not a directory)` = anything that is not a directory, **including a regular file in mode `000` and a named pipe** ; `permission denied` = listing refused ; `does not exist` = absent. Match those substrings, not the parenthetical suffix (that one comes from `strerror` and could localize ; the `IOErrorType` enum itself is hardcoded English in GHC `base`, verified invariant under `LC_ALL=C` and `fr_FR.UTF-8`, untested on Windows/macOS).
- **`permission denied` does not mean "directory".** Under a parent in mode `r--` (listable but not searchable), a regular file, a real subdirectory and an absent path all report `permission denied`, because resolving the child needs `x` on the parent. Treat that answer as "kind unknown" and say so in the warning ; asserting "directory" renders ordinary files as empty folders.
- **Never use `io.open` as an existence test on a path discovered by walking a tree.** Opening a named pipe with no writer blocks forever, with no timeout and no error: the render hangs rather than fails. This killed a probe process during the `filetree.lua` review. Restrict `io.open` to author-controlled config paths.
- Metadata keys containing slashes survive intact (`"config/tbl_helpers.R": "..."` reaches the shortcode as that exact key), so a path-keyed map in YAML is viable.
- A YAML sidecar can be read without a YAML parser: `pandoc.read("---\n" .. text .. "\n---\n", "markdown").meta`. This avoids project-level `metadata-files` config, which needs a `_quarto.yml`. **Only use it for values meant to be prose.** See the corruption trap below.

**Pandoc parses YAML metadata scalars as inline Markdown, which silently mutilates config values.** Every scalar read through a metadata block (the sidecar trick above, a `_quarto.yml` key, or a `.qmd` front matter key) goes through the inline reader before `pandoc.utils.stringify` flattens it. YAML quoting does not prevent it. Verified on Quarto 1.9.38:

| Value written | Value received |
|---|---|
| `__pycache__` | `pycache` |
| `_src_` | `src` |
| `^_%w+_$` | `^%w+$` |
| `%.html$\|_files$` | `%.html\|_files` |
| `%.html$` | unchanged |

**Why it is dangerous:** paired `_`, `*`, `$`, `^` and `[x](y)` are all Markdown syntax and all common in Lua patterns, regexes, and glob-ish config. There is no error path: the mangled pattern still compiles and `string.find` still runs, so a filter silently matches the wrong entries. The `.yml` on disk still reads correctly, so the only place a human would look shows nothing wrong. Disabling extensions does not save you: `tex_math_dollars` is switchable, emphasis, strong and superscript are not.

**How to apply:** split the config surface in two. Values that are prose (descriptions, captions, labels) go through `pandoc.read` and keep their inline Markdown, which is the feature. Values that are code (patterns, paths, flags, numbers) must be read from the raw file text, by scanning lines for the handful of keys involved rather than by parsing YAML properly. A ~35-line scanner covering `key: value` and `key:` + `- item` is enough for a sidecar you control. Corollary: never offer a front matter fallback for a config surface holding patterns, since the `.qmd` front matter goes through the same reader with no way to opt out. Applied in `quarto-hebstr-doc` `filters/filetree.lua` (`read_raw_config`) on 2026-07-20.
- A `MetaList` arrives as an array whose items are themselves `Inlines` (element `.t` is nil), while `MetaInlines` arrives as an array of `Inline` nodes (element `.t` is set). That distinction is how to tell a YAML list of strings from a single string; `stringify` on a `MetaList` concatenates the items with no separator, which is almost never what you want.
- **YAML 1.1 typing reaches Lua, and `%YAML 1.2` cannot switch it off.** An unquoted `no`/`yes`/`on`/`off`/`true`/`false` arrives as a Lua **boolean** and `~` as `""` ; numbers arrive as `Inlines`. `pandoc.Plain(<boolean>)` then raises `Inline, list of Inlines, or string expected, got boolean`, killing the render without naming the offending key. A `%YAML 1.2` directive is accepted without error and changes nothing (libyaml is only the scanner ; tag resolution happens in pandoc's Haskell layer and ignores the version), and 1.2 would still keep `true`/`false` and `null` anyway. Dispatch on `pandoc.utils.type` before handing any metadata value to a constructor.
- `pandoc.utils.stringify` flattens inline markup, so backticks in a metadata value are lost. To preserve them, keep the value as `Inlines` and write it with `pandoc.write(pandoc.Pandoc({pandoc.Plain(inlines)}), "html")`; `Plain` emits no wrapping `<p>`.

Related: [[feedback_verify_quarto_theming]] for the SCSS side of the same extension work, [[project_hebstr_doc_adaptive_figures]] for why that theme's custom adaptive-figure Lua filter was dropped in favor of Quarto's native `renderings`.
