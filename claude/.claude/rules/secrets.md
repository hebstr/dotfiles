# Secret files handling

On-demand reference for handling files containing credentials. Load when a file path matches the scope patterns declared in CLAUDE.md or the user flags a file as containing a secret.

## Why

Any output from Bash/Read lands in the conversation transcript and the local jsonl log under `~/.claude/projects/`; once written there, treating the secret as compromised is the only safe assumption.

## Rules

- **Forbidden without masking** on any path in scope: `cat`, `head`, `tail`, `less`, `Read` tool, `grep`/`rg` **without** `-l`, `sort`, `diff`, or any command that prints file content to stdout/stderr. Never `echo "$SECRET_VAR"` either.
- **Secrets in environment variables.** Prefer passing secrets via stdin or temporary files over CLI arguments: argv is visible in `ps aux` and may be logged by the receiving tool. Be cautious of any tool that logs its environment or arguments verbosely. Shell history: secrets typed as command arguments persist in `~/.bash_history` / `~/.zsh_history` unless prefixed with a leading space (under `HISTCONTROL=ignorespace`) or rotated out.
- **Allowed** because they don't emit the value: `sed -i` for in-place edits, `wc -l` for line counts, `ls -la` for permissions/size, `rg -l` / `grep -l` for matching filenames only, listing variable names via a masking pipe (`sed -E 's/=.*$/=***/' <file>`).
- **Searching for which file defines a secret**: use `rg -l 'VAR_NAME' …` (filenames only). Never `rg -n 'VAR_NAME=value-pattern'`; `-n` emits the matched line in clear.
- **Backups before destructive edits**: do not `cp` a secret file to a sibling backup; the copy persists in clear on disk. If a backup is genuinely required, redirect through a masking pipe first (`sed -E 's/=.*$/=***/' .secrets > .secrets.names.bak`) OR plan to `shred -u` the copy immediately after the edit completes (in the same tool call, not a follow-up).
- **Editing secret files**: prefer `sed -i '/pattern/d'` or `sed -i 's/old/new/'` over Edit/Write; those tools require a prior Read which would leak the file. If a structural edit beyond sed is required, ask the user to do it manually.
- **When in doubt**, assume the file is a secret and ask the user before reading. The cost of asking is one round-trip; the cost of leaking is a key rotation, transcript scrubbing, and a security incident.
