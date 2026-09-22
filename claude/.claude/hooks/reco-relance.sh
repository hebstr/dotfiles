#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

pattern="(que|qu['’]est-ce que tu|\\btu) recommand|recommand[a-z]*-tu|\\bta reco|\\breco *\\?|\\b(tu es|t['’]es|es-tu|êtes-vous) s[uû]r|vraiment *\\?|tu (me )?conseilles|conseilles-tu|tu ferais quoi|que ferais-tu|tu maintiens|what (do|would) you (really )?recommend|\\bare you sure|\\breally *\\?|what would you do"

reminder="The user may be asking again about a recommendation you already gave. Asking again is not a new fact. Keep the recommendation unless a new fact or a verification you had not yet run changes it, and name that fact or verification when you revise. If a check (test, measure, read of the file or the doc) bears on the answer and has not run yet, run it before answering. If no recommendation was given yet, run the check it depends on before giving it."

jq -c --arg pat "$pattern" --arg reminder "$reminder" '
  .prompt
  | strings
  | gsub("<pasted_content[^>]*>[\\s\\S]*?</pasted_content[^>]*>"; "")
  | select(test($pat; "i"))
  | {hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $reminder}}
' 2>/dev/null

exit 0
