---
name: Quarto include paths resolve against the including document, with no project-root form
description: A `{{< include >}}` path is relative to the directory of the document that includes it, a leading slash is NOT project-root but relative too, the shortcode only works standalone on its own line, and one broken include in a project fails every document's render; pre-render script paths, by contrast, are project-root relative
metadata:
  type: reference
---

Measured 2026-10-04 on Quarto 1.10 in a throwaway project (`render: [docs/a/main.qmd]`, fragment at `docs/b/_frag.qmd`), after the three forms broke `eds-prise`'s nested document folders.

- **The path is relative to the directory of the including document**, never to the project root. From `docs/a/main.qmd`, `../b/_frag.qmd` works and `docs/b/_frag.qmd` is looked for at `docs/a/docs/b/_frag.qmd`. So one fragment shared by documents at different depths carries a different spelling in each consumer.
- **A leading slash buys nothing.** `/docs/b/_frag.qmd` fails with the same `docs/a/docs/b/...` path in the error: Quarto strips it and resolves relative anyway. There is no project-root spelling for an include.
- **The failure is not local.** The project's input scan expands every document's includes, so one broken include makes `quarto render` of *any* document in the project fail, naming the file that holds the bad directive rather than the one being rendered.
- **The shortcode only works standalone on its own line.** Inline (`text: {{< include f.qmd >}}`) it is not expanded at all: `WARNING Shortcode 'include' not found` and the literal braces reach the output, exit 0.
- **A `pre-render` script path is the opposite**: resolved from the project root, with the project root as cwd. `pre-render: lib/pre.R` runs, a bare `pre.R` naming a file in `lib/` dies with `Fatal error: cannot open file 'pre.R'`. It runs on a single-file render of a listed document too, and prints its `Running script` banner only on a project render, so a silent script gives no sign it ran.

Chunks inside an included fragment do execute, in the parent's session, so the fragment reads objects the parent's `setup` chunk defined. A fragment with no YAML front matter cannot be rendered alone, which is the usual guard, and an underscore prefix is what keeps Quarto from treating it as a project input.

See also [[reference_quarto_file_outside_render_list]] and [[project_quarto_extensions_need_project_root]].
