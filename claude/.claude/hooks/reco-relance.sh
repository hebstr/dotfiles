#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

noise="stop hook feedback:|<command-message>|<bash-input>|<local-command"

reminder="Before answering, run the check the answer depends on (a test, a measure, a read of the file or the doc) if it has not run yet, rather than answering from memory. If you already gave a recommendation on this point, keep it: asking again is not a new fact. Revise it only on a new fact or on a verification you had not yet run, and name that fact or verification when you revise."

jq -c --arg noise "$noise" --arg reminder "$reminder" '
  .prompt
  | strings
  | select(test($noise; "i") | not)
  | gsub("<pasted_content[^>]*>[\\s\\S]*?</pasted_content[^>]*>"; "")
  | gsub("<(?<t>agent-message|cross-session-message|task-notification)\\b[^>]*>[\\s\\S]*?</\\k<t>>"; "")
  | select(index("?"))
  | {hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $reminder}}
' 2>/dev/null

exit 0
