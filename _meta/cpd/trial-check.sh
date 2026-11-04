#!/bin/bash
set -Eeuo pipefail

PORT=${CPD_PORT:-8090}
BASE=http://127.0.0.1:${PORT}
IDLE_WAIT=${CPD_IDLE_WAIT:-75}
LOG=${1:-$HOME/cpd-trial-$(date +%Y%m%d-%H%M%S).log}

exec 3>&2
exec >"$LOG" 2>&1

probe() {
  local label=$1 cmd=$2 status=0
  printf '\n### %s\n$ %s\n' "$label" "$cmd"
  bash -c "$cmd" 2>&1 || status=$?
  if [ "$status" -ne 0 ]; then
    printf '[exit %d]\n' "$status"
  fi
}

ask() {
  local label=$1 payload=$2 filter=$3 out=''
  printf '\n### %s\n' "$label"
  out=$(curl -s --max-time 180 "${BASE}/v1/chat/completions" \
    -H 'Content-Type: application/json' -d "$payload" || true)
  if [ "$out" = "" ]; then
    printf 'empty response\n'
    return 0
  fi
  jq -c "$filter" <<<"$out" || printf 'jq could not parse it, raw:\n%s\n' "$out"
}

PLAIN='{"messages":[{"role":"user","content":"Reply with exactly: ok"}]}'
TOOL='{"messages":[{"role":"user","content":"Quel temps fait-il a Lille ?"}],"tools":[{"type":"function","function":{"name":"get_weather","description":"Meteo d une ville","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]}'

# Loaded

printf '# cpd trial checks, %s, port %s\n' "$(date -Is)" "$PORT"
probe 'health' "curl -s --max-time 30 '${BASE}/health'"
probe 'vram while loaded' 'nvidia-smi --query-gpu=index,memory.used --format=csv,noheader'
probe 'props' "curl -s --max-time 30 '${BASE}/props' | head -c 3000"

ask 'plain reply, reasoning must be 0' "$PLAIN" \
  '{content: .choices[0].message.content, reasoning: (.choices[0].message.reasoning_content // "" | length), tokens: .usage.completion_tokens}'
ask 'tool call, finish_reason must be tool_calls' "$TOOL" \
  '.choices[0] | {finish_reason, call: .message.tool_calls[0].function}'

# Sleep on idle

probe "waiting ${IDLE_WAIT}s without a request" "sleep ${IDLE_WAIT}"
probe 'is_sleeping' "curl -s --max-time 30 '${BASE}/props' | jq .is_sleeping"
probe 'vram while asleep' 'nvidia-smi --query-gpu=index,memory.used --format=csv,noheader'

# Wake

ask 'reply after wake' "$PLAIN" '{content: .choices[0].message.content}'
probe 'vram after wake' 'nvidia-smi --query-gpu=index,memory.used --format=csv,noheader'

printf '\n# end, %s\n' "$(date -Is)"
printf 'trial log written to %s\n' "$LOG" >&3
