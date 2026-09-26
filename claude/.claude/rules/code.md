---
paths:
  - "**/*.R"
  - "**/*.r"
  - "**/*.py"
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.bats"
  - "**/*.rs"
  - "**/*.lua"
  - "**/*.sql"
  - "**/*.js"
  - "**/*.ts"
  - "**/*.css"
  - "**/*.scss"
  - "**/*.typ"
  - "**/*.pl"
---

# Writing code

On-demand reference, loaded when Claude reads a code file (a `Write` of a new file loads nothing, which is why `CLAUDE.md` keeps the bare "no comments" and "run the gate" rules): comments, the scope of a change, the lint gate, what to check before writing a helper, and when tests come first.

## Comments and code text

- No comments in code, with no exception for a regex, a workaround or an invariant. What stays is only what is not a comment to a reader: section headers, API documentation (roxygen, docstrings), and lines a tool reads (shebang, `# shellcheck`, `# noqa`, `#|` chunk options, a PEP 723 block).
- A WHY a reader would need goes into the tracking note that covers the code (the project's `.claude/` design note, its `_meta/notes/` entry, `PLAN.md`), written in the timeless present; when no note covers it, say so and propose one rather than falling back on a comment.
- Before reporting a code edit done, grep the lines just written for the language's comment marker and move every hit outside that list to the note.
- Code text (names, roxygen and docstrings, section headers) is in English.
- No cosmetic whitespace padding for alignment, such as aligning inline comments with extra spaces, unless asked.

## Scope of a change

Only modify code directly related to the task. Directly related includes the cascading edits correctness requires (call sites of a renamed function, imports of a moved module, types after a signature change) and the consistency updates a structural change requires (counts, doc tables, configs, tests). It excludes surrounding cleanup, style fixes and unrelated refactors found in passing: flag those separately when they matter.

## The lint, format and test gate

- After writing or modifying code, run the project's gate before reporting the task done, never waiting to be asked. Each language's sequence is in its `rules/*.md` and is authoritative. The shared order: auto-fixers, then the formatter, then the validating linter, then the type checker where there is one, tests last.
- It runs on any non-trivial edit: a new file, a new public or exported function, a new or substantively changed script under `bin/`, a logic change of more than about 10 lines or one that adds or removes a conditional branch. It is skipped for one-line typo fixes, pure renames of private or local symbols, comment-only edits and prose typo fixes.
- A hard failure is a non-zero exit with no file mutation, or the validating linter still reporting after the fixers ran; a fixer that mutates a file and exits non-zero is expected churn. On a hard failure, fix and re-run from the top at most once, then surface the residual violations.
- A missing tool (`command -v` fails) is skipped and named, the rest running in sequence. When the missing tool is the final validating linter (shell's `shellcheck`, Python's confirming `ruff check`), the gate cannot pass: report the task as unvalidated, not done. A tool that runs but validates nothing counts as missing: a bare `pyrefly check` on a file no pyrefly config governs reports `0 errors` under the fallback `basic` preset, and `rules/python.md` carries the invocation that avoids it.
- The auto-fixers and formatters rewrite tracked files in place: that mutation is part of the gate, not a git operation. Opt-in logic-rewriting fixers outside the default gate (`cargo clippy --fix`) are excluded. If a rewrite produces an unwanted diff, surface it and let the user revert it.
- If the user pushes back ("skip the gate", "I'll lint myself"), comply and say that the discipline is bypassed at their request.
- Markdown and Quarto prose has no gate of this kind: the `prose-lint-pretool.sh` hook checks the dash rules on `.md` and `.qmd` edits, and `/workflow:write` is the deeper polish.

## Before writing a helper

- Before writing a helper, check whether something already does the job: first the project (grep for an existing internal helper), then the libraries already in the dependency list. This binds whenever the body is generic mechanics (string casing or normalisation, path manipulation, date arithmetic, set/dedup/sort operations, type coercion, validation, retry/backoff), and never for domain logic, which has no library equivalent. Run the check against the **installed artifact**, not from recall: training memory under-knows what shipped recently and over-trusts the idiom that was current when it formed, so a hand-rolled helper reads as competent while duplicating a function the dependency already exports, and nothing in the lint/format/test gate detects it. Per-language commands in `rules/r.md` and `rules/python.md`. The currency half is not symmetric: an installed R package ships its own `NEWS.md`, so the check is local and free, while a wheel rarely ships a changelog, so Python answers "when did it arrive" by querying the installed version and fetching that project's release notes. When the library function exists but diverges from what the task needs, keeping the hand-rolled version is a legitimate outcome, not a fallback: name the divergence in the tracking note that covers the code and pin it with a test, so the duplication reads as a decision rather than an oversight.
- **Finding nothing on disk closes nothing.** The local check only covers what is already installed, so an empty result proves the capability is absent from the current dependencies, never that it is absent from the ecosystem: concluding otherwise is the reasoning-from-absence failure of `feedback_verify_before_claiming`, applied to code instead of claims. Escalate to the web, ranked by source and never to a bare search whose top hits are years-old forum answers, which would industrialise the stale idiom rather than correct it: a function-level documentation index first where the language has one, then the candidate library's own API reference. Asymmetric again: R has genuine cross-package function indexes (`rules/r.md` names them), Python has none, so `rules/python.md` routes to the stdlib reference and then to the dominant library of the domain. Three constraints on the result. A hit in a package that is not a dependency is a **proposal, never an action**: name it, price it (one more dependency), put the hand-rolled alternative beside it, recommend, and let the user decide, since silently adding a dependency to save a few lines is out of scope. A miss is a **bounded negative**: report "not found in <sources searched>", never "it does not exist". And when the web is unreachable, write the helper and flag the unverified assumption explicitly rather than implying the check passed.

## Tests

- After creating a new non-trivial script or public function: propose writing tests (agent proposes, user decides). Trigger when at least two criteria are met: (a) non-trivial branching logic (>2 conditional cases or >1 conditional transformation, not just argument parsing), (b) public exported function of an R/Python package, (c) script meant to be reused across sessions or by another user (not a one-shot analysis). Exclusions: simple install wrappers in `bin/`, one-shot analysis scripts, patches/refactors of existing code. Framework by context: `bats` for shell, `testthat` for R, `pytest` for Python, `cargo test` for Rust. Tests come before any review the `commit` skill proposes: they validate behavior, the review validates robustness and can point at gaps in the tests.
- **Bug-fix TDD**: when fixing a reported bug in code that already has a test framework configured (existing `tests/` directory, `testthat/`, `*.bats`, etc.), write a failing test that reproduces the bug **before** applying the fix, then fix, then verify the test passes. Reproducing the bug is already required by the "any error must be investigated" rule; the test formalizes that reproduction and prevents regression. Skip when: (a) no test framework exists in the project, (b) the bug is in one-shot analysis code or exploratory scripts, (c) the fix is a one-line typo or trivial rename, (d) the bug is in prose/docs (no executable behavior to test). If the user pushes back ("just fix it", "skip the test"), comply but state that the discipline is being bypassed.
- **Red/green TDD for new package exports**: when adding a new function to a tested R/Python package AND the function will be part of the public API, write a failing test specifying the expected behavior **before** implementing. Triggers (all must hold): (1) project is a package (R: `DESCRIPTION` + `tests/testthat/`; Python: `pyproject.toml` with pytest configured + `tests/` directory), (2) function will be exported (R: `@export` in roxygen, listed in NAMESPACE; Python: in `__all__` or documented as public), (3) behavior is specifiable upfront (clear inputs/outputs, not exploratory). Skip when: (a) internal helper not exported, (b) prototype still iterating on the API shape, (c) one-shot script even if it lives in a package directory, (d) refactor of an existing exported function (tests should already cover it; if not, add tests first as a separate step). When uncertain whether the function is genuinely public API, skip red/green and fall back to the propose-tests-after rule above. If the user pushes back, comply but state that the discipline is being bypassed.
