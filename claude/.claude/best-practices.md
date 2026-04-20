# Claude Code — CLAUDE.md Best Practices

Notes from a review of `~/.claude/CLAUDE.md` (2026-03-27).

## How CLAUDE.md works

- Loaded into Claude's context at session start — it's **advisory**, not enforced
- Three scopes: **global** (`~/.claude/CLAUDE.md`), **project** (`.claude/CLAUDE.md` at project root), **subdirectory** (lazy-loaded when Claude reads files there)
- Ancestor CLAUDE.md files load in full; subdirectory ones load on demand
- Survives context compaction — Claude re-reads from disk after `/compact`
- Target **under 200 lines** per file; beyond ~150 lines, adherence degrades

## What to put where

### Global (`~/.claude/CLAUDE.md`) — personal defaults

- User profile (role, expertise, domains)
- Coding style preferences that apply everywhere (pipe style, indentation, language for code text)
- Communication preferences (tone, language mirroring, verbosity)
- Personal safety guardrails (patient data, reproducibility rules)
- Tool preferences (air, jarl, uv, polars)

### Project (`.claude/CLAUDE.md`) — project-specific

- Build, test, lint, format commands — **highest-impact content**
- Git conventions (commit style, branch naming, PR workflow)
- Project file structure (only non-obvious patterns)
- Architecture decisions specific to this codebase
- Environment variables and their purposes

### `.claude/rules/` — thematic split (when needed)

- Use when a single CLAUDE.md exceeds ~100 lines
- One file per theme: `r-style.md`, `testing.md`, `data-safety.md`
- Path-specific rules possible (e.g., only load for `src/api/`)
- Not needed for small files — premature fragmentation adds complexity

## Best practices

1. **Be concrete and verifiable** — "Use 2-space indentation" not "Format code properly"
2. **Include build/test commands in project CLAUDE.md** — prevents 40% of mistakes
3. **Keep it short** — every line costs context tokens; only document what Claude can't infer from code
4. **One rule per line** — easier to scan, update, and remove
5. **Use `@file.md` imports** for reusable content across projects (max 5 hops)
6. **Separate conversation language from code language** explicitly to avoid ambiguity after compaction
7. **Audit periodically** — remove rules Claude already follows by default (test by deleting and checking behavior)

## Things to avoid

1. **Bloat** — 500+ lines means Claude ignores half of it
2. **Vague rules** — "Write clean code" has zero effect
3. **Contradictions across files** — Claude picks one arbitrarily
4. **Storing secrets** — use `.env`, `.mcp.json` env block (for MCP server keys), or `settings.json` env — never in CLAUDE.md
5. **Duplicating what code says** — file structure, imports, conventions visible in source
6. **Over-specifying** — Claude learns structure by reading code; only document non-obvious patterns
7. **Relying on CLAUDE.md for critical enforcement** — use hooks (`PreToolUse`) for must-never-happen rules

## CLAUDE.md vs other mechanisms

| Need | Use |
|------|-----|
| Code style, conventions, architecture | CLAUDE.md |
| "Must happen every time" (format on save, test before commit) | Hooks |
| Block dangerous actions deterministically | `settings.json` permissions |
| Things Claude learns from corrections | Auto memory |
| Task-specific workflows invoked on demand | Skills |
| Environment variables | `settings.json` env, `.mcp.json` env block |

## Auto memory system

Claude persists information across sessions via memory files in `~/.claude/memory/` (global) and per-project `memory/` directories.

### Memory types

| Type | Lifespan | Content | Example |
|------|----------|---------|---------|
| **user** | permanent | Role, expertise, preferences | "data scientist, R expert, new to React" |
| **feedback** | permanent | Corrections and validations of work approach | "don't propose shared email for LITREV_EMAIL" |
| **project** | temporary | Ongoing initiatives, decisions, deadlines | "litrev skills review pass in progress" |
| **reference** | permanent | Pointers to external resources | "pipeline bugs tracked in Linear project INGEST" |

### Best practices

- `project` memories must be deleted once the work is complete
- Each memory lives in its own file with frontmatter (name, description, type) + a pointer in `MEMORY.md`
- `MEMORY.md` is an index, not content — keep under 200 lines
- Don't save what code or git already tells you (architecture, history, visible conventions)
- Don't duplicate what's in CLAUDE.md

## Gaps identified in current setup (to revisit per-project)

- No build/test/lint commands → add to each project's `.claude/CLAUDE.md`
- No git conventions → add commit language/style if consistent across projects
- No project-level CLAUDE.md files yet → create when starting a new project with Claude
- Consider hooks for: auto-format on file edit, test before commit

## Review outcomes (2026-03-27)

Changes applied to `~/.claude/CLAUDE.md`:
- Condensed References section (3 lines → 1 line, kept citation instruction)
- Clarified "No inline comments" → "No inline comments in code" + separated from roxygen/docstrings
- Clarified "Mirror the user's language" → added "(code always in English)"
- Added `air` (formatter) and `jarl` (linter) to Coding preferences

Rejected findings (with rationale):
- Build/test commands in global → belongs in project CLAUDE.md, not global
- Project file structure → not applicable to a global config
- Move data pitfalls to project scope → these are personal guardrails, transversal
- Use `.claude/rules/` → premature at 42 lines
- Hook for patient data → pattern matching too error-prone, organizational guardrails are better
