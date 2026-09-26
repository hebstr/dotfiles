#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
prompt=$(printf '%s' "$payload" | jq -r '.prompt // "" | strings' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0
[[ -n $prompt ]] || exit 0

claude_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
installed=$claude_dir/plugins/installed_plugins.json
settings=$claude_dir/settings.json

plugin_path() {
  local plugin=$1
  [[ -r $installed && -r $settings ]] || return 1
  jq -r --arg p "$plugin" --slurpfile s "$settings" '
    .plugins // {} | to_entries[]
    | select((.key | split("@")[0]) == $p)
    | select(($s[0].enabledPlugins // {})[.key] == true)
    | .value[0].installPath // empty
  ' "$installed" 2>/dev/null | head -n 1
}

is_skill() {
  local name=$1 plugin item root dir
  if [[ $name == *:* ]]; then
    plugin=${name%%:*}
    item=${name#*:}
    root=$(plugin_path "$plugin") || return 1
    [[ -n $root && -d $root ]] || return 1
    [[ -f $root/skills/$item/SKILL.md || -f $root/$plugin/$item/SKILL.md || -f $root/commands/$item.md || -f $root/$plugin/commands/$item.md ]]
    return
  fi
  for dir in "$claude_dir" "${cwd:+"$cwd/.claude"}"; do
    [[ -f $dir/skills/$name/SKILL.md || -f $dir/commands/$name.md ]] && return 0
  done
  return 1
}

name_re='([a-z][a-z0-9_-]*(:[a-z0-9_-]+)?)'
end_re='([[:space:].,;!?)<"'"'"'`]|:[[:space:]]|:$|$)'
mention='[[:space:]("'"'"'`]/'$name_re$end_re

declare -A seen=()
body=${prompt#"${prompt%%[![:space:]]*}"}
lead='^/'$name_re$end_re
[[ $body =~ $lead ]] && seen["${BASH_REMATCH[1]}"]=1

found=()
rest=" $body"
while [[ $rest =~ $mention ]]; do
  name=${BASH_REMATCH[1]}
  rest=" ${rest#*"${BASH_REMATCH[0]}"}"
  [[ -z ${seen[$name]:-} ]] || continue
  seen[$name]=1
  is_skill "$name" && found+=("/$name")
done

((${#found[@]} > 0)) || exit 0

list=$(printf "\`%s\`, " "${found[@]}")
list=${list%, }
message="The user's message names ${list}. Call the Skill tool with that name before any other work: the harness loads only a slash command that opens the message, so this one loads only if you call it. A skill hidden from the skill listing (disable-model-invocation) still loads when the user typed its name; never read its SKILL.md as a substitute. Only if the Skill call fails, check ~/.claude/skills/<name>/SKILL.md and the project's .claude/skills/, then report the actual error."

jq -n --arg c "$message" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
