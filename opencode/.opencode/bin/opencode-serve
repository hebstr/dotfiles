#!/usr/bin/env bash
set -Eeuo pipefail

BIN=${CPD_LLAMA_BIN:-/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server}
CACHE=${CPD_LLAMA_CACHE:-/data2/llama.cpp}
REPO=${CPD_MODEL_REPO:-unsloth/Qwen3.8-27B-GGUF}
QUANT=${CPD_MODEL_QUANT:-UD-Q6_K_M}
HOST=${CPD_HOST:-127.0.0.1}
PORT=${CPD_PORT:-8090}
GPUS=${CPD_GPUS:-1,2}
CTX=${CPD_CTX:-196608}
NGL=${CPD_NGL:-99}
IDLE=${CPD_IDLE_SECONDS:-1800}
READY_TIMEOUT=${CPD_READY_TIMEOUT:-300}
LOGDIR=${CPD_LOGDIR:-$HOME/logs/cpd-llama}

PIDFILE=$LOGDIR/llama-server.pid
LOGFILE=$LOGDIR/llama-server.log

usage() {
  cat <<'EOF'
Usage: llama-server up | down | status | logs | -h | --help

Runs the local llama-server for the opencode cpd provider in the foreground.

  up      fetch the model from the HF repo if absent, then serve until interrupted
  down    stop a server started by this script
  status  report process, health and VRAM state
  logs    tail the server log
  -h, --help show this help

Environment: CPD_LLAMA_BIN CPD_LLAMA_CACHE CPD_MODEL_REPO CPD_MODEL_QUANT
             CPD_HOST CPD_PORT CPD_GPUS CPD_CTX CPD_NGL CPD_IDLE_SECONDS
             CPD_READY_TIMEOUT CPD_LOGDIR
EOF
}

die() {
  printf 'llama-server: %s\n' "$1" >&2
  exit 1
}

server_pid() {
  local pid=
  [ -f "$PIDFILE" ] || return 1
  read -r pid <"$PIDFILE" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  printf '%s\n' "$pid"
}

port_listening() {
  local listening
  listening=$(ss -ltn 2>/dev/null || true)
  grep -qE ":${PORT}([[:space:]]|\$)" <<<"$listening"
}

check_gpus() {
  local out idx used
  command -v nvidia-smi >/dev/null || return 0
  out=$(nvidia-smi --query-gpu=index,memory.used --format=csv,noheader,nounits) || return 0
  while read -r idx used; do
    case ",$GPUS," in
    *",$idx,"*)
      if [ "$used" -gt 1024 ]; then
        die "GPU $idx is already using ${used} MiB; free it or set CPD_GPUS"
      fi
      ;;
    esac
  done <<<"$out"
}

stop_server() {
  local pid
  if ! pid=$(server_pid); then
    printf 'no server started by this script (stale or missing %s)\n' "$PIDFILE" >&2
    return 0
  fi
  printf 'stopping llama-server (pid %s)\n' "$pid" >&2
  kill "$pid" || true
  local i
  for ((i = 0; i < 30; i++)); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    printf 'still alive after 30s, sending SIGKILL\n' >&2
    kill -9 "$pid" || true
    sleep 1
  fi
  rm -f "$PIDFILE"
  printf 'stopped\n'
}

cleanup() {
  if [ "${SERVER_PID:-}" != "" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    printf '\nstopping llama-server (pid %s)\n' "$SERVER_PID" >&2
    kill "$SERVER_PID" || true
    local i
    for ((i = 0; i < 30; i++)); do
      kill -0 "$SERVER_PID" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$SERVER_PID" 2>/dev/null; then
      kill -9 "$SERVER_PID" || true
    fi
  fi
  rm -f "$PIDFILE"
}

wait_ready() {
  local deadline=$((SECONDS + READY_TIMEOUT))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      printf 'llama-server died at startup, last log lines:\n' >&2
      tail -15 "$LOGFILE" >&2 || true
      return 1
    fi
    if curl -sf "http://${HOST}:${PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  printf 'still not answering after %ss, it is alive but loading\n' "$READY_TIMEOUT" >&2
  return 1
}

status() {
  local pid
  if pid=$(server_pid); then
    printf 'process: llama-server running (pid %s)\n' "$pid"
  else
    printf 'process: no llama-server started by this script\n'
  fi
  if port_listening; then
    printf 'port: %s:%s answers\n' "$HOST" "$PORT"
  else
    printf 'port: %s:%s silent\n' "$HOST" "$PORT"
  fi
  curl -sf "http://${HOST}:${PORT}/v1/models" 2>/dev/null |
    sed -n 's/.*"id":"\([^"]*\)".*/model: \1/p' || true
  if command -v nvidia-smi >/dev/null; then
    nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader,nounits |
      sed 's/^/gpu: /' || true
  fi
}

while [ $# -gt 0 ]; do
  case $1 in
  up) ;;
  down)
    stop_server
    exit 0
    ;;
  status)
    status
    exit 0
    ;;
  logs)
    [ -f "$LOGFILE" ] || die "no log at $LOGFILE yet"
    exec tail -n 50 -f "$LOGFILE"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) die "unknown argument: $1" ;;
  esac
  shift
done

[ -x "$BIN" ] || die "not executable: $BIN"
mkdir -p "$LOGDIR"

if port_listening; then
  die "port $PORT is already in use; stop it (llama-server down, or the llama-server service) or set CPD_PORT"
fi

check_gpus

printf 'serving %s:%s on %s:%s, ctx %s, GPUs %s, log %s\n' "$REPO" "$QUANT" "$HOST" "$PORT" "$CTX" "$GPUS" "$LOGFILE" >&2

SERVER_PID=
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

CUDA_VISIBLE_DEVICES="$GPUS" env LLAMA_CACHE="$CACHE" "$BIN" \
  --hf-repo "${REPO}:${QUANT}" --no-mmproj \
  --alias qwen3.8-27b --host "$HOST" --port "$PORT" \
  -ngl "$NGL" --ctx-size "$CTX" --parallel 1 \
  --split-mode tensor --fit off \
  --jinja --reasoning off \
  --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5 \
  --sleep-idle-seconds "$IDLE" \
  >>"$LOGFILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" >"$PIDFILE"

if ! wait_ready; then
  exit 1
fi

printf 'ready: http://%s:%s/v1, interrupt here to stop\n' "$HOST" "$PORT" >&2
wait "$SERVER_PID"
