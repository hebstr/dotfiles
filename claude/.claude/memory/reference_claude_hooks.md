---
name: Claude Code hook event types
description: Reference table of all hook event types in the Claude Code harness, with trigger conditions and matcher scope
type: reference
---

| Event | Trigger | Matcher on |
|---|---|---|
| `SessionStart` | Session start/resume | `startup`, `resume`, `compact`, `clear` |
| `UserPromptSubmit` | Before prompt processing | free text |
| `PreToolUse` | Before tool execution | tool name: `Bash`, `Edit\|Write`, etc. |
| `PostToolUse` | After successful tool execution | same |
| `PostToolUseFailure` | After tool failure | same |
| `Stop` | Claude finishes a response | — |
| `Notification` | Claude needs attention | `permission_prompt`, `idle_prompt` |
| `SubagentStart` / `SubagentStop` | Agent launch/end | agent type |
| `PreCompact` / `PostCompact` | Before/after compaction | — |
| `ConfigChange` | settings.json change | `user_settings`, `project_settings` |
| `SessionEnd` | Session end | — |

Hook types: `command` (shell, exit 0 = OK, exit 2 = blocks), `prompt` (mini-LLM returns `{"ok": true/false}`), `agent` (subagent with tools), `http` (POST to external endpoint).

## MCP servers evaluated (2026-03-26)

| MCP | Verdict | Reason |
|---|---|---|
| **Filesystem** | Rejected | Redundant — Claude already has full filesystem access via Read/Glob/Grep/Bash |
| **GitHub** | Passed on | Only MCP with real added value (issues, PRs, CI); no immediate need at the time |
| **PostgreSQL/DuckDB** | Rejected | No Claude-based data analysis use case at the time |
| **Brave Search** | Rejected | Redundant with native WebSearch/WebFetch |
| **Memory (knowledge graph)** | Rejected | Redundant with auto-memory (markdown files) |
