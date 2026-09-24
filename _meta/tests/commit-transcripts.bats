#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/commit/scripts/transcripts.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  FAKE_HOME="$WORK/home"
  REPO="$WORK/my_repo.x"
  PROJ="$FAKE_HOME/.claude/projects/${REPO//[^a-zA-Z0-9]/-}"
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
  run env TZ=Europe/Paris PATH="$STUB_DIR" HOME="$FAKE_HOME" /bin/bash "$SCRIPT" "$@"
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

@test "lists a typed command without arguments, with an empty argument field" {
  line "$(jq -nc '{timestamp: "2026-09-20T10:00:00Z", message: {content: "<command-message>workflow:sync</command-message>\n<command-name>/workflow:sync</command-name>"}}')"
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-20\tworkflow:sync\t' ]
}

@test "leaves out a command tag quoted inside a message" {
  line "$(jq -nc '{timestamp: "2026-09-20T10:00:00Z", message: {content: "Evaluate this: <command-name>/commit</command-name>"}}')"
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "dates an invocation by its local day, not its UTC day" {
  line "$(jq -nc '{timestamp: "2026-09-23T22:30:00.123Z", message: {content: "<command-name>/commit</command-name>"}}')"
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-24\tcommit\t' ]
}

@test "skips a record without a timestamp and keeps the others" {
  line '{"message": {"content": "<command-name>/cadrer</command-name>"}}'
  typed 2026-09-20 commit x
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-20\tcommit\tx' ]
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

@test "lists a Bash command naming the script, cut to 60 characters before the name and 140 after" {
  long=$(printf 'x%.0s' {1..200})
  bash_call 2026-09-22 $'cd /tmp && \\\n'"$long"$' && measure.py --all '"$long"$'\nsecond'
  run_transcripts bash "$REPO" measure.py
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'2026-09-22\t'"${long:0:56} && measure.py --all ${long:0:133}" ]
}

@test "lists a Bash command run by a subagent" {
  mkdir -p "$PROJ/sess/subagents"
  line "$(jq -nc '{timestamp: "2026-09-22T10:00:00Z", message: {content: [{type: "tool_use", name: "Bash", input: {command: "measure.py --all"}}]}}')" sess/subagents/agent-a
  run_transcripts bash "$REPO" measure.py
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-22\tmeasure.py --all' ]
}

@test "leaves out a Bash command that does not name the script" {
  bash_call 2026-09-22 'rg other'
  line "$(jq -nc '{timestamp: "2026-09-22T10:00:00Z", message: {content: [{type: "tool_result", content: "measure.py"}]}}')"
  line "$(jq -nc '{timestamp: "2026-09-22T10:00:00Z", message: {content: [{type: "tool_use", name: "Bash", input: {command: "bats x.bats", description: "run measure.py"}}]}}')"
  run_transcripts bash "$REPO" measure.py
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "keeps every later occurrence of the name in the excerpt" {
  bash_call 2026-09-22 'measure.py a | measure.py b'
  run_transcripts bash "$REPO" measure.py
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-22\tmeasure.py a | measure.py b' ]
}

@test "matches a name holding pattern metacharacters literally" {
  bash_call 2026-09-22 'a+b.sh --all'
  run_transcripts bash "$REPO" a+b.sh
  [ "$status" -eq 0 ]
  [ "$output" = $'2026-09-22\ta+b.sh --all' ]
}

@test "exits 0 with no output when no transcript line mentions a command" {
  bash_call 2026-09-22 'rg other'
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits non-zero when a matching transcript line is not valid JSON" {
  line '{"timestamp": "2026-09-20T10:00:00Z", "message": {"content": "<command-name>/commit</command-name>'
  run_transcripts invocations "$REPO"
  [ "$status" -ne 0 ]
}

@test "prints nothing when the transcript directory holds no transcript" {
  run_transcripts invocations "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints nothing and says so when the project has no transcript directory" {
  run_transcripts invocations "$WORK/nowhere"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ $output == *"no transcript directory"* ]]
}

@test "rejects a call without a repository" {
  run_transcripts invocations
  [ "$status" -eq 2 ]
}

@test "rejects an unknown mode" {
  run_transcripts nope "$REPO"
  [ "$status" -eq 2 ]
}

@test "rejects the bash mode without a name" {
  run_transcripts bash "$REPO"
  [ "$status" -eq 2 ]
}
