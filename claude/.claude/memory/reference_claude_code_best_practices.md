---
name: Claude Code best practices reference
description: Curated reference on Claude Code internals: CLAUDE.md scopes, hook events and exit codes, auto-memory system, notable settings.json keys, autocompact override
type: reference
---

# Claude Code: CLAUDE.md Best Practices

Last updated: 2026-05-02.

## How CLAUDE.md works

- Loaded into Claude's context at session start: advisory, not enforced
- **Five scopes** (loaded in this order, lowest to highest precedence):
  - Managed/org policy: `/etc/claude-code/CLAUDE.md` (system-wide, cannot be excluded)
  - User: `~/.claude/CLAUDE.md` (all your projects)
  - Project: `.claude/CLAUDE.md` or `CLAUDE.md` at repo root (shared via git)
  - Local project: `.claude/CLAUDE.local.md` (personal, gitignore it)
  - Child directories: loaded on demand when Claude reads files there
- Array settings in `settings.json` **merge** across scopes (concatenate + deduplicate, no override)
- HTML comments (`<!-- ... -->`) are stripped before injection: annotate CLAUDE.md without spending tokens
- Project-root CLAUDE.md is re-read from disk after `/compact`; nested subdirectory CLAUDE.md files are not
- Target **under 200 lines** per file; adherence degrades beyond that
- Use `@path/to/file.md` to import other files (max 5 hops)

## What to put where

### Global (`~/.claude/CLAUDE.md`): personal defaults

- User profile (role, expertise, domains)
- Coding style preferences that apply everywhere (pipe style, indentation, language for code text)
- Communication preferences (tone, language mirroring, verbosity)
- Personal safety guardrails (patient data, reproducibility rules)
- Tool preferences (air, jarl, uv, polars)

### Project (`.claude/CLAUDE.md`): project-specific, in git

- Build, test, lint, format commands: **highest-impact content**
- Git conventions (commit style, branch naming, PR workflow)
- Project file structure (only non-obvious patterns)
- Architecture decisions specific to this codebase
- Environment variables and their purposes

### `.claude/CLAUDE.local.md`: personal project overrides, not in git

- Personal preferences that don't belong in the shared project file

### `.claude/rules/`: thematic split (when needed)

- Use when a single CLAUDE.md exceeds ~100 lines
- One file per theme: `r-style.md`, `testing.md`, `data-safety.md`
- Path-scoped rules via YAML frontmatter (load only when Claude reads a matching file):
  ```yaml
  # frontmatter: paths:
  #   - "src/api/**/*.ts"
  ```

## Best practices

1. **Be concrete and verifiable**: "Use 2-space indentation" not "Format code properly"
2. **Include build/test commands in project CLAUDE.md**: prevents 40% of mistakes
3. **Keep it short**: every line costs context tokens; only document what Claude can't infer from code
4. **Audit periodically**: remove rules Claude already follows by default (delete and check behavior)
5. **Use `IMPORTANT` / `YOU MUST`** to improve adherence for critical rules
6. **Use `@file.md` imports** for reusable content across projects (max 5 hops)
7. **HTML comments** in CLAUDE.md are stripped before injection: use freely for maintainer notes
8. **Separate conversation language from code language** explicitly to survive compaction

## Things to avoid

1. **Bloat**: 500+ lines means Claude ignores half of it; ruthless test: "would removing this cause mistakes?"
2. **Vague rules**: "Write clean code" has zero effect
3. **Contradictions across files**: Claude picks one arbitrarily
4. **Storing secrets**: use `.env`, `.mcp.json` env block, or `settings.json` env (never in CLAUDE.md)
5. **Duplicating what code says**: file structure, imports, conventions visible in source
6. **Relying on CLAUDE.md for critical enforcement**: use hooks for must-never-happen rules
7. **Correcting more than twice**: after two failed corrections, `/clear` and write a better prompt

## CLAUDE.md vs other mechanisms

| Need | Use |
|------|-----|
| Code style, conventions, architecture | CLAUDE.md |
| "Must happen every time" (format on save, test before commit) | Hooks |
| Block dangerous actions deterministically | `settings.json` permissions |
| Things Claude learns from corrections | Auto memory |
| Task-specific workflows invoked on demand | Skills |
| Environment variables | `settings.json` env, `.mcp.json` env block |
| Personal project overrides not shared via git | `.claude/CLAUDE.local.md` |

## Hooks

### Event list (28 events as of 2026)

**Session lifecycle**: `SessionStart` (matcher: `startup|resume|clear|compact`), `Setup`, `SessionEnd`
**Per-turn**: `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`
**Agentic loop**: `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `SubagentStart`, `SubagentStop`
**Reactive**: `Notification`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `InstructionsLoaded`, `Elicitation`, `ElicitationResult`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`

**Handler types**: `command` (shell), `http` (POST), `prompt` (LLM yes/no), `agent` (subagent, experimental)

### Exit codes

- `0`: proceed; stdout is injected as context on `UserPromptSubmit` and `SessionStart`
- `2`: block the action; write reason to stderr (Claude receives it as feedback)
- Any other non-zero: non-blocking error (Claude sees a notice but continues)

**Exit code `1` does NOT block. Use `2` to enforce policy.**

### Structured JSON output

For `PreToolUse`, a hook can return JSON instead of relying on exit codes:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Use rg instead of grep"
  }
}
```
`permissionDecision` values: `"allow"`, `"deny"`, `"ask"`, `"defer"` (non-interactive only).

### Key patterns

- **Re-inject context after compact**: `SessionStart` with `matcher: "compact"` to echo reminders
- **direnv integration**: `CwdChanged` + `$CLAUDE_ENV_FILE` (append `export VAR=value` lines to persist env)
- **Stop hooks infinite loop**: always check `jq -r '.stop_hook_active'` and exit 0 when true
- **Catch all file writes**: `PostToolUse` on `Edit|Write` misses files written via `Bash`; match `Bash` too, or use a `Stop` hook on `git status --porcelain`
- **`PermissionRequest` hooks don't fire with `-p`** (non-interactive); use `PreToolUse` instead
- **Debugging hooks**: `claude --debug-file /tmp/claude.log` logs full hook execution details

### Gotchas

- Hooks run before permission-mode checks: a hook `deny` blocks even in `bypassPermissions` mode
- Shell profile unconditional `echo` statements break JSON parsing; wrap in `if [[ $- == *i* ]]`
- `PostToolBatch` fires after a parallel tool batch and can block the loop

## Auto memory system

Claude persists information across sessions via memory files in `~/.claude/memory/` (single source of truth, stow-managed under `~/dotfiles/claude/.claude/memory/`). The harness still auto-loads `MEMORY.md` from per-project paths like `~/.claude/projects/<cwd>/memory/` at session start, but those are read-only redirect stubs; never write new memory there.

### Memory types

| Type | Lifespan | Content |
|------|----------|---------|
| **user** | permanent | Role, expertise, preferences |
| **feedback** | permanent | Corrections and validations of work approach |
| **project** | temporary | Ongoing initiatives, decisions, deadlines |
| **reference** | permanent | Pointers to external resources |

### Best practices

- `MEMORY.md` index: first 200 lines or 25 KB loaded at every session start; keep concise
- Topic files (e.g. `debugging.md`) are NOT loaded at startup; Claude reads them on demand
- `project` memories must be deleted once the work is complete
- Each memory lives in its own file with frontmatter (name, description, type) + pointer in `~/.claude/memory/MEMORY.md` (the canonical index; per-project `MEMORY.md` is a redirect stub only)
- Don't save what code or git already tells you (architecture, history, visible conventions)
- Don't duplicate what's in CLAUDE.md
- `autoMemoryEnabled: false` in settings to disable; or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`
- `autoDreamEnabled: true` enables a memory consolidation pass (gates: 24h gap + 5 sessions + exclusive lock). Stale `.consolidate-lock` files in `~/.claude/projects/*/memory/` from crashed passes are swept at SessionStart by `claude/.claude/hooks/sweep-stale-consolidate-locks.sh`, logged to `~/.claude/logs/dream-sweeper.log`.

## Notable settings.json keys

Full reference: `code.claude.com/docs/en/settings`.
JSON schema for IDE validation: `"$schema": "https://json.schemastore.org/claude-code-settings.json"`.

| Key | Notes |
|-----|-------|
| `effortLevel` | `"low"`, `"medium"`, `"high"`, `"xhigh"` (persists thinking effort across sessions) |
| `alwaysThinkingEnabled` | `true` enables extended thinking by default |
| `showThinkingSummaries` | surface extended thinking summaries |
| `autoMemoryEnabled` | toggle auto memory |
| `autoMemoryDirectory` | custom memory path (accepted in user/local settings only, not project settings) |
| `claudeMdExcludes` | skip CLAUDE.md files by glob (useful in monorepos); arrays merge across scopes |
| `attribution` | replaces deprecated `includeCoAuthoredBy`; `{"commit": "", "pr": ""}` to hide both |
| `plansDirectory` | custom plan storage path |
| `disableAllHooks` | disable all hooks without removing config |
| `cleanupPeriodDays` | session file retention; default 30, min 1 |

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

Moves compaction threshold **earlier only**: the internal cap is ~83-85%. Values above that have no effect. Community sweet spot: `75` for general dev, `65-70` for debugging-heavy sessions.

## Gaps identified in current setup

- No build/test/lint commands → add to each project's `.claude/CLAUDE.md`
- No git conventions → add commit language/style if consistent across projects
