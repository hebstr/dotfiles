#!/bin/bash
set -Eeuo pipefail

LOG=${1:-$HOME/cpd-recon-$(date +%Y%m%d-%H%M%S).log}
BIN=${CPD_LLAMA_BIN:-/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server}
CACHE=${CPD_LLAMA_CACHE:-/data2/llama.cpp}
MODEL_DIR=models--unsloth--Qwen3.8-27B-GGUF

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

# Context

printf '# cpd recon, %s\n' "$(date -Is)"
probe 'identity' 'id; hostname'
probe 'kernel and resources' 'uname -a; nproc; free -g | head -2'
probe 'nvidia driver' 'nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv'

# The llama.cpp binary and its options

probe 'binary presence' "ls -l '$BIN'; test -x '$BIN' && echo executable || echo 'NOT executable by this user'"
probe 'ownership of the build tree' "stat -c '%U:%G %a %n' '$(dirname "$(dirname "$(dirname "$BIN")")")' '$(dirname "$BIN")' '$BIN'"
probe 'version' "'$BIN' --version 2>&1 | head -5"

printf '\n### required options\n'
help=''
help_status=0
if [ ! -x "$BIN" ]; then
  printf 'the binary is not executable here: every option below is UNDETERMINED, not absent\n'
else
  help=$("$BIN" --help 2>&1) || help_status=$?
  if [ "$help_status" -ne 0 ]; then
    printf 'the --help call exited %d, so every option below is UNDETERMINED, not absent\n' "$help_status"
    printf 'its output was:\n%s\n' "$help"
  elif ! grep -qE -- '(^|[[:space:],])--host([[:space:],=]|$)' <<<"$help"; then
    printf 'no --host in the output, so this is not a help text: every option below is UNDETERMINED\n'
    printf 'its output was:\n%s\n' "$help"
  fi
fi
for f in --reasoning --reasoning-effort --sleep-idle-seconds --offline --no-mmproj --jinja --hf-repo --ctx-size --parallel --alias -c -hf -ngl -np -m; do
  if grep -qE -- "(^|[[:space:],])${f}([[:space:],=]|\$)" <<<"$help"; then
    printf '%s present\n' "$f"
  else
    printf '%s not found\n' "$f"
  fi
done

printf '\n### raw help text, %d bytes\n' "${#help}"
printf '%s\n' "$help"

probe 'what the binary is' "file '$BIN'; ldd '$BIN' 2>&1 | head -20"
probe 'the build bin directory' "ls -l '$(dirname "$BIN")' | head -20"
probe 'shared libraries beside it' "ls -l '$(dirname "$(dirname "$BIN")")' | head -20"

# Who runs the server, on which port

probe 'llama-server processes' 'ps -o user=,pid=,etime=,args= -C llama-server | cut -c1-400'
probe 'any llama process' 'pgrep -af llama | cut -c1-400'
probe 'systemd units' 'systemctl list-units --all --no-pager | grep -i llama'
probe 'listening sockets' 'ss -ltnp 2>/dev/null || ss -ltn'

port=$(pgrep -a llama-server 2>/dev/null | grep -oE -- '--port[ =]+[0-9]+' | grep -oE '[0-9]+' | head -n1 || true)
PORT=${port:-8080}
printf '\n### port in use\n%s (%s)\n' "$PORT" "$([ "$port" != "" ] && echo 'read from the process' || echo 'default, none found in any process')"

printf '\n### candidate ports\n'
taken=$(ss -ltn 2>/dev/null | grep -oE '[0-9]+ *$|:[0-9]+ ' | grep -oE '[0-9]+' | sort -u || true)
for p in 8080 8090 8181 8282 8380 8480 8686 8787 8888 9080 9090 11435 18080; do
  if grep -qx "$p" <<<"$taken"; then
    printf '%s taken\n' "$p"
  else
    printf '%s free\n' "$p"
  fi
done

# What the server serves

probe 'health' "curl -s --max-time 10 'http://127.0.0.1:${PORT}/health'"
probe 'props' "curl -s --max-time 10 'http://127.0.0.1:${PORT}/props' | head -c 4000"
probe 'models' "curl -s --max-time 10 'http://127.0.0.1:${PORT}/v1/models' | head -c 2000"
probe 'vram now' 'nvidia-smi --query-gpu=index,memory.used --format=csv,noheader'

# The model cache

probe 'cache root' "stat -c '%U:%G %a %n' '$CACHE' 2>&1; ls -l '$CACHE' | head -20"
probe 'cached Qwen3.8 files' "ls -lL '$CACHE/$MODEL_DIR'/snapshots/*/ 2>&1 | head -30"
probe 'cache readable by others' "getfacl -p '$CACHE' 2>&1 | head -20"

# The dotfiles clone and the harness

probe 'clone state' 'git -C ~/dotfiles log -1 --format="%h %ad %s" --date=short; git -C ~/dotfiles status -sb | head -5'
probe 'clone remote' 'git -C ~/dotfiles remote -v'
# shellcheck disable=SC2016
probe 'opencode config links' 'for f in opencode.json AGENTS.md plugins/claude-hooks.ts; do readlink -e ~/.config/opencode/"$f" || echo "absent: $f"; done'
probe 'opencode plugin dependency' 'ls -d ~/.config/opencode/node_modules/@opencode-ai/plugin 2>&1'
# shellcheck disable=SC2016
probe 'claude profile links' 'for d in rules hooks memory skills; do readlink -e ~/.claude/"$d" || echo "absent: $d"; done; readlink -e ~/.agents/skills || echo "absent: .agents/skills"'
probe 'managed opencode config' 'ls -l /etc/opencode/ 2>&1'

printf '\n### tool inventory\n'
for c in opencode node npm stow jq curl tar git setfacl getfacl prose-lint panache ruff air shellcheck shfmt shellharden python3 uv; do
  p=$(command -v "$c" 2>/dev/null || true)
  if [ "$p" != "" ]; then
    printf '%-12s %s\n' "$c" "$p"
  else
    printf '%-12s absent\n' "$c"
  fi
done

# Reachability the install steps need

probe 'github' "curl -sI --max-time 15 https://github.com | head -1"
probe 'github release asset head' "curl -sI --max-time 15 -L https://github.com/anomalyco/opencode/releases/latest | head -1"
probe 'npm registry' "curl -sI --max-time 15 https://registry.npmjs.org | head -1"

printf '\n# end, %s\n' "$(date -Is)"
printf 'recon written to %s\n' "$LOG" >&3
