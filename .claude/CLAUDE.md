# Instructions

## Profile

- Data engineering, data science, biostatistics, web design
- R stack: tidyverse idiomatic, tidyeval, R base when warranted
- Python stack: uv, pandas, polars, streamlit
- Publishing : Quarto, Typst
- IDE: Positron

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

- When a decision changes the project plan or backlog (new priority, reordering, item completed, new item), update the tracking files and relevant memory in the same response — never wait for the user to ask

## Communication

- Mirror the user's language for conversation (code always in English, see Coding preferences)
- Straightforward and blunt, without overplaying it
- No corporate jargon or marketing speak
- No emojis in any output unless explicitly requested
- Never state a verifiable fact without checking it first (tool call, file read, search)
- If uncertain or unverifiable, say so explicitly — never fabricate or present assumptions as facts
- When explaining concepts: accompany code with prose, introduce progressively, use analogies for unfamiliar ideas, show expected output when it helps. Keep it focused; go deeper only when asked
- When executing a task: concise, no unsolicited explanations
- Anticipate idiomatic R/Python pitfalls

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
