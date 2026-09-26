#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
fields=$(printf '%s' "$payload" | jq -r 'select((.session_id // "") != "" and (.load_reason // "") != "" and (.file_path // "") != "") | [.session_id, .load_reason, .file_path, .trigger_file_path // ""] | @tsv' 2>/dev/null) || exit 0
[[ -n $fields ]] || exit 0
IFS=$'\t' read -r session reason file trigger <<<"$fields"

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
umask 077
{
  mkdir -p "$log_dir" &&
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$session" "$reason" "$file" "$trigger" >>"$log_dir/instructions.log"
} 2>/dev/null || true
exit 0
