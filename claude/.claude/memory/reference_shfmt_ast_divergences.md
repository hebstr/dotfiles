---
name: shfmt syntax tree traps for a bash command parser
description: shfmt 3.8.0 `--to-json` joins the line after a comment ending in a backslash (bash does not); what its tree leaves raw
metadata:
  type: reference
---

`shfmt -ln bash --to-json` (3.8.0, the apt build on Ubuntu 24.04) is the command parser of `git-write-guard.sh` since option B of `~/dotfiles/.claude/PLAN-SESSION-DISCIPLINE.md` (2026-09-27). Traps measured that day:

- A comment ending in a backslash (`git status # see \` then `git push` on the next line) is read as a line continuation: shfmt returns one command `git status git push`, while bash ends the comment at the newline and runs two. The comment's `Text` keeps the trailing `\` and newline, so a consumer can detect it (`any(.. | objects | select(has("Hash")) | .Text; test("\\\\\n$"))`) and treat it as a parse failure.
- `Lit` values stay raw: an unquoted `pu\sh` comes out as `pu\\sh` and a double-quoted `\$` keeps its backslash, so the consumer unescapes (unquoted: drop every backslash; double-quoted: only before `$`, backtick, `"`, `\` and newline). A backslash-newline outside a comment is removed by the parser.
- `$'…'` is `SglQuoted` with `Dollar: true` and the escapes undecoded in `Value`.
- A quoted heredoc delimiter gives one `Lit` body; an unquoted one gives `CmdSubst` parts for `$(…)` and backticks, which run.
- Brace expansion is never a node: `{git,}` is a plain `Lit`.
- Operator codes: redirections `>` 54, `>>` 55, `<` 56, `<>` 57, `<&` 58, `>&` 59, `>|` 60, `<<` 61, `<<-` 62, `<<<` 63, `&>` 64, `&>>` 65; `BinaryCmd` `&&` 10, `||` 11, `|` 12, `|&` 13.
- On a syntax error it exits 1 with `line:col: message` on stderr; piped into jq without `pipefail`, the failure is lost.

Related: [[reference_bash_tool_pitfalls]], [[feedback_shell_grep_pipefail]].
