---
name: Claude Code session forensics, MCP verdicts and the Bash write blind spot
description: "Local Claude Code facts not in upstream docs: probing past sessions through the jsonl transcripts (7-day retention here), the 2026-03-26 MCP server verdicts, PostToolUse on Edit|Write missing files written via Bash, auto mode instructing shell writes against the Edit-or-Write rule, a hook entry arming without a restart, and the UserPromptSubmit payload field name with what reaches it besides typed text"
metadata:
  type: reference
---

# Claude Code: local facts

## Hooks

- **Catch all file writes**: `PostToolUse` on `Edit|Write` misses files written via `Bash`; match `Bash` too, or use a `Stop` hook on `git status --porcelain`
- **A new hook entry takes effect without a restart**: adding a hook to `settings.json` mid-session arms it for the rest of that same session, observed three times (2026-09-22, 09-23 and 09-26, each on the session that registered the hook)
- **`UserPromptSubmit` payload field is `prompt`**: read from the raw `hooks.md`; a WebFetch summary of that page gave `user_prompt`, which does not exist. For a payload field name, read the hooks doc raw, never a summary of it
- **`UserPromptSubmit` does not mean the user typed it**: a subagent hand-back fires the event too (observed 2026-09-22, a `/commit` verifier report quoting the user's own wording triggered a hook keyed on that wording). What arrives there beyond typed text: `<agent-message>`, `<cross-session-message>`, `<task-notification>` and `<pasted_content>` blocks, plus the harness markers `Stop hook feedback:`, `<command-message>`, `<bash-input>` and `<local-command`. Two of those four markers are not tag pairs (a bare prefix, an unclosed opener) and a `<command-message>` carries its arguments in a following `<command-args>`, so a hook that must ignore them drops the whole prompt rather than stripping a tag pair. That these wrappers reach `prompt` exactly as the transcript shows them is inferred from the transcript, never measured on the payload
- **Auto mode instructs the opposite**: entering auto mode injects a harness message telling Claude to change files with `sed`, heredocs or short scripts instead of `Edit`/`Write`, which contradicts the `CLAUDE.md` bullet that covers auto mode explicitly. Blocking shell writes deterministically is not the cheap fix: the mandated lint gate writes from the shell too (`shfmt -w`, `ruff format`, `shellharden --replace`), so any rule has to separate shell constructs (`sed -i`, redirection, heredoc, `tee`) from a formatter's own flag. Decided 2026-09-28 in dotfiles, `.claude/DESIGN-INSTRUCTION-ROUTING.md`: no mechanism, the rule stays prose, and the lever is that `defaultMode` is `default`, so not entering auto mode removes the instruction at its source

## Session transcript forensics

Past sessions of a project live as one `.jsonl` per session in `~/.claude/projects/<slugified-cwd>/`.
This is the authoritative record for "did X ever actually run?", which git history cannot answer for
anything that produced no commit (an audit, a review, an abandoned attempt).

- **Was a slash command invoked, and with what target?** Invocations are logged as `<command-name>/foo</command-name>`
  plus a separate `<command-args>...</command-args>`. Listing the distinct arg strings is the reliable probe:
  `rg -o "command-args>[^<]{0,150}" ~/.claude/projects/<proj>/*.jsonl | sed 's/.*command-args>//' | sort -u`.
  Grepping the command name alone is useless: it matches every conversational mention of the command,
  including skill descriptions and my own suggestions to run it.
- **Date a session**: first and last `"timestamp"` fields of the file.
- **Read the opening user turns** (what the session was actually for):
  `jq -r 'select(.type=="user") | .message.content | if type=="string" then . else (.[]? | select(.type=="text") | .text) end' <file>.jsonl | head`.
- **Caveat**: a review run in walkthrough-only mode, or a reviewer spawned as a subagent, leaves no
  `command-args` trail. Absence of the marker means "not invoked as a targeted slash command", not
  "never reviewed". Cross-check the opening user turns before concluding.

Retention is bounded by `cleanupPeriodDays`, set to 7 in `~/dotfiles/claude/.claude/settings.json` (upstream default 30), so this only works on the last week of history.

## MCP servers evaluated (2026-03-26)

```
| MCP | Verdict | Reason |
|---|---|---|
| **Filesystem** | Rejected | Redundant: Claude already has full filesystem access via Read/Glob/Grep/Bash |
| **GitHub** | Passed on | Only MCP with real added value (issues, PRs, CI); no immediate need at the time |
| **PostgreSQL/DuckDB** | Rejected | No Claude-based data analysis use case at the time |
| **Brave Search** | Rejected | Redundant with native WebSearch/WebFetch |
| **Memory (knowledge graph)** | Rejected | Redundant with auto-memory (markdown files) |
```
