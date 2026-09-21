#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/llama-session

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/llama-session"

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

# The ssh stub dispatches on the remote command text and keeps the remote state
# in files, so a test can assert what was sent and what survived the run.
_install_ssh_stub() {
  _stub_command ssh '
printf "%s\n" "$*" >>"${SSH_LOG}"
remote="${!#}"
case "$remote" in
*"pgrep -x llama-server"*)
  [ -e "${STATE}/running" ]
  exit $?
  ;;
*"pkill -9 -x llama-server"* | *"pkill -x llama-server"*)
  rm -f "${STATE}/running"
  exit 0
  ;;
*"download"*)
  printf "%s\n" "${FAKE_MODEL_PATH:-/remote/cache/model.gguf}"
  exit 0
  ;;
*"setsid nohup"*)
  [ -n "${START_FAILS:-}" ] || touch "${STATE}/running"
  exit 0
  ;;
*"tail -15"*)
  printf "remote log line one\nremote log line two\n"
  exit 0
  ;;
*"/v1/models"*)
  printf "{\"data\":[{\"id\":\"stub-alias\"}]}\n"
  exit 0
  ;;
-N)
  exit 0
  ;;
esac
case "$*" in
*" -N "*)
  exit 0
  ;;
esac
exit 0'
}

_install_curl_stub() {
  _stub_command curl '
for arg; do
  case "$arg" in
  *"/health"*)
    [ -e "${STATE}/running" ] && [ -z "${HEALTH_SILENT:-}" ]
    exit $?
    ;;
  esac
done
exit 1'
}

setup() {
  STUBS="$(mktemp -d)"
  STATE="$(mktemp -d)"
  SSH_LOG="$(mktemp -u)"
  export STUBS STATE SSH_LOG
  for cmd in cat sed tr tail printf sleep rm touch; do
    [ -e "/usr/bin/${cmd}" ] && ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _install_ssh_stub
  _install_curl_stub
}

teardown() {
  rm -rf "$STUBS" "$STATE" "$SSH_LOG"
}

_run() {
  run env PATH="$STUBS" STATE="$STATE" SSH_LOG="$SSH_LOG" \
    START_FAILS="${START_FAILS:-}" HEALTH_SILENT="${HEALTH_SILENT:-}" \
    FAKE_MODEL_PATH="${FAKE_MODEL_PATH:-}" \
    LLAMA_READY_TIMEOUT="${LLAMA_READY_TIMEOUT:-3}" \
    LLAMA_MODEL_REPO="${LLAMA_MODEL_REPO:-}" LLAMA_MODEL_FILE="${LLAMA_MODEL_FILE:-}" \
    LLAMA_CTX="${LLAMA_CTX:-}" LLAMA_PORT="${LLAMA_PORT:-}" LLAMA_ALIAS="${LLAMA_ALIAS:-}" \
    "$BASH" "$SCRIPT" "$@"
}

_server_up() { touch "${STATE}/running"; }

# ─── argument handling ──────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: llama-session"* ]]
  [[ "$output" == *"--keep"* ]]
}

@test "an unknown argument exits 1 and names it" {
  _run --frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument: --frobnicate"* ]]
}

# ─── status ─────────────────────────────────────────────────────────────────

@test "--status reports both ends down when nothing runs" {
  _run --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no llama-server"* ]]
  [[ "$output" == *"silent, no forward"* ]]
}

@test "--status reports the running server and its model" {
  _server_up
  _run --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"llama-server running"* ]]
  [[ "$output" == *"model stub-alias"* ]]
  [[ "$output" == *"port 8080 answers"* ]]
}

@test "--status starts nothing" {
  _run --status
  [ "$status" -eq 0 ]
  run ! grep -q "setsid nohup" "$SSH_LOG"
}

# ─── stop ───────────────────────────────────────────────────────────────────

@test "--stop stops a running server" {
  _server_up
  _run --stop
  [ "$status" -eq 0 ]
  [[ "$output" == *"remote server stopped"* ]]
  [ ! -e "${STATE}/running" ]
}

@test "--stop on an idle host says so and exits 0" {
  _run --stop
  [ "$status" -eq 0 ]
  [[ "$output" == *"no remote server to stop"* ]]
}

# ─── bringing a session up ──────────────────────────────────────────────────

@test "a cold start resolves the model then launches the server" {
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"resolving"* ]]
  [[ "$output" == *"ready: http://127.0.0.1:8080/v1"* ]]
  grep -q "download" "$SSH_LOG"
  grep -q "setsid nohup" "$SSH_LOG"
}

@test "a cold start sends the resolved model path and the default flags" {
  FAKE_MODEL_PATH=/remote/cache/qwen.gguf _run
  [ "$status" -eq 0 ]
  grep -q -- "--model /remote/cache/qwen.gguf" "$SSH_LOG"
  grep -q -- "--ctx-size 40960" "$SSH_LOG"
  grep -q -- "--parallel 1" "$SSH_LOG"
  grep -q -- "--reasoning-budget 0" "$SSH_LOG"
}

@test "the environment overrides reach the remote command line" {
  LLAMA_CTX=8192 LLAMA_MODEL_FILE=other.gguf LLAMA_ALIAS=custom _run
  [ "$status" -eq 0 ]
  grep -q -- "--ctx-size 8192" "$SSH_LOG"
  grep -q -- "--alias custom" "$SSH_LOG"
  grep -q "other.gguf" "$SSH_LOG"
}

@test "the alias defaults to the model file without its extension" {
  LLAMA_MODEL_FILE=Some-Model-Q4.gguf _run
  [ "$status" -eq 0 ]
  grep -q -- "--alias Some-Model-Q4" "$SSH_LOG"
}

@test "a server already running is reused rather than started again" {
  _server_up
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"reusing the llama-server"* ]]
  run ! grep -q "setsid nohup" "$SSH_LOG"
  run ! grep -q "download" "$SSH_LOG"
}

# ─── ownership of the remote server ─────────────────────────────────────────

@test "a session that started the server stops it on exit" {
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopping the remote server"* ]]
  [ ! -e "${STATE}/running" ]
}

@test "--keep leaves a server this session started" {
  _run --keep
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopping the remote server"* ]]
  [ -e "${STATE}/running" ]
}

@test "a reused server survives the session that borrowed it" {
  _server_up
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopping the remote server"* ]]
  [ -e "${STATE}/running" ]
}

# ─── failure to become ready ────────────────────────────────────────────────

@test "a server that dies at startup is reported with the remote log" {
  START_FAILS=1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"died at startup"* ]]
  [[ "$output" == *"remote log line one"* ]]
}

@test "a server alive but never answering is called loading, not dead" {
  HEALTH_SILENT=1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alive but loading"* ]]
  [[ "$output" != *"died at startup"* ]]
}
