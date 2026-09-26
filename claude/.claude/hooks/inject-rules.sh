#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
fields=$(printf '%s' "$payload" | jq -r '[.session_id // "", .tool_name // "", .tool_input.file_path // "", .cwd // "", .tool_input.command // ""] | map(gsub("\u001f"; " ")) | join("\u001f")' 2>/dev/null) || exit 0
IFS=$'\x1f' read -r -d '' session tool file cwd cmd <<<"$fields"
cmd=${cmd%$'\n'}

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

rules_dir=${CLAUDE_RULES_DIR:-$HOME/.claude/rules}
marker="${XDG_RUNTIME_DIR:-/tmp}/claude-code-rules-${session}"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
cap=9500

decision=""
reason=""
context=""
wanted=()

injected() {
  [[ -f $marker ]] && grep -qxF -- "$1" "$marker"
}

want() {
  local name
  for name in "$@"; do
    injected "$name" || wanted+=("$name")
  done
}

decide() {
  local new=$1
  case $decision:$new in
  deny:*) return ;;
  ask:ask | :ask) decision=ask ;;
  *:deny) decision=deny ;;
  esac
  reason=${reason:+$reason }$2
}

is_secret_path() {
  local p=$1 base lower seg abs
  base=${p##*/}
  [[ -n $base ]] || return 1
  case $base in
  *.example | *.template | *.sample) return 1 ;;
  esac
  # shellcheck disable=SC2016
  case $p in
  /* | '~'/* | '$HOME'/* | '${HOME}'/*) abs=$p ;;
  *) abs=${cwd:-.}/$p ;;
  esac
  case $abs in
  "$rules_dir"/* | *.claude/rules/*) return 1 ;;
  esac
  case $base in
  .env | .env.* | .envrc | .secrets | .pgpass | .netrc | credentials* | *.pem | *.key | *.pfx | id_rsa* | id_ed25519*) return 0 ;;
  esac
  lower=${p,,}
  IFS=/ read -r -a segs <<<"$lower"
  for seg in "${segs[@]}"; do
    case $seg in
    *secret* | *password* | *passwd* | *apikey* | *api_key*) return 0 ;;
    esac
  done
  lower=${base,,}
  if [[ $lower == *token* ]]; then
    case $lower in
    *.py | *.r | *.sh | *.bash | *.js | *.ts | *.jsx | *.tsx | *.rs | *.lua | *.go | *.c | *.h | *.cpp | *.java | *.rb | *.pl | *.md | *.qmd | *.rmd | *.bats) return 1 ;;
    esac
    return 0
  fi
  return 1
}

secret_hit=""
case $tool in
Read | Edit | Write | MultiEdit | NotebookEdit)
  is_secret_path "$file" && secret_hit=$file
  ;;
Bash)
  flat=${cmd//[\"\'\`]/ }
  flat=${flat//[;&|<>()=]/ }
  read -r -d '' -a words <<<"$flat"
  for word in "${words[@]}"; do
    [[ $word != -* ]] || continue
    if is_secret_path "$word"; then
      secret_hit=$word
      break
    fi
  done
  ;;
esac
if [[ -n $secret_hit ]]; then
  want secrets
  decide ask "$secret_hit matches a secret-file pattern: the user confirms this access."
fi

lower_file=${file,,}
case $tool in
Read)
  case $lower_file in
  *.pdf)
    if ! injected pdf && [[ -r $rules_dir/pdf.md ]]; then
      want pdf
      decide deny "Classify this PDF before reading it natively: run detect-pdf \"$file\" --analyze --json, then follow the routing of ~/.claude/rules/pdf.md."
    fi
    ;;
  *.docx) want docx ;;
  esac
  ;;
Edit | Write | MultiEdit)
  case $file in
  "$HOME"/.claude/projects/*/memory/*)
    want memory
    decide deny "Memory is written to ~/.claude/memory/ (its index is ~/.claude/memory/MEMORY.md), never under ~/.claude/projects/*/memory/: write it there instead."
    ;;
  "$HOME"/.claude/memory/* | "$HOME"/dotfiles/claude/.claude/memory/*) want memory ;;
  esac
  case $file in
  */.claude/*.md | */CLAUDE.md | */AGENTS.md) want claude-files ;;
  esac
  ;;
Agent | Task)
  want agents
  ;;
Bash)
  seg_start='(^|[;&|(]|&&|\|\||\$\()[[:space:]]*(sudo[[:space:]]+|timeout[[:space:]]+[^[:space:]]+[[:space:]]+)*'
  [[ $cmd =~ (^|[^[:alnum:]_-])(detect-pdf|pdf2md|pdftotext|pdfinfo|pdftoppm)([^[:alnum:]_-]|$) || ${cmd,,} =~ \.pdf([^[:alnum:]]|$) ]] && want pdf
  [[ $cmd =~ ${seg_start}(libreoffice|soffice)([[:space:]]|$) || ${cmd,,} =~ \.docx([^[:alnum:]]|$) ]] && want docx
  if [[ $cmd =~ ${seg_start}(apt|apt-get)[[:space:]] || $cmd =~ ${seg_start}uv[[:space:]]+tool[[:space:]]+install || $cmd =~ ${seg_start}(pip|pip3)[[:space:]]+install || $cmd =~ ${seg_start}stow([[:space:]]|$) || $cmd =~ ${seg_start}claude[[:space:]]+plugin[[:space:]]+install || $cmd =~ ${seg_start}systemctl[[:space:]] ]]; then
    want showboat install
  fi
  [[ $cmd =~ ${seg_start}(/snap/bin/)?(chromium|chromium-browser|firefox)([[:space:]]|$) ]] && want chromium
  ;;
esac

((${#wanted[@]} > 0)) || [[ -n $decision ]] || exit 0

declare -A seen=()
delivered=()
for name in "${wanted[@]}"; do
  [[ -z ${seen[$name]:-} ]] || continue
  seen[$name]=1
  src=$rules_dir/$name.md
  [[ -r $src ]] || continue
  body=$(awk 'NR == 1 && /^---$/ {fm = 1; next} fm && /^---$/ {fm = 0; next} !fm' "$src")
  block="=== rules/$name.md, injected by inject-rules.sh ==="$'\n'"$body"
  if [[ -n $context ]] && ((${#context} + ${#block} + 2 > cap)); then
    continue
  fi
  context=${context:+$context$'\n\n'}$block
  delivered+=("$name")
done

[[ -n $context || -n $decision ]] || exit 0

umask 077
if ((${#delivered[@]} > 0)); then
  { printf '%s\n' "${delivered[@]}" >>"$marker"; } 2>/dev/null || true
  {
    mkdir -p "$log_dir" &&
      for name in "${delivered[@]}"; do
        printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$session" "inject${decision:+-$decision}" "$rules_dir/$name.md" "${file:-$tool}"
      done >>"$log_dir/instructions.log"
  } 2>/dev/null || true
fi

jq -n --arg d "$decision" --arg r "$reason" --arg c "$context" '{
  hookSpecificOutput: (
    {hookEventName: "PreToolUse"}
    + (if $d == "" then {} else {permissionDecision: $d, permissionDecisionReason: $r} end)
    + (if $c == "" then {} else {additionalContext: $c} end)
  )
}'
