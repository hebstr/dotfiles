# Instructions

## Profile

- Data engineering, data science, biostatistics, web design
- R stack: tidyverse idiomatic, tidyeval, R base when warranted
- Python stack: uv, pandas, polars, streamlit
- Publishing : Quarto, Typst
- IDE: Positron

## Environment

### System

- OS: Ubuntu 24.04 LTS, x86_64

### Runtimes

| Tool   | Version | Usage |
|--------|---------|-------|
| R      | 4.6.0   | Data processing, statistical analysis |
| Python | 3.13.9  | NLP pipeline (langchain + ollama), data manipulation |
| Quarto | 1.9.37  | Book generation (HTML via `quarto render`) |
| Typst  | 0.14.2  | PDF typesetting (via Quarto) |

### Package management

**R**

| Tool | Notes |
|------|-------|
| pak  | Default package installer (`pak::pak()`) |
| rv   | Lockfile: `rv.lock`, config: `rproject.toml` |
| renv | Lockfile: `renv.lock` (legacy projects) |

- CRAN mirror: `https://packagemanager.posit.co/cran/__linux__/noble/latest` (PPM, Linux noble binaries)

**Python**

| Tool | Notes |
|------|-------|
| uv   | Lockfile: `uv.lock`, config: `pyproject.toml` |

### CLI tools available

| Tool    | Role                                      |
|---------|-------------------------------------------|
| git     | Version control                           |
| gh      | GitHub CLI (PRs, issues, releases)        |
| ripgrep | Fast code search (`rg`)                   |
| uv      | Python package/project manager            |
| ruff    | Python linter/formatter (via uv)          |
| air     | R formatter                               |
| jarl    | R linter                                  |
| delta   | Structured diffs with line numbers        |
| fd      | File search by name (`fdfind`)            |
| jq      | JSON processor                            |
| duckdb  | SQL queries from shell (`~/.local/bin/duckdb`) |
| rig     | R version manager (`rig default <version>`)    |
| stow    | Symlink manager for dotfiles (`~/dotfiles`)    |
| shellcheck  | Shell linter (analyse statique, codes `SC*`) |
| shellharden | Auto-fix du quoting des variables shell      |
| shfmt       | Formateur shell (indentation, espacement)    |
| prek        | Pre-commit hooks runner (Rust, remplace pre-commit) |
| bats        | Bash TDD framework |

### Shell search preferences

- **Prefer `rg` over `grep`** for code/text search in Bash. Faster, respects `.gitignore`, sensible defaults.
- **Prefer `fdfind` over `find`** for file discovery in Bash. Faster, respects `.gitignore`, simpler syntax.
- Applies to every Bash invocation — including quick one-liners. Do not default to `grep`/`find` out of habit.
- Fallback rule: if `rg`/`fdfind` is not installed on the current machine (e.g. `command -v rg` fails), use `grep`/`find`. Also fall back when the query needs a feature the modern tool doesn't support (e.g. `find -exec`, filesystem predicates).

### Dotfiles & symlinks

- Dotfiles live in `~/dotfiles`, organized as stow packages (`bin`, `bash`, `claude`, `gh`, `git`, `positron`, `R`, `Rstudio`, `syncthing`).
- Always use `stow` to create symlinks from `~/dotfiles` — never `ln -s` directly. Place files inside the package using the target-relative layout (e.g. `~/dotfiles/bin/.local/bin/foo.sh`), then `cd ~/dotfiles && stow <package>`. If a manual symlink or file already exists at the target, `rm` it before stowing.

## Coding preferences

- No inline comments in code
- Code text (variables, roxygen/docstrings, section headers) in English
- Memory files (.claude/memory/) in English — they are instructions for Claude, not user-facing content
- R: use native pipe `|>`
- R: use the lambda shorthand `\()` instead of `function()`; inside purrr map/walk, prefer tilde formula `~ .x` for simple expressions
- R: use `here::here()` for paths, never absolute paths
- R: format with `air`, lint with `jarl` (configs in air.toml)
- Python: prefer polars over pandas unless the project already uses pandas
- Only modify code directly related to the task, don't refactor surrounding code
- No manual soft wraps in .md/.qmd files — one sentence or logical unit per line, no artificial line breaks
- No cosmetic whitespace padding for alignment (e.g. aligning inline comments with extra spaces) unless explicitly requested
- Never use deprecated config keys, syntax, APIs, or CLI flags — always use the current recommended form. When unsure, verify against current docs before writing

## Data & review pitfalls

- Joins: always use explicit keys, check for NA on join keys after every join
- Domain-specific regex or business rules: do not "fix" or tighten without explicit domain validation
- LLM inference parameters (temperature, top_p, seed): do not change without documented justification — breaks reproducibility of existing results
- Calculated approximations (e.g. age from date diff / 365.25): flag but do not auto-correct — often intentional for consistency with institutional conventions
- Never run git write commands (commit, add, push, reset, branch, tag, merge, rebase, PR creation) — user manages all git operations. A "y" or "ok" in conversation is not authorization to run git write commands

## Plan & memory discipline

- **Claude-related markdown files live in `.claude/` by default** (CLAUDE.md, PLAN.md, MEMORY.md, handoff docs, etc.). The project root is accepted as legacy location — when encountered, read it in place but do not re-introduce root-level Claude files. When creating a new Claude-related file, always default to `.claude/`.
- At session start, look for `PLAN.md` in `.claude/PLAN.md` (preferred) or at the project root (legacy). Read whichever exists and display: current objective, current step, and any blockers. Do not ask the user what to read — just do it. If no `PLAN.md` exists and the task involves multiple sequential steps spanning more than one session, propose creating one — default location is `.claude/PLAN.md`.
- When a step is completed, an item is deferred, a priority changes, or a blocker appears, update **all affected tracking files and memory** in the same response — never wait for the user to ask. "All affected" means: any markdown file at the project root that tracks plan state, backlog, or deferred items, plus any memory file whose content is now stale. If unsure whether a file is affected, read it and check.
- After a structural change (new file, renamed tool/function, moved path, added/removed phase), verify consistency of directly affected files **and check for side effects** in files that reference the changed entity (grep for the old name/path across the project). Do this before marking the step complete — check as you go, not after the fact.
- Concrete post-change greps — all mandatory, not optional:
  1. Old counts (e.g. "12 tools" → update to new count)
  2. "planned"/"todo" references to the feature just implemented → mark done
  3. README/doc tables listing the changed entities → add/remove/rename entries
  4. Permission/config files that gate the changed capability (allowed-tools, DESCRIPTION Imports, `__all__`, manifests, rbac configs) → grant access where appropriate
  5. Instructions or docs that describe limitations now lifted by the change (e.g. "Do NOT do X", "ask user to provide X manually", "planned for later") → update to reflect new capability
- When compacting, always preserve: current objective and active step from PLAN.md, list of modified files, and active constraints or blockers.

## Communication

- Mirror the user's language for conversation (code always in English, see Coding preferences). Always use proper diacritics regardless of input quality — write "étapes" even if the user wrote "etapes".
- Straightforward and blunt, without overplaying it
- No corporate jargon or marketing speak
- No emojis in any output unless explicitly requested
- Never state a verifiable fact without checking it first (tool call, file read, search)
- If uncertain or unverifiable, say so explicitly — never fabricate or present assumptions as facts
- Never say "fix appliqué" / "fix applied" unless an Edit/Write has actually modified a file. When the change requires user action (git command to run, manual edit), phrase it as "à appliquer par toi" / "voici la commande à exécuter" — the user manages their own git operations and needs accurate status
- When explaining concepts: accompany code with prose, introduce progressively, use analogies for unfamiliar ideas, show expected output when it helps. Keep it focused; go deeper only when asked
- When executing a task: concise, no unsolicited explanations
- Anticipate idiomatic R/Python pitfalls
- Avoid em dashes (`—`) and en dashes used as punctuation in prose. They are an AI tic that makes text feel synthetic and unpleasant for humans. Use colons, parentheses, periods, or simply restructure the sentence. En dashes for numeric ranges (`1–2 min`) are fine. This applies in every language

## Prose hygiene

Concrete anti-AI-slop patterns to avoid in all prose Claude writes. Applies to both English and French. Full reference in the `/write` skill — these are the always-on essentials.

- **No negative parallelism.** "Not X. Y." / "Ce n'est pas X. C'est Y." — the most common AI tell. State Y directly.
- **No rhetorical self-questions.** "The result? Devastating." / "Le résultat ? Spectaculaire." — state the answer.
- **No ritual openers.** Drop "It's worth noting", "Notably,", "Importantly," / "Il convient de noter", "Force est de constater", "À noter que", "Il importe de souligner".
- **No conclusion announcements.** Drop "In conclusion", "To sum up" / "En somme", "Pour conclure". Just end.
- **Drop empty intensifiers.** "quietly", "fundamentally", "remarkably", "literally", "genuinely" / "véritablement", "particulièrement", "résolument", "pleinement". Usually deletable without loss.
- **Plain verbs over puffed.** "use" not "leverage/utilize/harness" ; "show" not "demonstrate". In FR : "utiliser" pas "leverager", "traiter" pas "adresser (un problème)", "prendre en charge" pas "supporter (une feature)", "ça a du sens" pas "ça fait du sens", "certainement" pas "définitivement" (au sens de *certainly*).
- **No "véritable/real + N" filler.** "Un véritable défi" → "un défi". "A real challenge" → "a challenge".
- **No transformation clichés.** "X révolutionne/redéfinit/bouleverse Y", "X revolutionizes/redefines Y" — describe the actual mechanism instead.
- **No false agency.** "the data tells us" / "le constat est sans appel" — name the human or supply the evidence.
- **For deep polish or full prose review, invoke `/write`** — auto-loads complete EN/FR/ZH reference based on detected language. Don't try to recall the full skill from memory.

## Agents

- When the user asks to "spawn agents", "lance des agents", or requests parallel work: always use the Agent tool — do not do the work sequentially yourself
- For any task involving reading more than ~5 files to produce a synthesis (audit, review, doc generation): proactively propose parallel agents split by facet
- Each agent prompt must target a non-overlapping facet — avoid giving the same broad prompt to multiple agents
- 2-4 parallel agents is the sweet spot; beyond that, fusion becomes the bottleneck
- Use background mode for exploration, foreground when results feed into the next step
- Agent type selection: `Explore` (haiku) for fast code scanning, `ouroboros:qa-judge` for structured verdicts with score, `ouroboros:architect` for system-level design views, `general-purpose` for complex multi-step tasks
- Agents do not survive session interruptions and cannot communicate with each other — plan for partial failures and bridge results in the main context

## References

- When explaining or grounding a claim, cite authoritative sources (e.g., official docs, r4ds, adv-r, tidyverse/tidymodels docs, PEP)

<!-- ooo:START -->
<!-- ooo:VERSION:0.27.0 -->
# Ouroboros — Specification-First AI Development

> Before telling AI what to build, define what should be built.
> As Socrates asked 2,500 years ago — "What do you truly know?"
> Ouroboros turns that question into an evolutionary AI workflow engine.

Most AI coding fails at the input, not the output. Ouroboros fixes this by
**exposing hidden assumptions before any code is written**.

1. **Socratic Clarity** — Question until ambiguity ≤ 0.2
2. **Ontological Precision** — Solve the root problem, not symptoms
3. **Evolutionary Loops** — Each evaluation cycle feeds back into better specs

```
Interview → Seed → Execute → Evaluate
    ↑                           ↓
    └─── Evolutionary Loop ─────┘
```

## ooo Commands

Each command loads its agent/MCP on-demand. Details in each skill file.

| Command | Loads |
|---------|-------|
| `ooo` | — |
| `ooo interview` | `ouroboros:socratic-interviewer` |
| `ooo seed` | `ouroboros:seed-architect` |
| `ooo run` | MCP required |
| `ooo evolve` | MCP: `evolve_step` |
| `ooo evaluate` | `ouroboros:evaluator` |
| `ooo unstuck` | `ouroboros:{persona}` |
| `ooo status` | MCP: `session_status` |
| `ooo setup` | — |
| `ooo help` | — |

## Agents

Loaded on-demand — not preloaded.

**Core**: socratic-interviewer, ontologist, seed-architect, evaluator,
wonder, reflect, advocate, contrarian, judge
**Support**: hacker, simplifier, researcher, architect
<!-- ooo:END -->
