---
name: diagram
description: >
  User-invocable ONLY via `/diagram <need>`.
  Does not auto-trigger on mentions of "diagram", "flowchart", "Mermaid", "schema", "figure of the process", or French equivalents ("diagramme", "organigramme", "schéma", "diagramme de flux").
  The pass that chooses a Mermaid diagram type for a project on the `hebstr` stack, before any `easy_diagram()` script is written.
  Not for: a ggplot or a table (use the project's `fig_*` and `tbl_*` scripts), a diagram drawn by hand in Typst or TikZ, deciding where a diagram lives in a document (use `/design`).
disable-model-invocation: true
---

# Choosing a Mermaid diagram on a light and dark board

The argument is the need, in the user's words: what the diagram must show, for which document.
Conduct the conversation in the user's language.
The pass writes candidates and a board under the project's `.claude/screenshots/diagram/` and no other project file: the script that publishes the retained diagram is the user's call.

## 1. Read the measured limits

Read `~/Documents/packages/R-hebstr/.claude/DIAGRAM-OUT.md`, section "Measured Pele limits".
It holds the types that render, the layout, styling and font limits, and the traps of this method.
If the file or the section is absent, stop and say so: the limits are the one source and no copy stands in for it.

Compare the version tags of the section with the project's pinned `hebstr` (`rg -n -A3 'name = "hebstr"' rv.lock`).
A different version means the limits may be stale: say so before relying on them.

## 2. Check the project

Run everything from the project root.

- `rg -n hebstr rproject.toml`: no hit, stop with one sentence naming the missing dependency.
- `node --version`: 20 or later.
- `git check-ignore -v .claude/screenshots/diagram/x`: no output means the folder is versioned, so ignore it before writing anything.
- The project's setup file (`_setup.R` or `setup.R`): it holds `set_opts()` with the project's font, which changes how wide the boxes render. Pass it to the script, never judge a board without it.

## 3. Write the candidates

Choose 4 to 5 types suited to the need among those the limits list, and write one Mermaid file per type in `.claude/screenshots/diagram/candidates/`, named after the type (`flowchart.mmd`).
The choice is a judgement: name the types and the reason for each in a line, and let the user cut or add before rendering.
Use the project's real labels and the real figure of the need, never placeholders, since the board exists to see real text in real boxes.
Apply the limits as you write.

## 4. Build the board

```
Rscript ~/.claude/skills/diagram/scripts/board.R --out .claude/screenshots/diagram --setup <setup file> .claude/screenshots/diagram/candidates/*.mmd
```

The script runs the project's `easy_diagram()` then `easy_out(pair = TRUE)` for each candidate, and its last stdout line is the path of `board.html`.
A non-zero exit names its cause on stderr: read it before going on.

## 5. Capture and read

The page and the capture stay under the project, and each launch takes its own throwaway profile as `rules/chromium.md` prescribes, which the harness injects on the `chromium` command:

```
chromium --headless=new --user-data-dir="$P" --window-size=<width>,<height> --screenshot=<project>/.claude/screenshots/diagram/board.png file://<project>/.claude/screenshots/diagram/board.html
```

Read the PNG with the Read tool and judge each candidate in both columns: text inside its box, overlaps, the dark column's contrast, a node the dark pair left unchanged.
A box that overflows is a finding about this font, whatever the render looked like elsewhere.
The board is two diagrams wide and one per candidate tall: take a window width of twice the widest diagram plus 200, and a height of the diagrams stacked plus 100, a diagram's natural size being half the pixel size of its `<name>-light.png` (`file <png>`). Check that the capture shows the whole board, and widen the window when it does not.

## 6. Iterate and close

Edit the candidate files, rerun steps 4 and 5, and drop a type the user rules out.
End with the retained candidate's path, the limits it had to respect, and the one you recommend with its reason.
