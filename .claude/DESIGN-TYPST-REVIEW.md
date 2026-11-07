# DESIGN-TYPST-REVIEW.md

Design note for `typst-review`, the adversarial reviewer for Typst source and the artifact it renders to, decided 2026-10-17.
It is the pass `_meta/notes/typst-skill-reco.md` deferred when it adopted `lucifer1004/claude-skill-typst`, and it is the second application of the placement criterion of `DESIGN-AGENT-SKILLS.md`.

## The reviewer is a personal skill, because every load-bearing step reads this machine

Decision: `typst-review` lives in `claude/.claude/skills/typst-review/`, reached at `~/.claude/skills/typst-review`, next to `review-comments` and `relire`.
It is not a fifth skill of the `hebstr` marketplace.

The criterion is the one `DESIGN-AGENT-SKILLS.md` states under "Where a skill the user writes goes is decided by its coupling to this machine": the marketplace takes only what someone else can install and run.
Four of this reviewer's steps fail that test, and they are the steps it exists for.
The typst snap sees non-hidden paths under `$HOME` only, so the compile happens in the project directory and a path under `/tmp` reports "input file not found", which names the wrong cause (`rules/typst.md`).
`tinymist` resolves only inside a Positron extension directory whose path carries the extension version.
`--font-path` is required because the faces live under `pro-cv/assets/fonts` and only the front matter declares them.
And the single sharpest fact the reviewer acts on, that `typst compile --features html` emits a `<body>` of 0 characters on a Quarto-generated unit, was measured on one `.qmd` of one project (`~/admin/pro-cv/.claude/DESIGN-TYPST-LAYOUT.md` § "Gate for this project").

## Runtime discovery is neutral on placement, against the brief that opened this pass

The brief argued for the marketplace on the ground that a reviewer is discovered off the installed plugins by `audit/walkthrough/scripts/scan-reviewers.py`.
That is false and the script says so: it scans `USER_SKILLS_DIR` and the project `.claude/skills/` chain before it walks the plugin manifest, and personal skills keep their bare name.
Measured 2026-10-17 from `~/admin/pro-cv`, the scan returns five candidates, one of them `review-comments` at `~/.claude/skills/review-comments/SKILL.md`.

## Two frontmatter constraints the scan imposes, neither of them a preference

Both probed 2026-10-17 against the script's own `is_reviewer` and `classify`.

- The name gate matches `typst-review`: `NAME_PAT` is `\breview` and the hyphen is a word boundary.
- `classify` returns `code` only when the `description` carries a `CODE_SIGNALS` word, and that list is literal: `codebase`, `code`, `PR`, `pull request`, `project`, `repositor(y|ies)`, `architecture`, `python`, `R `, `javascript`, `typescript`, `SQL`. `typst` is not among them, so a description whose only technical word is `Typst` returns `unknown`, which is what `review-comments` gets. `SKILL_TOOL_SIGNALS` is tested first and wins, so a description naming `SKILL.md` or an MCP server lands on `skill-tool` whatever else it carries. The consequence is not cosmetic: `walkthrough/agents/orchestrator.md` injects calibration **only** for the `code` category and treats `unknown` as fail-safe, so on `unknown` the calibration note below never reaches the reviewer at all.

So the description must be written to land on `code`, while still obeying `rules/skill.md`, which reserves it for trigger language.

## The reviewer renders, and removes what it rendered

It runs the probes itself rather than requiring a pre-generated unit, because the caller cannot supply one: `AskUserQuestion` is withheld from every subagent, and the walkthrough hands the reviewer exactly one path.
Since `rules/typst.md` forbids compiling in an agent scratchpad, rendering means writing into the user's project.

The rule that makes that acceptable: render into a new non-hidden project-local directory the reviewer creates, never overwrite an existing path, list every file created in the report, revert any tracked file a render modified, and remove the created ones before returning, naming any that could not be removed.
`pro-cv/cv.pdf` is the case that forces the non-overwrite half: it exists on disk and a render would replace the user's copy.

Naming `--output-dir` as what satisfies that half was wrong, and the first real run is what established it: Quarto renders the artifact beside the `.qmd` and then moves it, so `quarto render cv.qmd --output-dir <fresh-dir>` destroyed that exact file on 2026-10-17 (quarto 1.10.19, reproduced on a scratch document with a sentinel), leaving only the fresh render in the output directory.
`--no-clean` documents the cleaning of the output directory and says nothing about the source directory, which is where the loss happens.
The rule now has the reviewer copy the artifact aside and restore it, since skipping the Quarto render instead would remove the only probe that compiles the real document.

## No finding about the rendered result without the probe output that produced it

The stop rule, on the model of `feedback_review_severity_heuristic_code`.
A claim derived from reading the source alone is dropped rather than downgraded, because on this corpus the source reads fine and the artifact is where the defect is: `typst compile` exits 0 on `cv-body.typ` and produces a PDF whose `pdftotext` output is 1 byte.

Round-level, the global `CLAUDE.md` rule governs unchanged: the user calls the stop, and the reviewer stops on its own only after two consecutive rounds producing nothing but findings already addressed or rejected.

## The calibration note exists before the first run, or the first run pays for it

`feedback_review_severity_typst_documents.md`, keyed on the artifact kind rather than on a project, which is what the scope filter of `orchestrator.md` matches on, so one file serves both `~/admin/pro-cv` and the `hebstr-template` suite in `claude-code-litrev`.

It opens with the five non-defects the measurements of 2026-10-16 and 2026-10-17 already established, so that the first pass does not spend itself re-filing them:

- `typst eval --in cv.typ 'query(heading).len()'` returning 0 when section titles are styled text rather than `heading` elements;
- `typst compile --features html` emitting an empty `<body>` on a Quarto-generated unit;
- `typst compile` exiting 0 on a library `.typ` whose `pdftotext` output is 1 byte;
- a missing `--font-path`, which is a harness miss rather than a document defect;
- a path under `/tmp` failing with "input file not found", which is snap confinement rather than a missing file.

## What it adds over the reviewers already installed

`posit-dev:critical-code-reviewer` holds zero occurrences of `typst`, `.typ`, `pdf` or `rendered`, and no step anywhere in it compiles, renders or executes the thing under review.
A calibration memory can suppress a false finding; it cannot create a probe, which is why routing Typst targets to that reviewer leaves the artifact unread.

`typst-verify`, in the vendored tree at `agents/typst-verify.md`, is not a competitor and cannot be selected as one: it is an agent definition rather than a `SKILL.md`, so `scan-reviewers.py` never sees it and `--reviewer typst-verify` does not resolve.
It also answers a different question, taking claims supplied to it and returning PASS/FAIL per claim where a reviewer is handed a path and must generate the claims itself, and its verification table puts HTML export first, which the pro-cv measurement refutes for the Quarto case.
Its three probes are the overlap, and `typst-review` cites `debug.md` for them rather than copying them: `_meta/notes/typst-skill-reco.md` records that `skills update -g` replaces the vendored directory wholesale.

## Rejected, with what disqualified each

- **A fifth skill of the `hebstr` marketplace** (`audit/typst-review/`): the coupling criterion above, and a recurring cost the repository has already measured. Every edit owes a push, two `claude plugin update` calls and a restart, which is why the "three Step 2b strings" count sits uncorrected as a residual in that repository's `PLAN.md`. The distributability it buys is deferred there too, under "Announcement / discoverability".
- **A project skill at `~/admin/pro-cv/.claude/skills/`**: it would be discovered, the scan walking from the working directory to the repository root, and it would settle the project-level question `DESIGN-AGENT-SKILLS.md` leaves open. It is invisible from `claude-code-litrev`, which holds the other half of a two-project corpus.
- **Building nothing and writing the calibration memory alone**: leaves the rendered artifact unread, for the reason given under "What it adds".
- **Requiring a pre-rendered unit instead of rendering**: no side effects, but the reviewer stalls on the Quarto case, having no channel to ask for the unit.

## Open

- **The walkthrough could not load a reviewer by name, which blocked the consumer the brief names; corrected on 2026-10-17, never exercised live.** `orchestrator.md` built its Agent prompt as `You are running the <reviewer> skill. Review: <target>`, with no path, while `blindspot/SKILL.md` instructed its Agent to read the reviewer's `SKILL.md` and execute its procedure. `disable-model-invocation: true`, which `typst-review` carries like every skill of the marketplace, removes a skill from the listing the model sees, so the Skill tool refuses the name: observed 2026-10-17 in this session, where the five skills of `~/.claude/skills/` carrying the flag (`design`, `poc`, `prune`, `relire`, `review-comments`) are absent from the listing and the other eight are present, the fourteenth entry of that directory, `synced`, holding no `SKILL.md` and being no skill. The gap was pre-existing and applied identically to `audit:skill-adversary`, which is why every pass that used it went through `/audit:blindspot`. Both of `orchestrator.md`'s Agent prompt templates now pass the reviewer's resolved `SKILL.md` path with a read-and-execute instruction. What a reading cannot establish, and what the open item of `~/Documents/packages/claude-code-plugins/.claude/PLAN.md` still holds, is a live run proving it; until one happens, `/audit:blindspot` is the proven consumer.
- Whether the reviewer should read the PNG export itself, which needs multimodal reading of each page, or stop at `typst eval` and `pdftotext`. Undecided: the cost per page is unmeasured and the corpus is two documents.
- Nothing lints or tests a user-level skill, which the coupling criterion names and accepts. `prose-lint` is the one check that reaches the file, and it exits 0 on the `SKILL.md` as first written, so the backlog `ref` arrived with did not materialise here.
