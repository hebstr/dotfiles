---
name: Claude Code session forensics, MCP verdicts and the Bash write blind spot
description: "Local Claude Code facts not in upstream docs: probing past sessions through the jsonl transcripts (7-day retention here), reading the current session's context occupancy from its transcript usage fields, the 2026-03-26 MCP server verdicts, PostToolUse on Edit|Write missing files written via Bash, auto mode instructing shell writes against the Edit-or-Write rule, the auto mode classifier being a layer `permissions.allow` does not satisfy and the `autoMode` block that steers it, a hook entry arming without a restart, the UserPromptSubmit payload field name with what reaches it besides typed text, the three self-started turns that fire the event with compaction excluded, a hook firing being unverifiable from the transcripts, the 10,000-character hook output cap and its 2 KB preview, additionalContext reaching the model on every permission decision, a paths: rule loading on a native Read only, the autoMemoryDirectory load cap, near-cap nudge, frontmatter stamping and symlink asymmetry, and the subagent facts that decide where an orchestrating step runs (fork mode by default, no AskUserQuestion in any subagent, Skill and Agent kept to depth 3)"
metadata:
  type: reference
---

# Claude Code: local facts

## Hooks

- **Catch all file writes**: `PostToolUse` on `Edit|Write` misses files written via `Bash`; match `Bash` too, or use a `Stop` hook on `git status --porcelain`
- **A new hook entry takes effect without a restart**: adding a hook to `settings.json` mid-session arms it for the rest of that same session, observed three times (2026-09-22, 09-23 and 09-26, each on the session that registered the hook)
- **`UserPromptSubmit` payload field is `prompt`**: read from the raw `hooks.md`; a WebFetch summary of that page gave `user_prompt`, which does not exist. For a payload field name, read the hooks doc raw, never a summary of it
- **`UserPromptSubmit` does not mean the user typed it**: a subagent hand-back fires the event too (observed 2026-09-22, a `/commit` verifier report quoting the user's own wording triggered a hook keyed on that wording). What arrives there beyond typed text: `<agent-message>`, `<cross-session-message>`, `<task-notification>` and `<pasted_content>` blocks, plus the harness markers `Stop hook feedback:`, `<command-message>`, `<bash-input>` and `<local-command`. Two of those four markers are not tag pairs (a bare prefix, an unclosed opener) and a `<command-message>` carries its arguments in a following `<command-args>`, so a hook that must ignore them drops the whole prompt rather than stripping a tag pair. That these wrappers reach `prompt` exactly as the transcript shows them is inferred from the transcript, never measured on the payload
- **The self-started turns that fire `UserPromptSubmit` are exactly three**, per the event's own section of the hooks doc (read 2026-10-11): a scheduled task firing, a `/loop` iteration included; a background subagent reporting back to the session that started it; a message another session sends to the main conversation. A conversation-compaction continuation turn is **not** one of them, so the auto-generated "This session is being continued from a previous conversation" summary never reaches a `UserPromptSubmit` hook, however many `/name` tokens it quotes from past invocations. That bounds what a hook stripping relayed text has to cover: the three wrapper tags of those turns plus `<pasted_content>`. The event table's one-line claim ("Also fires on turns Claude Code starts on its own") names none of them, so read the `UserPromptSubmit` section and never the table
- **A hook firing is not confirmable from the transcripts.** No `UserPromptSubmit` `additionalContext` was found in any retained transcript: every match for a hook's own injected text sits in a `tool_result` of a session that read the script, never in an `isMeta: true` turn companion. So absence of a hook's text beside a prompt is not evidence the hook stayed silent, and a corpus test of the form "did this hook fire on that turn?" is inconclusive by construction. Settle such a question by running the hook offline on the extracted prompt, or from the doc, never from the transcript
- **Auto mode instructs the opposite**: entering auto mode injects a harness message telling Claude to change files with `sed`, heredocs or short scripts instead of `Edit`/`Write`. The `CLAUDE.md` bullet decides it, exempts it from "name the conflict" and bans the announcement; why no mechanism enforces it, and why `defaultMode: default` is the real lever, is in `.claude/DESIGN-INSTRUCTION-ROUTING.md`
- **The auto mode classifier is a layer of its own, and `permissions.allow` does not satisfy it**: with `"Bash"` already in `permissions.allow`, the classifier still refused `git status --short` mid-commit-sequence on 2026-10-06 with `[Auto-Mode Bypass]`, and refused the narrower retry as a workaround of the first refusal, so adding `Bash(git status:*)` rules would have been inert. Its lever is the `autoMode` block of `settings.json` (`allow`, `soft_deny`, `hard_deny`, `environment`, `classifyAllShell`), whose lists replace the built-in prompt sections unless they carry the literal `"$defaults"` at the position where the built-ins should sit. Added there the same day for read-only git inspection (`git status`, `diff`, `log`, `show`, `rev-parse`, `ls-files`, `check-ignore`); the `deny` rules on git writes are untouched by it (41 of the 50 `permissions.deny` entries match `git` on 2026-10-09)
- **A hook output above 10,000 characters reaches the model as a 2 KB preview**: the threshold applies to each output separately (`stdout`, `additionalContext`, `systemMessage`), the full text being saved to a file and replaced by a 2,000-character preview that the transcript shows as `persisted-output` (178 transcripts of `~/.claude/projects/` on 2026-09-26, 2.1.283). A 25,684-byte `SessionStart` output got at most 9 of its lines into context. Keep every injected file at or under 9,000 characters
- **`additionalContext` reaches the model in the same turn on every permission decision**: measured 2026-09-26 on 2.1.283 through `claude -p`, on `allow`, `deny`, `ask` and with no `permissionDecision` at all, each run answering with the codeword its hook injected. On `ask`, `permissionDecisionReason` goes to the user and not to Claude, so only `additionalContext` carries a rule to the model there. Under `-p` an `ask` resolves as a denial, so the interactive `ask` a user approves stays unobserved
- **A self-matching `paths:` glob is a trap** (the Read-only trigger itself is in `CLAUDE.md` § Environment and `rules/claude-files.md`, measured here over 30 `claude -p` runs): a glob naming the file itself keeps a rules file from loading at launch, at both user and project level, and reading it directly logs no `path_glob_match`, so its text arrives only as the `Read` output. User-level globs do match files of a project outside the dotfiles repository

## The auto-memory directory

`autoMemoryDirectory` is read from the user settings, with `~/` expansion, and replaces the per-project `~/.claude/projects/<cwd>/memory/`. Read in the binary of 2.1.283 on 2026-09-26 and 2026-09-27, then measured.

- The harness cuts the loaded `MEMORY.md` at the last newline under its limit and tells the model it cut. It counts the index trimmed of trailing whitespace, so `wc -c` over the file is stricter by the trailing newline. The thresholds themselves are in `rules/memory.md`.
- A near-cap nudge arrives as `PostToolUse` context once the larger of the byte and line fractions reaches 80 % (20,000 bytes, 160 lines), asking to compact under 70 % (17,500 bytes, printed as 17.1KB, or 140 lines). A session that gets it compacts mid-task.
- `stampNewMemoryContent` rewrites a written memory's frontmatter: `originSessionId` and a millisecond `modified` added, `node_type: memory` added, the `name:` title turned into a slug, the `description` quoted.
- A fourth behaviour runs the other way: the edit permission check resolves every spelling of the target path, the symlink target included, and lets an `.md` write skip the permission prompt only when every spelling starts with the configured directory, compared as a string after `~/` expansion, with no `realpath`, and before the protected-path check on `.claude/`.
- All four key on the literal configured path and none follows a symlink, so pointing the setting at the link (`~/.claude/memory`) keeps every memory write prompting and escapes the nudge, the stamp and the per-file checks, while pointing it at the resolved store would silence the prompt and stamp every diff. That asymmetry is why dotfiles names the link and denies writes through it, sending them to the resolved path instead.
- The native per-turn recall, a selector over the memory files' `description`, is gated by a server flag and off on this account; when it is on, the binary drops the index from context and recall runs through that selector instead.

## Subagents

Read on the official sub-agents doc page on 2026-09-14, against 2.1.232, and not re-derived since; a skill that orchestrates agents is built on them, so re-check before relying on one.

- **Fork mode is the default in an interactive session**, so every `Agent` call starts in the background and Claude cannot ask for the foreground. `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` is the only lever back.
- **`AskUserQuestion` is removed from every subagent**, with no exception. A step that has to question the user therefore belongs in the main context: that is why the `audit:walkthrough` orchestrator and its batch-triage and bridge steps run there, and only the reviewer goes to an `Agent`.
- **A background subagent keeps `Skill` and `Agent`**, nesting to depth 3. What stays unmeasured is the notification path: whether a subagent can launch background `Agent` calls of its own *and* receive their completion notifications. The `audit/sweep` Phase 1 fan-out depends on it when a sweep is itself spawned as a reviewer, and the open row of `~/Documents/packages/claude-code-plugins/.claude/DEFERRED.md` asks for that measurement.

## Session transcript forensics

Past sessions of a project live as one `.jsonl` per session in `~/.claude/projects/<slugified-cwd>/`.
This is the authoritative record for "did X ever actually run?", which git history cannot answer for
anything that produced no commit (an audit, a review, an abandoned attempt).

- **Was a slash command invoked, and with what target?** Invocations are logged as `<command-name>/foo</command-name>`
  plus a separate `<command-args>...</command-args>`. Listing the distinct arg strings is the reliable probe:
  `rg -o "command-args>[^<]{0,150}" ~/.claude/projects/<proj>/*.jsonl | sed 's/.*command-args>//' | sort -u`.
  Grepping the command name alone is useless: it matches every conversational mention of the command,
  including skill descriptions and my own suggestions to run it.
- **Read the context occupancy of the session you are in.** Each assistant entry carries `.message.usage`, and the last one's `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` is the context sent on that request:
  `jq -r 'select(.message.usage) | (.message.usage.input_tokens + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0))' <session>.jsonl | tail -1`.
  Measured 600,359 tokens on a 320-turn session whose transcript was 5.3 MB (2026-09-30), matching the figure the user's own display showed. Two things are not it: the `<total_tokens>` line of the prompt, which is a per-turn budget, and the transcript's byte size, which gives an order of magnitude at best. Never answer that the context load cannot be measured; it is one `jq` away, and the answer decides whether to continue a long session or hand it to a fresh one.
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
