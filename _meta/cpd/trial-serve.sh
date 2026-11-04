#!/bin/bash
set -Eeuo pipefail

BIN=${CPD_LLAMA_BIN:-/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server}
CACHE=${CPD_LLAMA_CACHE:-/data2/llama.cpp}
PORT=${CPD_PORT:-8090}
REPO=${CPD_MODEL_REPO:-unsloth/Qwen3.8-27B-GGUF}
QUANT=${CPD_MODEL_QUANT:-UD-Q4_K_M}
IDLE=${CPD_IDLE_SECONDS:-60}

if [ ! -x "$BIN" ]; then
  printf 'not executable: %s\n' "$BIN" >&2
  exit 1
fi

listening=$(ss -ltn 2>/dev/null || true)
if grep -qE ":${PORT}([[:space:]]|\$)" <<<"$listening"; then
  printf 'port %s is already in use; pick a free one with CPD_PORT=<n>\n' "$PORT" >&2
  exit 1
fi

printf 'serving %s:%s on 127.0.0.1:%s, sleeping after %ss idle, Ctrl-C to stop\n' \
  "$REPO" "$QUANT" "$PORT" "$IDLE" >&2

exec env LLAMA_CACHE="$CACHE" "$BIN" \
  --hf-repo "${REPO}:${QUANT}" --offline --no-mmproj \
  --alias qwen3.8-27b --host 127.0.0.1 --port "$PORT" \
  -ngl 99 --ctx-size 98304 --parallel 1 \
  --jinja --reasoning off \
  --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5 \
  --sleep-idle-seconds "$IDLE"
