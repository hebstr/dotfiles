#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/commit/scripts/transcripts.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  FAKE_HOME="$WORK/home"
  REPO="$WORK/my.repo"
  PROJ="$FAKE_HOME/.claude/projects/${REPO//[\/.]/-}"
  export WORK STUB_DIR FAKE_HOME REPO PROJ

  mkdir -p "$STUB_DIR" "$PROJ" "$REPO"
  for cmd in rg jq sort; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_transcripts() {
  run env PATH="$STUB_DIR" HOME="$FAKE_HOME" /bin/bash "$SCRIPT" "$@"
}

line() {
  printf '%s\n' "$1" >>"$PROJ/${2:-t1}.jsonl"
}

typed() {
  local date=$1 name=$2 args=$3
  line "$(jq -nc --arg t "${date}T10:00:00Z" --arg n "$name" --arg a "$args" \
    '{timestamp: $t, message: {content: "<command-message>\($n)</command-message>\n<command-name>/\($n)</command-name>\n<command-args>\($a)</command-args>"}}')"
}

skill_call() {
  local date=$1 input=$2
  line "$(jq -nc --arg t "${date}T10:00:00Z" --argjson i "$input" \
    '{timestamp: $t, message: {content: [{type: "tool_use", name: "Skill", input: $i}]}}')"
}

bash_call() {
  local date=$1 command=$2
  line "$(jq -nc --arg t "${date}T10:00:00Z" --arg c "$command" \
    '{timestamp: $t, message: {content: [{type: "tool_use", name: "Bash", input: {command: $c}}]}}')"
}

@test "lists a typed command with its date and the first line of its arguments" {
  typed 2026-09-20 audit:walkthrough $'foo.sh --reviewer x\nsecond line'
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-20\taudit:walkthrough\tfoo.sh --reviewer x' ]
}

@test "lists a typed command carried in a text block" {
  line "$(jq -nc '{timestamp: "2026-09-20T10:00:00Z", message: {content: [{type: "text", text: "<command-name>/cadrer</command-name>\n<command-args>x</command-args>"}]}}')"
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-20\tcadrer\tx' ]
}

@test "lists a Skill tool call with its arguments" {
  skill_call 2026-09-21 '{"skill": "audit:blindspot", "args": "CLAUDE.md\nmore"}'
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-21\taudit:blindspot\tCLAUDE.md' ]
}

@test "prints an empty argument field, never null, for a Skill call without arguments" {
  skill_call 2026-09-21 '{"skill": "commit"}'
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-21\tcommit\t' ]
}

@test "deduplicates and sorts invocations across transcripts" {
  skill_call 2026-09-22 '{"skill": "commit"}'
  skill_call 2026-09-22 '{"skill": "commit"}' t2
  typed 2026-09-20 cadrer x
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = $'2026-09-20\tcadrer\tx' ]
}

@test "lists a Bash command naming the script, first line cut to 160 characters" {
  long=$(printf 'x%.0s' {1..200})
  bash_call 2026-09-22 $'measure.py --all '"$long"$'\nsecond'
  run_transcripts bash "$REPO" measure.py
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ ${lines[0]} == $'2026-09-22\tmeasure.py --all x'* ]]
  [ "${#lines[0]}" -eq $((10 + 1 + 160)) ]
}

@test "leaves out a Bash command that does not name the script" {
  bash_call 2026-09-22 'rg other'
  line "$(jq -nc '{timestamp: "2026-09-22T10:00:00Z", message: {content: [{type: "tool_result", content: "measure.py"}]}}')"
  run_transcripts bash "$REPO" measure.py
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints nothing and says so when the project has no transcript directory" {
  run_transcripts invocations "$WORK/nowhere"
  [ "$status" -eq 0 ]
  [[ $output == *"no transcript directory"* ]]
}

@test "rejects an unknown mode" {
  run_transcripts nope "$REPO"
  [ "$status" -eq 2 ]
}

@test "rejects the bash mode without a name" {
  run_transcripts bash "$REPO"
  [ "$status" -eq 2 ]
}
