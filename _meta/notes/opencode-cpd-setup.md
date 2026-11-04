# opencode with a local llama-server on cpd000001

As-built record and reproduction procedure, updated 2026-11-04.
The scope is the single user `edjulien`; the shared, multi-user variant is deferred.

## Current state

- opencode 1.19.5 runs from `~/.opencode/bin/opencode`.
- `~/.config/opencode/opencode.json` is a stow link to `~/dotfiles/opencode/.config/opencode/opencode.json`.
- It declares the provider `cpd`, the model `cpd/qwen3.8-27b`, and the base URL `http://127.0.0.1:8090/v1`.
- The model entry is named `unsloth/Qwen3.8-27B-GGUF`.
- `llama-server` answers with the alias `qwen3.8-27b` and loads `Qwen3.8-27B-UD-Q4_K_M.gguf` from the cache in `/data2/llama.cpp`.
- `llama-server.service` is enabled and active under user `edjulien`, on `127.0.0.1:8090`, with one slot and a 98304 token context.
- The binary is the pre-existing b9286 at `/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server`.
- The stow packages `bin`, `opencode`, `agents` and `claude` are linked.
- `~/.claude/skills` is a real directory whose entries are links; `~/.local/share/opencode-claude-skills` exists and stays empty.
- `/etc/opencode` is empty, `/usr/local/bin/opencode` is absent, and neither the `llama` user nor `/opt/llama` exists.

Verified on 2026-11-04: `/health` returns `ok`, a tool call completes with `finish_reason` set to `tool_calls`, a plain reply carries no reasoning, sleep and wake work with a 60 s idle trial, and `opencode run "Reply exactly: ok"` returns `ok` through the service.

## What opencode sends

opencode resolves the model key `qwen3.8-27b` inside the provider `cpd` and sends it to the OpenAI-compatible endpoint.
The server maps that alias to `unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M` loaded from the cache.
The display name `unsloth/Qwen3.8-27B-GGUF` in the config is cosmetic.

## Decisions

- Keep b9286 instead of installing a newer build under `/opt/llama`.
  b9286 supports every flag the service uses; the only missing option is `--reasoning-effort`, which matters only for the deferred thinking A/B.
- Run the service as `edjulien` instead of creating a `llama` system user.
  Only `edjulien` uses opencode on cpd today, so the account, the ACLs and the cache permissions would add work with no user.
- Use port 8090 because 8080 is already taken.
- Keep the managed `/etc/opencode` configuration and the system-wide binary out of scope until a second user needs them.

## Parameters and why

- Sampling follows the model card for the non-thinking mode: `--temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5`.
  The thinking sampling makes this model loop when reasoning is off.
- `--reasoning off` is explicit because the chat template defaults to `xhigh`.
- `--sleep-idle-seconds 1800` unloads the model after 30 minutes without a request; the next request reloads it.
- `--ctx-size 98304` matches the client limit declared in `opencode.json`.
- `--jinja`, `--no-mmproj` and `--offline` follow the validated trial.
  The cache already holds the GGUF, so `--offline` avoids a Hub call.

Hardware, measured 2026-09-24: two Xeon Silver 4110 sockets with 32 threads and about 92 GiB of RAM, plus three Quadro RTX 6000 cards with 24 GiB each.

## Reproduction

Link the packages:

```bash
cd ~/dotfiles
stow -v -t ~ bin opencode agents
mkdir -p ~/.claude/skills ~/.local/share/opencode-claude-skills
stow -v -R --ignore='\.ruff_cache' -t ~ claude
```

`~/.claude/skills` must exist as a real directory before the `claude` package is stowed, so each skill becomes one directory link.

Install the unit:

```bash
sudo tee /etc/systemd/system/llama-server.service >/dev/null <<'EOF'
[Unit]
Description=llama-server for opencode (Qwen3.8 27B)
After=network.target

[Service]
Type=simple
User=edjulien
Group=edjulien
Environment=LLAMA_CACHE=/data2/llama.cpp
ExecStart=/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server --hf-repo unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M --offline --no-mmproj --alias qwen3.8-27b --host 127.0.0.1 --port 8090 -ngl 99 --ctx-size 98304 --parallel 1 --jinja --reasoning off --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5 --sleep-idle-seconds 1800
Restart=on-failure
RestartSec=10
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemd-analyze verify /etc/systemd/system/llama-server.service
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server
curl -s http://127.0.0.1:8090/health
```

Test opencode in a throwaway repository:

```bash
cd "$(mktemp -d)" && git init -q && opencode run "Reply exactly: ok"
```

## Operations

```bash
systemctl status llama-server
journalctl -u llama-server -n 50
curl -s http://127.0.0.1:8090/props | jq '{model_alias, is_sleeping}'
sudo systemctl restart llama-server
```

opencode reads its configuration only at startup, so restart it after a change to `opencode.json`.
The trial helpers in `_meta/cpd/` remain available: `trial-serve.sh` starts the same model on 8090 with a 60 s idle timer, and `trial-check.sh` records the health, tool call, reasoning and sleep checks.

## Deferred

- Multi-user: install opencode in `/usr/local/bin`, add a provider in `/etc/opencode/opencode.json`, create the `llama` user, grant it read access to `/data2/llama.cpp`, and change the unit to `User=llama`.
  Two simultaneous users would also need `--parallel 2 --ctx-size 196608`.
- Thinking A/B: install a build that supports `--reasoning-effort`, then replace `--reasoning off ${SAMPLING}` with `--reasoning on --reasoning-effort low --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0`.
- Claude Code is not installed on cpd, so the plugin skills directory stays empty.

## Caveats

- b9286 logs `--cache-idle-slots requires --kv-unified, disabling`.
  The trial still verified sleep and wake, so the flag is left out; add `--kv-unified` only if keeping the prompt cache across idle periods matters.
- The binary and its shared libraries belong to another user under `/data2`; removing or rebuilding that tree breaks the service.
- `--offline` logs a missing `unsloth_Qwen3.8-27B-GGUF_preset.ini` and continues; the model still loads from the cache.
