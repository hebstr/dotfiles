#!/usr/bin/env bats
# shellcheck disable=SC2016

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/skill-mention.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  CONF="$WORK/claude"
  PROJECT="$WORK/project"
  export WORK CONF PROJECT

  mkdir -p "$CONF/skills/commit" "$CONF/skills/design" "$CONF/commands" "$PROJECT/.claude/skills/local-skill"
  mkdir -p "$CONF/plugins/cache/m/audit/v1/audit/walkthrough" "$CONF/plugins/cache/m/other/v1/skills/thing" "$CONF/plugins/cache/m/off/v1/skills/x"
  : >"$CONF/skills/commit/SKILL.md"
  : >"$CONF/skills/design/SKILL.md"
  : >"$CONF/commands/legacy.md"
  : >"$PROJECT/.claude/skills/local-skill/SKILL.md"
  : >"$CONF/plugins/cache/m/audit/v1/audit/walkthrough/SKILL.md"
  : >"$CONF/plugins/cache/m/other/v1/skills/thing/SKILL.md"
  : >"$CONF/plugins/cache/m/off/v1/skills/x/SKILL.md"
  jq -n --arg c "$CONF/plugins/cache/m" '{plugins: {
    "audit@m": [{installPath: ($c + "/audit/v1")}],
    "other@m": [{installPath: ($c + "/other/v1")}],
    "off@m": [{installPath: ($c + "/off/v1")}]
  }}' >"$CONF/plugins/installed_plugins.json"
  printf '{"enabledPlugins": {"audit@m": true, "other@m": true, "off@m": false}}\n' >"$CONF/settings.json"
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local prompt=$1
  # shellcheck disable=SC2016
  run env CLAUDE_CONFIG_DIR="$CONF" /bin/bash -c 'jq -nc --arg p "$1" --arg c "$3" "{prompt: \$p, cwd: \$c}" | /bin/bash "$2"' _ "$prompt" "$SCRIPT" "$PROJECT"
}

context() {
  printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // ""'
}

@test "names a user skill typed at the end of the message" {
  run_hook "fais le point puis /commit"
  [ "$status" -eq 0 ]
  [[ $(context) == *'`/commit`'* ]]
  [[ $(context) == *'Skill tool'* ]]
}

@test "leaves a skill that opens the message to the harness" {
  run_hook "/commit please"
  [ -z "$output" ]
}

@test "still names a second skill when another opens the message" {
  run_hook "/commit then run /design on it"
  [[ $(context) == *'`/design`'* ]]
  [[ $(context) != *'`/commit`'* ]]
}

@test "accepts an enabled plugin skill in either layout" {
  run_hook "lance /audit:walkthrough sur x, puis /other:thing."
  [[ $(context) == *'`/audit:walkthrough`, `/other:thing`'* ]]
}

@test "ignores a skill of a disabled plugin" {
  run_hook "essaie /off:x"
  [ -z "$output" ]
}

@test "accepts project skills and user commands" {
  run_hook "use /local-skill and (/legacy)"
  [[ $(context) == *'`/local-skill`, `/legacy`'* ]]
}

@test "ignores paths, URLs and unknown names" {
  run_hook "see https://github.com/x/commit/abc, /home/u/commit, /tmp and /nothing"
  [ -z "$output" ]
}

@test "reads a mention inside backticks or pasted content" {
  run_hook 'invoke `/design` here <pasted_content id="1">run /commit</pasted_content id="1">'
  [[ $(context) == *'`/design`, `/commit`'* ]]
}

@test "names each skill once" {
  run_hook "a /design b /design c"
  [ "$(context | grep -o '/design' | wc -l)" -eq 1 ]
}

@test "exits 0 on malformed input" {
  # shellcheck disable=SC2016
  run env CLAUDE_CONFIG_DIR="$CONF" /bin/bash -c 'printf "not json" | /bin/bash "$1"' _ "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
