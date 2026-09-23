#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/ending-gate.sh"

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

run_gate() {
  local payload=$1
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  local message=$1 active=${2:-false}
  jq -nc --arg m "$message" --argjson a "$active" \
    '{session_id: "s1", hook_event_name: "Stop", stop_hook_active: $a, last_assistant_message: $m}'
}

assert_offer_blocked() {
  [ "$status" -eq 2 ]
  [[ $output == *"recommendation"* ]]
}

assert_close_blocked() {
  [ "$status" -eq 2 ]
  [[ $output == *"commit skill"* ]]
}

assert_passes() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks an offer ending on 'si tu veux'" {
  run_gate "$(payload "Le script est prêt. Je peux l'écrire si tu veux.")"
  assert_offer_blocked
  [[ $output == *"si tu veux"* ]]
}

@test "blocks 'Si tu veux' opening a sentence" {
  run_gate "$(payload 'Si tu veux, je reprends la note.')"
  assert_offer_blocked
}

@test "blocks 'quand tu veux'" {
  run_gate "$(payload 'Je passe à la suite quand tu veux.')"
  assert_offer_blocked
}

@test "blocks 'dis-moi si'" {
  run_gate "$(payload 'Dis-moi si je déplace la ligne.')"
  assert_offer_blocked
}

@test "blocks 'tu veux que je' and 'veux-tu que je'" {
  run_gate "$(payload 'Tu veux que je la reformule ?')"
  assert_offer_blocked
  run_gate "$(payload 'Veux-tu que je lance la mesure ?')"
  assert_offer_blocked
}

@test "blocks the English offers" {
  run_gate "$(payload 'I can write the test if you want.')"
  assert_offer_blocked
  run_gate "$(payload 'Let me know if the wording works.')"
  assert_offer_blocked
  run_gate "$(payload 'Want me to run it once?')"
  assert_offer_blocked
}

@test "blocks an offer placed in the middle of the message" {
  run_gate "$(payload "$(printf '%s\n' 'Fait.' '' 'Je peux aussi purger le cache si tu veux.' '' 'Les tests passent.')")"
  assert_offer_blocked
}

@test "blocks a closure delegated with a backticked /commit" {
  # shellcheck disable=SC2016
  run_gate "$(payload 'Lance `/commit` pour le bloc.')"
  assert_close_blocked
  [[ $output == *"/commit"* ]]
}

@test "blocks the delegation forms of /commit" {
  run_gate "$(payload 'Je lance /commit ?')"
  assert_close_blocked
  run_gate "$(payload 'Tu peux lancer /commit maintenant.')"
  assert_close_blocked
  # shellcheck disable=SC2016
  run_gate "$(payload 'Tape `/commit` quand tout est relu.')"
  assert_close_blocked
  # shellcheck disable=SC2016
  run_gate "$(payload 'Run `/commit` to get the blocks.')"
  assert_close_blocked
}

@test "names both families when both occur" {
  # shellcheck disable=SC2016
  run_gate "$(payload 'Lance `/commit` quand tu veux le bloc.')"
  [ "$status" -eq 2 ]
  [[ $output == *"quand tu veux"* ]]
  [[ $output == *"commit skill"* ]]
}

@test "passes a message with a recommendation and no listed phrase" {
  run_gate "$(payload 'Je recommande de garder la regex : ses échecs sont sans gravité.')"
  assert_passes
}

@test "passes an alternative offered after a recommendation" {
  run_gate "$(payload 'Je recommande 1 à 6. Si tu préfères clore vite, la note porte tout.')"
  assert_passes
}

@test "passes a mention of /commit without a delegation verb" {
  # shellcheck disable=SC2016
  run_gate "$(payload 'La skill `/commit` rend les blocs, et `commit-gate.sh` les vérifie.')"
  assert_passes
}

@test "ignores a phrase inside inline code" {
  # shellcheck disable=SC2016
  run_gate "$(payload 'Le motif `si tu veux` est dans la liste.')"
  assert_passes
}

@test "ignores a phrase inside a double-backtick code span" {
  # shellcheck disable=SC2016
  run_gate "$(payload 'Elles sont écrites `` lance `/commit` `` dans les transcripts.')"
  assert_passes
}

@test "ignores a phrase inside a fenced block" {
  run_gate "$(payload "$(printf '%s\n' 'Exemple :' '```text' 'Je peux le faire si tu veux.' 'lance /commit' '```' 'Fin.')")"
  assert_passes
}

@test "ignores a phrase between double quotes, guillemets or curly quotes" {
  run_gate "$(payload 'La correction portait sur "Je peux l écrire si tu veux".')"
  assert_passes
  run_gate "$(payload 'Deux tournures : « lance /commit » et « quand tu veux ».')"
  assert_passes
  run_gate "$(payload 'The offer “let me know if” is listed.')"
  assert_passes
}

@test "an unclosed guillemet does not hide the next line" {
  run_gate "$(payload "$(printf '%s\n' 'Une citation « ouverte' 'Je peux le faire si tu veux.')")"
  assert_offer_blocked
}

@test "an apostrophe does not open a quotation" {
  run_gate "$(payload "L'écriture est prête, je l'applique si tu veux.")"
  assert_offer_blocked
}

@test "does not match a phrase inside a longer word" {
  run_gate "$(payload 'Le fichier pepsi tu veux-rien est un exemple.')"
  assert_passes
}

@test "passes when stop_hook_active is true" {
  run_gate "$(payload 'Je peux le faire si tu veux.' true)"
  assert_passes
}

@test "passes when the message has no text" {
  run_gate '{"session_id":"s1","stop_hook_active":false}'
  assert_passes
}

@test "exits 0 on malformed JSON" {
  run_gate 'not json'
  assert_passes
}

@test "exits 0 silently when jq is missing" {
  rm -f "$STUB_DIR/jq"
  run_gate "$(payload 'Je peux le faire si tu veux.')"
  assert_passes
}
