#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/reco-relance.sh"

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
  [[ $(jq -r '.hookSpecificOutput.additionalContext' <<<"$output") == *"new fact"* ]]
}

assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "injects the reminder on a follow-up asking what is really recommended" {
  run_hook "$(payload 'Que recommandes-tu vraiment ?')"
  assert_injects
}

@test "injects on the question form with an apostrophe" {
  run_hook "$(payload "Qu'est-ce que tu recommandes, au final ?")"
  assert_injects
}

@test "injects on a typographic apostrophe" {
  run_hook "$(payload "T’es sûr de ton choix ?")"
  assert_injects
}

@test "injects on 'tu es sûr' in capitals" {
  run_hook "$(payload 'TU ES SÛR ?')"
  assert_injects
}

@test "injects on 'tu es sur' without the accent" {
  run_hook "$(payload 'tu es sur de ca')"
  assert_injects
}

@test "injects on a bare 'vraiment ?'" {
  run_hook "$(payload 'Vraiment ?')"
  assert_injects
}

@test "injects on 'ta reco'" {
  run_hook "$(payload "C'est quoi ta reco finale")"
  assert_injects
}

@test "injects on 'tu ferais quoi'" {
  run_hook "$(payload 'Et toi, tu ferais quoi à ma place ?')"
  assert_injects
}

@test "injects on an English follow-up" {
  run_hook "$(payload 'Are you sure? What would you really recommend?')"
  assert_injects
}

@test "stays silent on a plain instruction" {
  run_hook "$(payload 'Lance les tests et corrige ce qui casse.')"
  assert_silent
}

@test "stays silent on a prompt that only mentions recommendations as a topic" {
  run_hook "$(payload 'Lis la section « Les recommandations se maintiennent sauf fait nouveau nommé », puis implémente la sous-étape 5.')"
  assert_silent
}

@test "ignores a follow-up phrase that sits inside pasted content" {
  local prompt
  prompt=$(printf '%s\n' 'Voici le transcript :' '<pasted_content id="ab12">' 'Que recommandes-tu vraiment ?' '</pasted_content id="ab12">' 'Résume-le.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "still injects when the typed part is a follow-up next to pasted content" {
  local prompt
  prompt=$(printf '%s\n' '<pasted_content id="ab12">' 'log' '</pasted_content id="ab12">' 'Tu es sûr ?')
  run_hook "$(payload "$prompt")"
  assert_injects
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
  p=$(payload 'Tu es sûr ?')
  rm -f "$STUB_DIR/jq"
  run_hook "$p"
  assert_silent
}
