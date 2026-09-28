#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

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
  run --separate-stderr env PATH="$STUB_DIR" /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  jq -nc --arg p "$1" '{session_id: "s1", hook_event_name: "UserPromptSubmit", prompt: $p}'
}

assert_injects() {
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" = UserPromptSubmit ]
  [[ $(jq -r '.hookSpecificOutput.additionalContext' <<<"$output") == *"new fact"* ]]
  [ -z "$stderr" ]
}

assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "injects when the prompt holds a question mark" {
  run_hook "$(payload 'On part sur polars ou sur duckdb ?')"
  assert_injects
}

@test "injects when the question mark is typed next to pasted content" {
  local prompt
  prompt=$(printf '%s\n' '<pasted_content id="ab12">' 'log' '</pasted_content id="ab12">' 'On garde cette voie ?')
  run_hook "$(payload "$prompt")"
  assert_injects
}

@test "injects when the question mark is typed between two pasted blocks" {
  local prompt
  prompt=$(printf '%s\n' '<pasted_content id="ab12">' 'log A' '</pasted_content id="ab12">' 'On part sur cette voie ?' '<pasted_content id="cd34">' 'log B' '</pasted_content id="cd34">')
  run_hook "$(payload "$prompt")"
  assert_injects
}

@test "injects when the question mark is typed next to a stripped wrapper" {
  local prompt
  prompt=$(printf '%s\n' '<task-notification>Agent terminé.</task-notification>' 'Et la suite ?')
  run_hook "$(payload "$prompt")"
  assert_injects
}

@test "injects when the question mark is typed between two agent-message wrappers" {
  local prompt
  prompt=$(printf '%s\n' '<agent-message from="verifier">Rapport prêt, dois-je poursuivre ?</agent-message>' 'On garde cette voie ?' '<agent-message from="reviewer">Revue finie, autre chose ?</agent-message>')
  run_hook "$(payload "$prompt")"
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

@test "stays silent when the only question mark sits inside pasted content" {
  local prompt
  prompt=$(printf '%s\n' 'Voici le transcript :' '<pasted_content id="ab12">' 'Que recommandes-tu vraiment ?' '</pasted_content id="ab12">' 'Résume-le.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "stays silent when the only question marks sit inside two pasted blocks" {
  local prompt
  prompt=$(printf '%s\n' 'Voici les deux transcripts :' '<pasted_content id="ab12">' 'Que recommandes-tu ?' '</pasted_content id="ab12">' 'et' '<pasted_content id="cd34">' 'On part sur quoi ?' '</pasted_content id="cd34">' 'Résume-les.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "stays silent when the only question mark sits inside an agent-message wrapper" {
  local prompt
  prompt=$(printf '%s\n' '<agent-message from="verifier">Que recommandes-tu ?</agent-message>' 'Applique le rapport.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "stays silent when the only question mark sits inside a cross-session-message wrapper" {
  local prompt
  prompt=$(printf '%s\n' '<cross-session-message>On part sur quoi ?</cross-session-message>' 'Note-le dans le plan.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "stays silent when the only question mark sits inside a task-notification wrapper" {
  local prompt
  prompt=$(printf '%s\n' '<task-notification>Agent fini : reste-t-il quelque chose ?</task-notification>' 'Poursuis.')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "drops the whole prompt on a Stop hook feedback marker" {
  local prompt
  prompt=$(printf '%s\n' 'Stop hook feedback:' '- [ending-gate.sh] La réponse finit-elle sur une recommandation ?')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "drops the whole prompt on a command-message wrapper whose question mark sits in the args" {
  local prompt
  prompt=$(printf '%s\n' '<command-message>workflow:reco is running…</command-message>' '<command-args>que recommandes tu pour la suite ?</command-args>')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "drops the whole prompt on a bash-input marker" {
  local prompt
  prompt=$(printf '%s\n' '<bash-input>git log --oneline -5</bash-input>' '<bash-stdout>b500b7b docs(claude): ok ?</bash-stdout>')
  run_hook "$(payload "$prompt")"
  assert_silent
}

@test "drops the whole prompt on a local-command opener" {
  local prompt
  prompt=$(printf '%s\n' '<local-command-stdout>Tout est à jour ?</local-command-stdout>')
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
  p=$(payload 'On garde cette voie ?')
  rm -f "$STUB_DIR/jq"
  run_hook "$p"
  assert_silent
}
