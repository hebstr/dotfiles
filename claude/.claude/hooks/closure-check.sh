#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

pattern="\\b(to[ut]{1,2}|tra?c?ki?n?g)\\b[^.?!\\n]{0,30}?\\b(est|ets|es|sont)\\s+(bien\\s+)?(update|uodate|updat[ée]|(à|a)\\s+jour|consign)|\\btra?c?ki?n?g\\s+(update|uodate|(à|a)\\s+jour)\\s*\\?|\\breste[- ]?t[- ]?il\\b[^.?!\\n]{0,20}\\b(consigner|update|mettre (à|a) jour)|\\b(peux|peut|pouvons|puis)(-je|-on)?\\b[^.?!\\n]{0,20}\\bclore\\b|\\b(is|are) (everything|it all|all|the tracking)( [a-z]+){0,2} (up to date|updated|recorded)\\b|\\b(can|may|could|should) (i|we) (close|wrap up|end)( (this|the)( session)?)? (here|now)\\b|\\b(can|may|could|should) (i|we) (close|end) the session\\b"

reminder="The user is asking whether everything is up to date or whether the session can be closed. Assert nothing first, not even \"yes\": invoke the handoff skill now, which carries the procedure, and answer with what its pass found. If it finds something to update, it is updated before the session is declared closable."

jq -c --arg pat "$pattern" --arg reminder "$reminder" '
  .prompt
  | strings
  | gsub("<pasted_content[^>]*>[\\s\\S]*?</pasted_content[^>]*>"; "")
  | gsub("<(?<t>agent-message|cross-session-message|task-notification)\\b[^>]*>[\\s\\S]*?</\\k<t>>"; "")
  | select(test($pat; "i"))
  | {hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $reminder}}
' 2>/dev/null

exit 0
