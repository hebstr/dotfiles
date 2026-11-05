# opencode with a local llama-server on cpd000001

As-built record and reproduction procedure, built 2026-11-04 and updated 2026-11-05.
The scope is the single user `edjulien`; the shared, multi-user variant is deferred.

## Current state

- opencode 1.19.5 runs from `~/.opencode/bin/opencode`.
- `~/.config/opencode/opencode.json` is a stow link to `~/dotfiles/opencode/.config/opencode/opencode.json`.
- It declares the provider `cpd`, the model `cpd/qwen3.8-27b`, and the base URL `http://127.0.0.1:8090/v1`, alongside a `ju-tp2` provider kept declared and unused; see "Where the machine-specific keys live".
- The model entry is named `unsloth/Qwen3.8-27B-GGUF`.
- `llama-server` answers with the alias `qwen3.8-27b` and loads `Qwen3.8-27B-UD-Q4_K_M.gguf` from the cache in `/data2/llama.cpp`.
- `llama-server.service` is disabled at boot and inactive by default.
  It is started on demand under user `edjulien`, on `127.0.0.1:8090`, with one slot, a 65536 token context, and only CUDA device 0 visible.
- The binary is the pre-existing b9286 at `/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server`.
- The stow packages `bin`, `opencode`, `agents` and `claude` are linked.
- `~/.claude/skills` is a real directory whose entries are links; `~/.local/share/opencode-claude-skills` exists and stays empty.
- `/etc/opencode` is empty, `/usr/local/bin/opencode` is absent, and neither the `llama` user nor `/opt/llama` exists.

Verified on 2026-11-04: `/health` returns `ok`, a tool call completes with `finish_reason` set to `tool_calls`, a plain reply carries no reasoning, sleep and wake work with a 60 s idle trial, and `opencode run "Reply exactly: ok"` returns `ok` through the service.
A one-GPU run with `CUDA_VISIBLE_DEVICES=0` and a 65536 context loaded with health `ok`, used 20062 MiB on GPU 0, kept GPUs 1 and 2 at 1 MiB, and freed the VRAM at exit.

## Where the machine-specific keys live

In the tracked `opencode.json`, which both machines stow, and that is a decision rather than an accident.

It was questioned on 2026-11-05: one stowed file describing `cpd` leaves `ju-TP` with a `baseURL` on port 8090 and a model id naming a 27B its own 9B service does not serve, so the keys were to move to a managed `/etc/opencode/opencode.json`, the system directory opencode documents as highest in precedence.
The user then stated that opencode will not be used against `ju-TP2` until further notice, which removes the second machine from the problem: there is nothing for `ju-TP` to point at, so one file naming `cpd` describes the only setup that runs.

What the file therefore carries: `model` as `cpd/qwen3.8-27b`, the `cpd` provider with its port 8090 and its 65536 limit, and the `ju-tp2` provider kept declared and unused with its own 98304 limit, so the day `ju-TP2` comes back only `model` changes.
The managed route stays the answer if both machines ever serve at once, and `/etc/opencode` is then written with those three keys alone; its one untested assumption is whether a managed `model` wins over the stowed one, which `opencode debug config` settles in a line.

## What opencode sends

opencode resolves the model key `qwen3.8-27b` inside the provider `cpd` and sends it to the OpenAI-compatible endpoint.
The server maps that alias to `unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M` loaded from the cache.
The display name `unsloth/Qwen3.8-27B-GGUF` in the config is cosmetic.

## Decisions

- Keep b9286 instead of installing a newer build under `/opt/llama`.
  b9286 supports every flag the service uses; the only missing option is `--reasoning-effort`, which matters only for the deferred thinking A/B.
- Run the service as `edjulien` instead of creating a `llama` system user.
  Only `edjulien` uses opencode on cpd today, so the account, the ACLs and the cache permissions would add work with no user.
- Keep the unit disabled at boot and start it on demand.
  The process holds a GPU and the model only while it runs, and `stop` frees the VRAM immediately.
- Restrict the service to GPU 0 with `CUDA_VISIBLE_DEVICES=0`, and lower the context to 65536 so the model fits on one card.
  The measured 20062 MiB leaves about 4 GiB of headroom, while the original 98304 context spread over three cards used 24458 MiB in total.
- Use port 8090 because 8080 is already taken.
- Keep the managed `/etc/opencode` configuration and the system-wide binary out of scope until a second user needs them.
  The managed file was reconsidered on 2026-11-05 as a way to stop one stowed file describing two machines, then left out again once opencode stopped being used against `ju-TP2`: see "Where the machine-specific keys live".

## Parameters and why

- Sampling follows the model card for the non-thinking mode: `--temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5`.
  The thinking sampling makes this model loop when reasoning is off.
- `--reasoning off` is explicit because the chat template defaults to `xhigh`.
- `--sleep-idle-seconds 1800` unloads the model after 30 minutes without a request; the next request reloads it.
  This still applies while the service is started, and `stop` is the way to free the process and its VRAM.
- `CUDA_VISIBLE_DEVICES=0` restricts the process to the first card, leaving the other two free.
- `--ctx-size 65536` keeps the model within one card, and matches the `cpd` provider's `limit.context` in `opencode.json`.
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
Environment=CUDA_VISIBLE_DEVICES=0
ExecStart=/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server --hf-repo unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M --offline --no-mmproj --alias qwen3.8-27b --host 127.0.0.1 --port 8090 -ngl 99 --ctx-size 65536 --parallel 1 --jinja --reasoning off --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5 --sleep-idle-seconds 1800
Restart=on-failure
RestartSec=10
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemd-analyze verify /etc/systemd/system/llama-server.service
sudo systemctl daemon-reload
sudo systemctl disable llama-server
sudo systemctl start llama-server
curl -s http://127.0.0.1:8090/health
sudo systemctl stop llama-server
```

Test opencode in a throwaway repository:

```bash
cd "$(mktemp -d)" && git init -q && opencode run "Reply exactly: ok"
```

## Operations

```bash
systemctl is-enabled llama-server
systemctl is-active llama-server
systemctl status llama-server
journalctl -u llama-server -n 50
curl -s http://127.0.0.1:8090/props | jq '{model_alias, is_sleeping}'
sudo systemctl start llama-server
sudo systemctl stop llama-server
sudo systemctl restart llama-server
```

`enable` is never used on this machine; the unit stays disabled so a reboot leaves the GPU free.
`start` loads the model on demand, and `stop` frees the VRAM.

opencode reads its configuration only at startup, so restart it after a change to `opencode.json`.
The trial helpers in `_meta/cpd/` remain available: `trial-serve.sh` starts the model on 8090 with a 60 s idle timer and no GPU restriction, and `trial-check.sh` records the health, tool call, reasoning and sleep checks.

## Deferred

- Multi-user: install opencode in `/usr/local/bin`, add a provider in `/etc/opencode/opencode.json`, create the `llama` user, and change the unit to `User=llama`.
  Reading `/data2/llama.cpp` needs no grant, the cache being mode 777 with `other::rwx`.
  Two simultaneous users would need more VRAM than one card provides, so revisit `CUDA_VISIBLE_DEVICES` and `--ctx-size` at that point.
- Thinking A/B: install a build that supports `--reasoning-effort`, then replace `--reasoning off ${SAMPLING}` with `--reasoning on --reasoning-effort low --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0`.
- Claude Code is not installed on cpd, so the plugin skills directory stays empty.

## Caveats

- b9286 logs `--cache-idle-slots requires --kv-unified, disabling`.
  The trial still verified sleep and wake, so the flag is left out; add `--kv-unified` only if keeping the prompt cache across idle periods matters.
- The binary and its shared libraries belong to another user under `/data2`; removing or rebuilding that tree breaks the service. `git/.gitconfig` carries `[safe] directory = /data2/llama_cpp_bin/llama.cpp` (added 2026-11-05) so git accepts the foreign-owned tree without a dubious-ownership refusal.
- `--offline` logs a missing `unsloth_Qwen3.8-27B-GGUF_preset.ini` and continues; the model still loads from the cache.
