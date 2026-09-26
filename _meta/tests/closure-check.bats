#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/closure-check.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  export WORK STUB_DIR

  mkdir -p "$STUB_DIR"
  for cmd in cat jq; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  jq -nc --arg p "$1" '{session_id: "s1", hook_event_name: "UserPromptSubmit", prompt: $p}'
}

assert_injects() {
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" = UserPromptSubmit ]
  [[ $(jq -r '.hookSpecificOutput.additionalContext' <<<"$output") == *"check run now"* ]]
}

assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "injects the reminder on 'tout est update ?'" {
  run_hook "$(payload 'tout est update ?')"
  assert_injects
}

@test "injects on 'tout le tracking est update ?'" {
  run_hook "$(payload 'tout le tracking est update ?')"
  assert_injects
}

@test "injects on 'je peux clore ici ?'" {
  run_hook "$(payload 'OK. je peux clore ici ?')"
  assert_injects
}

@test "injects on a closure question with a verb between" {
  run_hook "$(payload 'je peux commit et clore ici ?')"
  assert_injects
}

@test "injects on 'tout ça est consigné ?'" {
  run_hook "$(payload 'tout ça est consigné ?')"
  assert_injects
}

@test "injects on 'tout est à jour' in capitals" {
  run_hook "$(payload 'TOUT EST À JOUR ?')"
  assert_injects
}

@test "injects on the check requested before a commit" {
  run_hook "$(payload 'vérifie que tout est update avant de proposer un commit')"
  assert_injects
}

@test "injects on 'que reste-t-il à consigner ?'" {
  run_hook "$(payload 'que reste t il à consigner ?')"
  assert_injects
}

@test "injects on a typo in the subject" {
  run_hook "$(payload 'totu est update ici ? tracking ?')"
  assert_injects
}

@test "injects on a typo in the verb" {
  run_hook "$(payload 'le tracking ets update ?')"
  assert_injects
}

@test "injects on a bare 'tracking update ?'" {
  run_hook "$(payload 'OK. tracking uodate ?')"
  assert_injects
}

@test "injects on an English up-to-date question" {
  run_hook "$(payload 'Is everything up to date?')"
  assert_injects
}

@test "injects on an English closure question" {
  run_hook "$(payload 'Can I close here?')"
  assert_injects
}

@test "stays silent on an instruction to update the tracking" {
  run_hook "$(payload 'fais une dernière vérification, update tracking')"
  assert_silent
}

@test "stays silent on a tool named update" {
  run_hook "$(payload 'explique en détail prek update --cooldown-days 7 --check')"
  assert_silent
}

@test "stays silent on a status report mentioning an update" {
  run_hook "$(payload 'push fait. update en cours dans md-nesrine')"
  assert_silent
}

@test "stays silent on 'clôture' used about something else" {
  run_hook "$(payload "et la formule de clôture de l'exposé ?")"
  assert_silent
}

@test "stays silent on 'mise à jour' as a topic" {
  run_hook "$(payload 'je veux que la mise à jour des extensions soit automatisée au même titre que zotero')"
  assert_silent
}

@test "stays silent on relayed Stop hook feedback" {
  run_hook "$(payload 'Stop hook feedback: An action the discipline already requires, such as a tracking update, is done, not offered.')"
  assert_silent
}

@test "ignores a closure question that sits inside pasted content" {
  local prompt
  prompt=$(printf '%s\n' 'Voici le transcript :' '<pasted_content id="ab12">' 'tout est update ? je peux clore ici ?' '</pasted_content id="ab12">' 'Résume-le.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "still injects when the typed part is a closure question next to pasted content" {
  local prompt
  prompt=$(printf '%s\n' '<pasted_content id="ab12">' 'log' '</pasted_content id="ab12">' 'je peux clore ici ?')
  run_hook "$(payload "$prompt")"
  assert_injects
}

@test "ignores a subagent report relayed as a prompt" {
  local prompt
  prompt=$(printf '%s\n' 'Another Claude session sent a message:' '<agent-message from="a2ac6">' '[Subagent hand-back] 16 prompts read "tout est update ?".' '</agent-message>')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "ignores a cross-session message" {
  local prompt
  prompt=$(printf '%s\n' 'Another Claude session sent a message:' '<cross-session-message from="uds:/run/x.sock">' 'je peux clore ici ?' '</cross-session-message>')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "ignores a task notification" {
  local prompt
  prompt=$(printf '%s\n' '<task-notification>' '<result>tout est à jour</result>' '</task-notification>')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "stays silent when the prompt field is missing" {
  run_hook '{"session_id": "s1"}'
  assert_silent
}

@test "stays silent when the prompt is not a string" {
  run_hook '{"prompt": 42}'
  assert_silent
}

@test "exits 0 silently on malformed JSON" {
  run_hook 'not json'
  assert_silent
}

@test "exits 0 silently when jq is missing" {
  local p
  p=$(payload 'tout est update ?')
  rm -f "$STUB_DIR/jq"
  run_hook "$p"
  assert_silent
}
