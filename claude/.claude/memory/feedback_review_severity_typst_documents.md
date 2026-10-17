---
name: Review severity for Typst documents
description: "Calibrating reviews of Typst sources (`.typ`, local Typst packages, the `.typ` a Quarto render generates) and of the PDF they compile to: five measured non-defects that open the pass already dismissed, and the evidence rule a finding about the artifact must meet"
metadata:
  type: feedback
---

Calibration for a review of Typst source and of the artifact it renders to, whatever the project holding it: `~/admin/pro-cv` and the `hebstr-template` suite of `claude-code-litrev` are the two members of the corpus. The reviewer built on it is `typst-review`, at `~/.claude/skills/typst-review`.

**The evidence rule.** A finding is KEPT only when it cites the output of a command the pass ran: a probe, a `tinymist lint` diagnostic, a `typstyle -l 100 --check` result, a render exit code. A finding derived from reading the source alone is DROPPED, not downgraded and not filed as a note. On this corpus the source reads fine and the artifact is where the defect is.

**Five non-defects, already measured on 2026-10-16 and 2026-10-17. File none of them.**

- `typst eval --in cv.typ 'query(heading).len()'` returning 0: the section titles are styled text rather than `heading` elements. It leaves the PDF without an outline, which is a known property of the design, not a regression.
- `typst compile --features html` emitting an empty `<body>` on a Quarto-generated unit: measured on the generated `cv.typ`, where a control document emits its headings and paragraphs. HTML export is not an introspection path here.
- `typst compile` exiting 0 on a library `.typ` whose `pdftotext` output is 1 byte: a library defines bindings and renders nothing on its own. The probe belongs on the document that consumes it.
- A missing `--font-path`: a harness miss rather than a document defect. The faces live under the project's tree (`pro-cv/assets/fonts`) and only the front matter declares them, so the standalone steps need the flag and the linter exits 1 on `unknown font family` without it.
- A path under `/tmp` failing with `input file not found`: the Typst snap gets its own private `/tmp` and sees non-hidden paths under `$HOME` only, so the message names the wrong cause. Same for `access denied` on a path under a hidden directory.

**Why:** a reviewer handed a Typst target reads the source, finds it clean, and then files the toolchain's own confinement and the Quarto split as document defects. Each of the five was established by measurement before any review ran, so a pass that re-files them spends itself on settled ground. The design note is `~/dotfiles/.claude/DESIGN-TYPST-REVIEW.md`.

**How to apply:** before accepting a finding about what a Typst document renders to, name the command and quote the figure. Zero bytes out of `pdftotext` is a defect on an entry point and the expected result on a library, so classify the unit first. A question only a rendered page answers (alignment, page breaks, a header's position) is reported as unverified with the PNG command that would settle it, never asserted. At the level of the round the global `CLAUDE.md` rule governs: the user calls the stop. See [[feedback_review_severity_heuristic_code]], [[project_typst_skill_evaluation]], [[feedback_verify_gt_output_on_render]], [[feedback_audit_walkthrough]].
