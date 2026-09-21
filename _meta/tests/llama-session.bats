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
*"pgrep -a -x llama-server"*)
  [ -z "${PGREP_A_UNREACHABLE:-}" ] || exit 255
  [ -e "${STATE}/running" ] || exit 1
  cat "${STATE}/cmdline" 2>/dev/null
  exit 0
  ;;
*"pgrep -x llama-server"*)
  n=$(($(cat "${STATE}/pgrep_calls" 2>/dev/null || echo 0) + 1))
  echo "$n" >"${STATE}/pgrep_calls"
  [ "$n" != "${SSH_DROP_AT:-}" ] || exit 255
  [ -e "${STATE}/running" ]
  exit $?
  ;;
*"pkill -9 -x llama-server"* | *"pkill -x llama-server"*)
  [ -z "${PKILL_UNREACHABLE:-}" ] || exit 255
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
  printf "{\"data\":[{\"id\":\"stub-alias\"}]}"
  exit 0
  ;;
esac
case "$*" in
*" -N "*)
  [ -z "${TUNNEL_FAILS:-}" ] || exit 255
  touch "${STATE}/tunnel"
  exec sleep "${TUNNEL_LIFE:-1}"
  ;;
esac
exit 0'
}

_install_curl_stub() {
  _stub_command curl '
for arg; do
  case "$arg" in
  *"/health"*)
    [ -e "${STATE}/tunnel" ] && [ -e "${STATE}/running" ] && [ -z "${HEALTH_SILENT:-}" ]
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
    FAKE_MODEL_PATH="${FAKE_MODEL_PATH:-}" SSH_DROP_AT="${SSH_DROP_AT:-}" \
    PKILL_UNREACHABLE="${PKILL_UNREACHABLE:-}" PGREP_A_UNREACHABLE="${PGREP_A_UNREACHABLE:-}" \
    TUNNEL_FAILS="${TUNNEL_FAILS:-}" TUNNEL_LIFE="${TUNNEL_LIFE:-}" \
    LLAMA_READY_TIMEOUT="${LLAMA_READY_TIMEOUT:-3}" \
    LLAMA_MODEL_REPO="${LLAMA_MODEL_REPO:-}" LLAMA_MODEL_FILE="${LLAMA_MODEL_FILE:-}" \
    LLAMA_CTX="${LLAMA_CTX:-}" LLAMA_PORT="${LLAMA_PORT:-}" LLAMA_ALIAS="${LLAMA_ALIAS:-}" \
    "$BASH" "$SCRIPT" "$@"
}

_server_up() {
  touch "${STATE}/running"
  printf '%s\n' "${1:-4242 llama-server --model /m.gguf --alias Qwen3.5-4B-UD-Q4_K_XL --host 127.0.0.1 --port 8080 -ngl 99 --ctx-size 40960 --parallel 1}" >"${STATE}/cmdline"
}

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
  touch "${STATE}/tunnel"
  _run --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"llama-server running"* ]]
  [[ "$output" == *"model stub-alias"$'\n'"local: port 8080 answers"* ]]
}

@test "--status on an unreachable host says so rather than reporting no server" {
  SSH_DROP_AT=1 _run --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"remote: cannot reach"* ]]
  [[ "$output" != *"no llama-server"* ]]
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

@test "--stop on a host lost mid-stop does not claim success" {
  _server_up
  PKILL_UNREACHABLE=1 _run --stop
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" != *"remote server stopped"* ]]
  [ -e "${STATE}/running" ]
}

@test "--stop on an unreachable host says so rather than reporting no server" {
  _server_up
  SSH_DROP_AT=1 _run --stop
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" != *"no remote server to stop"* ]]
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
  [[ "$output" != *"warning"* ]]
}

@test "a reused server on another port is refused before the forward opens" {
  _server_up "4242 llama-server --alias Qwen3.5-4B-UD-Q4_K_XL --port 9090 --ctx-size 40960"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"another port than 8080"* ]]
  run ! grep -q -- " -N " "$SSH_LOG"
}

@test "a reused server whose flags cannot be read says so rather than passing silently" {
  _server_up "4242 llama-server --alias Qwen3.5-4B-UD-Q4_K_XL --port 9090 --ctx-size 40960"
  PGREP_A_UNREACHABLE=1 LLAMA_READY_TIMEOUT=1 _run
  [[ "$output" == *"cannot check the reused server's flags"* ]]
  [[ "$output" != *"was not started as"* ]]
}

@test "a reused server with another context is flagged but still used" {
  _server_up
  LLAMA_CTX=8192 _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]]
  [[ "$output" == *"ctx 8192"* ]]
  [[ "$output" == *"ready: http://127.0.0.1:8080/v1"* ]]
}

@test "a reused server with another model is flagged but still used" {
  _server_up
  LLAMA_MODEL_FILE=Other-Model.gguf _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]]
  [[ "$output" == *"Other-Model"* ]]
}

@test "an unreachable host at startup is named and nothing is started" {
  SSH_DROP_AT=1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  run ! grep -q "download" "$SSH_LOG"
  run ! grep -q "setsid nohup" "$SSH_LOG"
}

# ─── ownership of the remote server ─────────────────────────────────────────

@test "a session that started the server stops it on exit" {
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopping the remote server"* ]]
  [ ! -e "${STATE}/running" ]
}

@test "a teardown that cannot reach the host warns of a possible orphan" {
  PKILL_UNREACHABLE=1 _run
  [[ "$output" == *"stopping the remote server"* ]]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" == *"llama-session --stop"* ]]
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

@test "a dropped ssh probe while loading is not taken for a dead server" {
  SSH_DROP_AT=2 _run
  [ "$status" -eq 0 ]
  [ "$(cat "${STATE}/pgrep_calls")" -ge 2 ]
  [[ "$output" != *"died at startup"* ]]
  [[ "$output" == *"ready: http://127.0.0.1:8080/v1"* ]]
}

@test "a server alive but never answering is called loading, not dead" {
  HEALTH_SILENT=1 TUNNEL_LIFE=10 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alive but loading"* ]]
  [[ "$output" != *"died at startup"* ]]
}

# ─── the forward ────────────────────────────────────────────────────────────

@test "the forward asks ssh to exit when it cannot bind the port" {
  _run
  [ "$status" -eq 0 ]
  grep -q -- "-o ExitOnForwardFailure=yes -N -L 8080:127.0.0.1:8080" "$SSH_LOG"
}

@test "a forward that dies is reported as such, not as a loading server" {
  TUNNEL_FAILS=1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"port forward on 8080"* ]]
  [[ "$output" != *"alive but loading"* ]]
}

@test "a local port already answering is refused before anything starts" {
  _server_up
  touch "${STATE}/tunnel"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"port 8080 already answers"* ]]
  run ! grep -q "setsid nohup" "$SSH_LOG"
  [ -e "${STATE}/running" ]
}
