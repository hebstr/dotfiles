---
name: Claude Code session forensics, MCP verdicts and the Bash write blind spot
description: "Local Claude Code facts not in upstream docs: probing past sessions through the jsonl transcripts (7-day retention here), the 2026-03-26 MCP server verdicts, PostToolUse on Edit|Write missing files written via Bash, auto mode instructing shell writes against the Edit-or-Write rule, a hook entry arming without a restart, the UserPromptSubmit payload field name with what reaches it besides typed text, the 10,000-character hook output cap and its 2 KB preview, additionalContext reaching the model on every permission decision, a paths: rule loading on a native Read only, and the autoMemoryDirectory load cap, near-cap nudge, frontmatter stamping and symlink asymmetry"
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
- **A hook output above 10,000 characters reaches the model as a 2 KB preview**: the threshold applies to each output separately (`stdout`, `additionalContext`, `systemMessage`), the full text being saved to a file and replaced by a 2,000-character preview that the transcript shows as `persisted-output` (178 transcripts of `~/.claude/projects/` on 2026-09-26, 2.1.283). A 25,684-byte `SessionStart` output got at most 9 of its lines into context. Keep every injected file at or under 9,000 characters
- **`additionalContext` reaches the model in the same turn on every permission decision**: measured 2026-09-26 on 2.1.283 through `claude -p`, on `allow`, `deny`, `ask` and with no `permissionDecision` at all, each run answering with the codeword its hook injected. On `ask`, `permissionDecisionReason` goes to the user and not to Claude, so only `additionalContext` carries a rule to the model there. Under `-p` an `ask` resolves as a denial, so the interactive `ask` a user approves stays unobserved
- **A `paths:` rule loads on a native `Read` only**: creating a file with `Write`, or reading it through `cat`, loads none, measured 2026-09-26 over 30 `claude -p` runs. A self-matching `paths:` (a glob naming the file itself) keeps a rules file from loading at launch, at both user and project level, and reading it directly logs no `path_glob_match`, so its text arrives only as the `Read` output. User-level globs do match files of a project outside the dotfiles repository

## The auto-memory directory

`autoMemoryDirectory` is read from the user settings, with `~/` expansion, and replaces the per-project `~/.claude/projects/<cwd>/memory/`. Read in the binary of 2.1.283 on 2026-09-26 and 2026-09-27, then measured.

- The harness loads that directory's `MEMORY.md` into context up to 200 lines and 25,000 bytes, cuts at the last newline under the limit and tells the model it cut. It counts the index trimmed of trailing whitespace, so `wc -c` over the file is stricter by the trailing newline.
- A near-cap nudge arrives as `PostToolUse` context once the larger of the byte and line fractions reaches 80 % (20,000 bytes, 160 lines), asking to compact under 70 % (17,500 bytes, printed as 17.1KB, or 140 lines). A session that gets it compacts mid-task.
- `stampNewMemoryContent` rewrites a written memory's frontmatter: `originSessionId` and a millisecond `modified` added, `node_type: memory` added, the `name:` title turned into a slug, the `description` quoted.
- A fourth behaviour runs the other way: the edit permission check resolves every spelling of the target path, the symlink target included, and lets an `.md` write skip the permission prompt only when every spelling starts with the configured directory, compared as a string after `~/` expansion, with no `realpath`, and before the protected-path check on `.claude/`.
- All four key on the literal configured path and none follows a symlink, so pointing the setting at the link (`~/.claude/memory`) keeps every memory write prompting and escapes the nudge, the stamp and the per-file checks, while pointing it at the resolved store would silence the prompt and stamp every diff. That asymmetry is why dotfiles names the link and denies writes through it, sending them to the resolved path instead.
- The native per-turn recall, a selector over the memory files' `description`, is gated by a server flag and off on this account; when it is on, the binary drops the index from context and recall runs through that selector instead.

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
