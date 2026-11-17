# DESIGN-DIAGRAM-SKILL.md

Design note for the `diagram` skill and for the home of the measured Pele limits, approved by the user on 2026-11-17 after `/design`, each decision named separately (a fourth, the provisional staging of the limits in this note, was executed on 2026-11-17 and deleted).
It formalises the exploration practice of `eds-prise` on 2026-11-16 and 2026-11-17, where `scripts/fig_flowchart.R` (Gmisc, grid) was rebuilt with `hebstr::easy_diagram()` and paused by the user.
Implemented on 2026-11-17: the limits in `DIAGRAM-OUT.md`, `diagram/scripts/board.R` with `_meta/tests/diagram-board.bats`, and `diagram/SKILL.md`.
Why a note: the decision constrains later sessions, and anyone who missed the conversation would propose the rejected homes for the limits again.

## The practice is a typed skill, because no always-on mechanism covers a multi-step procedure with traps

**Decision 1.** A personal skill `diagram` in `claude/.claude/skills/diagram/`, invoked as `/diagram <need>`, with `disable-model-invocation: true` and a short procedure.

The practice the user judged effective: preselect 4 to 5 Mermaid types suited to the context, render them as one HTML board in the browser with a light and a dark column, read a screenshot of it, iterate.

Reason: step 4 of the routing test in `rules/claude-files.md`, section "Where a new instruction goes" (a multi-step procedure is a skill).
The 55 % automatic activation of `DESIGN-INSTRUCTION-ROUTING.md` (section "Each instruction lives where its trigger fires, and the root keeps only what has none", rejected "Skills instead of injection") does not apply: the skill is typed, as `design` and `poc` are.
The skill is personal and not a marketplace skill by the criterion of `DESIGN-AGENT-SKILLS.md`, section "Where a skill the user writes goes is decided by its coupling to this machine": its load-bearing steps read this machine (project paths, the Chromium snap, the absolute path of the `hebstr` repository).
The frontmatter follows `rules/skill.md`: a `description:` carrying trigger language only, quoted when it holds a `: `, on the model of `poc` (a folded `>` scalar).

The procedure points at the limits note (decision 2) and at `rules/chromium.md`, and repeats neither: the Chromium snap traps are injected on a `chromium` command, and the Mermaid traps live with the limits.

## The measured Pele limits live in `hebstr/.claude/DIAGRAM-OUT.md`, next to the code that causes them

**Decision 2.** The limits go in a new section of `~/Documents/packages/R-hebstr/.claude/DIAGRAM-OUT.md`, dated 2026-11-16 and 2026-11-17 and tagged hebstr 0.1.0 with Pele 1.13.0, beside its existing section "Measured".
The skill reads that file by its absolute path as its first step.

Reason: that note is already where `hebstr` records what Pele does, and `hebstr/.claude/CLAUDE.md` names it as the file to read "before bumping `inst/pele/`", the moment the limits must be re-checked.
The fix for the Luciole measurer lands in the same repository, so the bullet that describes the defect is deleted where the fix is committed.
The facts concern the package that serves 13 projects, not one project's ER.

What it costs, accepted: the skill depends on an absolute path on this machine, and fails loudly if the file is absent, which is preferred to a silent stale copy.
`hebstr/.claude/` is git-ignored, so the note shares the durability of the other `.claude/` notes of that repository.

One edit rides with the move: the bullet of "Measured" in `DIAGRAM-OUT.md` that reads "Labels of 38 to 44 characters, upper case and accented, fit their boxes in Luciole" is bounded to its length, because 60 to 70 characters overflow.
The two figures do not contradict each other: the fit threshold lies between 44 and 60 characters and is not measured.
`eds-prise/.claude/DESIGN-DIAGRAM.md` needs no edit: its claim, section "The two weakest assumptions: one held on 2026-11-14, one is still untested", item 2, is scoped to 38 to 44 characters, and its table "Measured on 2026-11-14" concerns the renderer's feasibility, not these limits.

## The board script stops at the HTML, and its one guard is mechanical

**Decision 3.** A tested R script under `claude/.claude/skills/diagram/scripts/`.
For each candidate Mermaid file it calls `easy_diagram()` then `easy_out(pair = TRUE)` of the project's own `hebstr`, into a folder of the project, then writes one HTML page with a light column and a dark column.
`easy_out(pair = TRUE)` already writes `<name>-light.{svg,png}` and `<name>-dark.{svg,png}` (roxygen of `easy_out()`), so the dark column invents nothing.
It aborts on an output folder under `/tmp`: the snap Chromium cannot read it (`rules/chromium.md`).
The test is a bats suite in `_meta/tests/`, on the precedent of `handoff-tail.bats` for `handoff/scripts/tail.sh`, skipped without Node or `hebstr`.
The R gate of `rules/r.md` applies at implementation.

The screenshot is one documented line of the procedure, following `rules/chromium.md` (project-local page and capture, one throwaway profile per launch).
Scripting it would make the test launch the snap browser.

The script holds no table from a need to Mermaid types.
Choosing the 4 to 5 types is a judgement, left to the session and the user through the candidate files, per the rule of `CLAUDE.md` that subjective heuristics are deferred rather than hardcoded.

The board must go through the project's exact export path: a board rendered with `render.mjs` directly judged boxes that fit while the real `easy_diagram()` then `easy_out()` overflowed in Luciole.

## Rejected

- **Limits in a dated reference file of the skill.** A second copy of facts `hebstr` owns: nothing ties a Pele bump or the measurer fix to it, so it goes stale unseen, and the roxygen subset would be a third copy.
- **Limits in `eds-prise/.claude/DESIGN-DIAGRAM.md`.** That note records one project's decision (the ER of the chaînage keys), and a diagram in another project would never read it. It also is already a dense note.
- **Limits in the roxygen of `easy_diagram()` alone.** The roxygen holds the stable, user-facing subset only, not dated measurements, pixel figures or probes. It is a complement and a separate act owed to `hebstr`, not folded in here.
- **Limits as a memory.** Tied to hebstr 0.1.0 and Pele 1.13.0, they go stale at the next bump.
- **A script that also takes the screenshot.** The test would need the snap browser.
- **A need-to-types table in the script.** Subjective, so left to the user.
- **Doing nothing.** The practice would stay in one conversation, and the traps below would be rediscovered.

## The weakest assumption

The limits stay current only if a Pele bump goes through `DIAGRAM-OUT.md`.
That holds while `hebstr/.claude/CLAUDE.md` keeps its trigger "before bumping `inst/pele/`" for that file. If it fails, the limits age as in the rejected reference file, with a version tag as the only warning.
Untested: it depends on a future session.

## Decided at implementation, 2026-11-17

The user settled the three open points, each separately.

- **R alone.** `board.R` runs from the project root under `Rscript`, so the project's `.Rprofile` activates its rv library. No shell launcher: the `/tmp` guard and the dependency checks live in R, and one file has one gate.
- **The board shows the SVG pair only.** `easy_out(pair = TRUE)` still writes the PNG pair beside, and the dark PNG's opaque white background stays recorded as a limit. Revisit when a Word or PNG-first consumer needs the board to show it.
- **`/diagram` stops in a project with no `hebstr` in its `rproject.toml`.** The board path and the limits both assume the project's hebstr and its Pele; the user-library hebstr of this machine (0.0.0.9000) cannot render a diagram.

Two shapes the suite pins that the design did not state: the script takes `--setup <file>`, the project's setup, because the font `set_opts()` resolves there decides how wide the boxes render, and the real-run tests of `diagram-board.bats` run from `DIAGRAM_BOARD_PROJECT` and skip when the hebstr they reach has no diagram support.

## What stays open

Owed elsewhere, not folded in: the limits in the roxygen of `easy_diagram()`; a width factor for non-generic fonts in the Pele measurer (`eds-prise/.claude/DEFERRED.md`, row "A pele diagram overflows its boxes in Luciole…"); the sankey script of the flowchart, paused; the open points of `eds-prise/.claude/DESIGN-DIAGRAM.md`, section "What stays open".
