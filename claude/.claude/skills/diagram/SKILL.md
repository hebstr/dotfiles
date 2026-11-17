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
The pass writes candidates and a board under the project's `.claude/screenshots/diagram/` and no other project file, bar the one ignore line that step 2 adds when the folder is versioned: the script that publishes the retained diagram is the user's call.

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
- `Rscript -e 'quit(status = !("easy_diagram" %in% getNamespaceExports("hebstr")))'`: a non-zero status means the project's hebstr is absent from its library or predates `easy_diagram()`, so stop with one sentence. A hit in `rproject.toml` is not enough: most projects pin `0.0.0.9000`, which cannot render a diagram.
- `git check-ignore -v .claude/screenshots/diagram/x`, or `git -C .claude check-ignore -v screenshots/diagram/x` when `.claude/.git` exists, since the outer repository then answers for `.claude/` as a whole and only the nested one knows its own ignore rules. No output means the folder is versioned: add `screenshots/` to the `.gitignore` of the repository that versions `.claude/` before writing anything.
- The project's setup file, which holds `set_opts()` with the project's font and so changes how wide the boxes render: `rg -l 'set_opts\(' --glob '*.R' .` finds it (`setup.R` or `_setup.R` at the root, or `scripts/_setup.R`). One hit is passed to the script, several are a question to the user, none is a stop and a question: a board judged without it misjudges the box widths.

## 3. Write the candidates

Look first at `.claude/screenshots/diagram/candidates/`: step 4 renders every `.mmd` there, so the files of an earlier need are deleted before writing, with the user's say when one may still be the retained candidate.
Choose 4 to 5 types suited to the need among those the limits list, and write one Mermaid file per type in that folder, named after the type (`flowchart.mmd`).
The choice is a judgement: name the types and the reason for each in a line, and let the user cut or add before rendering.
Use the project's real labels and the real figure of the need, never placeholders, since the board exists to see real text in real boxes.
Apply the limits as you write.

## 4. Build the board

```
Rscript ~/.claude/skills/diagram/scripts/board.R --out .claude/screenshots/diagram --setup <setup file> .claude/screenshots/diagram/candidates/*.mmd
```

The script runs the project's `easy_diagram()` then `easy_out(pair = TRUE)` for each candidate, and its last stdout line is the path of `board.html`.
A non-zero exit names its cause on stderr, and the candidate file when its render failed (exit 6): read it before going on.

## 5. Capture and read

The page and the capture stay under the project, and each launch takes its own throwaway profile as `rules/chromium.md` prescribes, which the harness injects on the `chromium` command:

```
P=$(mktemp -d ~/snap/chromium/common/claude-profile.XXXXXX); trap 'rm -rf "$P"' EXIT
chromium --headless=new --user-data-dir="$P" --window-size=<width>,<height> --screenshot=<project>/.claude/screenshots/diagram/board.png file://<project>/.claude/screenshots/diagram/board.html
```

Read the PNG with the Read tool and judge each candidate in both columns: text inside its box, overlaps, the dark column's contrast, a node the dark pair left unchanged.
A box that overflows is a finding about this font, whatever the render looked like elsewhere.
The board is two diagrams wide and one per candidate tall: take a window width of twice the widest diagram plus 200, and a height of the diagrams stacked plus 20 per candidate plus 100, a diagram's natural size being half the pixel size of its `<name>-light.png` (`file <png>`). Check that the capture shows the whole board, and enlarge the window when it does not.

## 6. Iterate and close

Edit the candidate files, rerun steps 4 and 5, and drop a type the user rules out by deleting its `.mmd`, which the glob of step 4 would otherwise render again.
End with the retained candidate's path, the limits it had to respect, and the one you recommend with its reason.
