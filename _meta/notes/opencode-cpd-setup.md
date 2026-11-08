# opencode with a local llama-server on cpd000001

As-built record and reproduction procedure, built 2026-11-04 and updated 2026-11-08.
The scope is the single user `edjulien`; the shared, multi-user variant is deferred.

## Current state

- opencode 1.19.5 runs from `~/.opencode/bin/opencode`.
- `~/.config/opencode/opencode.json` is a stow link to `~/dotfiles/opencode/.config/opencode/opencode.json`.
- It declares the provider `cpd`, the model `cpd/qwen3.8-27b`, and the base URL `http://127.0.0.1:8090/v1`, alongside a `ju-tp2` provider kept declared and unused; see "Where the machine-specific keys live".
- The model entry is named `unsloth/Qwen3.8-27B-GGUF` with a 196608 token context limit.
- The server runs from `~/.opencode/bin/llama-server.sh`, stowed from `~/dotfiles/opencode/.opencode/bin/llama-server.sh`, in the foreground of a terminal; `up` fetches the model from the Hub if absent and serves until interrupted, `down` stops it, `status` reports process, port and VRAM, `logs` tails `~/logs/cpd-llama/llama-server.log`.
- The default run loads `Qwen3.8-27B-UD-Q6_K_M.gguf` from the cache in `/data2/llama.cpp` on CUDA devices 1 and 2 with `--split-mode tensor`, a 196608 token context, one slot, and flash attention enabled by the split mode.
- The legacy `llama-server.service` unit is untouched; it stays disabled at boot, and its old single-GPU Q4_K_M run on port 8090 coexists with the script while both are up, each holding its own card set.
- The binary is the pre-existing b9286 at `/data2/llama_cpp_bin/llama.cpp/build/bin/llama-server`.
- The stow packages `bin`, `opencode`, `agents` and `claude` are linked.
- `~/.claude/skills` is a real directory whose entries are links.
- The farm directory `~/.local/share/opencode-claude-skills` does not exist on this machine: its entry left the stowed `opencode.json` on 2026-11-08 because nothing here ever fills it, and `opencode-skills-sync` would recreate it only if it ran.
- The skills clone lives at `~/.local/share/opencode/skills`, cloned 2026-11-08 from `git@github.com:hebstr/skills.git`. It is a consumer clone, never edited here, kept current with `git pull --ff-only`, and it is what serves the seven skills of `hebstr/skills` to opencode.
- The stowed `opencode.json` names that path under `skills.paths`; on `ju-TP` the same entries point at `~/Documents/packages/skills/{audit,workflow}`, so the two machines differ there (see "The skills paths override").
- `/etc/opencode` is empty, `/usr/local/bin/opencode` is absent, and neither the `llama` user nor `/opt/llama` exists.

Verified on 2026-11-04: `/health` returns `ok`, a tool call completes with `finish_reason` set to `tool_calls`, a plain reply carries no reasoning, sleep and wake work with a 60 s idle trial, and `opencode run "Reply exactly: ok"` returns `ok` through the service.
Verified on 2026-11-06 with the script: `/health` returns `ok` on the test port 8091, a chat completion answers in French, prompt processing runs at about 50 tok/s and generation at about 32 tok/s, GPUs 1 and 2 each hold 17606 MiB while GPU 0 stays with its Q4_K_M instance, and `down` frees both cards.
**The 50 tok/s is not a prefill throughput figure and must not be cited as one**, established 2026-11-07 in `cpd-inference-engine-reco.md`: it comes from that one short French chat completion on a freshly started server, so it measures per-request overhead and any PTX JIT rather than prompt processing at depth, and it sits about an order of magnitude below every published sm_75 figure for this model.
Nothing in this repository measures prefill, so the baseline has still to be taken.

Verified on 2026-11-08 for the skills clone: `opencode debug skill` resolves all seven from `~/.local/share/opencode/skills`, four under `audit` and three under `workflow`, each exactly once, with flat ids.
A live `opencode run` in a throwaway repository loaded the `reco` skill through the `skill` tool and completed, which is the first end-to-end pass of a clone-served skill on this machine.
The same run auto-rejects a skill set to `ask` in `permission.skill`, because `opencode run` has no channel to prompt: a named `allow` entry is what lets it load, as the override above shows for `reco`.

The same session measured a permission bypass: a compound `cd /home/edjulien/dotfiles && git push` was rewritten by the shell scanner into `git -C /home/edjulien/dotfiles push`, which matched an allow rule and executed without a prompt despite `"git push*": "deny"`.
The deny patterns were moved to substring form (`git*push*`, `git*reset*`, etc.) so that every flag-prefixed spelling of a write verb is caught by one pattern per verb; see `DESIGN-OPENCODE-HARNESS.md` § "The deny patterns moved from prefix to substring form, 2026-11-08".

## The skills paths override

The stowed `opencode.json` names this machine's clone path, `~/.local/share/opencode/skills/{audit,workflow}`, and `ju-TP` carries the same two entries pointing at `~/Documents/packages/skills/{audit,workflow}`.
The user decided on 2026-11-08 to edit the stowed file directly rather than keep one path for both machines with a per-machine override: the clone is not synced between the machines, so nothing breaks when the two paths differ, and a local layer was rejected as an invisible second source of truth.
The `ju-TP` entries were replaced in place; that machine re-resolves its seven skills from its own clone on next start, which owes the same check this machine had on 2026-11-08.

## Where the machine-specific keys live

In the tracked `opencode.json`, which both machines stow, and that is a decision rather than an accident.

It was questioned on 2026-11-05: one stowed file describing `cpd` leaves `ju-TP` with a `baseURL` on port 8090 and a model id naming a 27B its own 9B service does not serve, so the keys were to move to a managed `/etc/opencode/opencode.json`, the system directory opencode documents as highest in precedence.
The user then stated that opencode will not be used against `ju-TP2` until further notice, which removes the second machine from the problem: there is nothing for `ju-TP` to point at, so one file naming `cpd` describes the only setup that runs.

What the file therefore carries: `model` as `cpd/qwen3.8-27b`, the `cpd` provider with its port 8090 and its 196608 limit, and the `ju-tp2` provider kept declared and unused with its own 98304 limit, so the day `ju-TP2` comes back only `model` changes.
The managed route stays the answer if both machines ever serve at once, and `/etc/opencode` is then written with those three keys alone; its one untested assumption is whether a managed `model` wins over the stowed one, which `opencode debug config` settles in a line.

## What opencode sends

opencode resolves the model key `qwen3.8-27b` inside the provider `cpd` and sends it to the OpenAI-compatible endpoint.
The server maps that alias to `unsloth/Qwen3.8-27B-GGUF:UD-Q6_K_M` loaded from the cache.
The display name `unsloth/Qwen3.8-27B-GGUF` in the config is cosmetic.

## Decisions

- Keep b9286 instead of installing a newer build under `/opt/llama`.
  b9286 supports every flag the script uses; the only missing option is `--reasoning-effort`, which matters only for the deferred thinking A/B.
- Run the server as `edjulien` from a foreground script instead of creating a `llama` system user or a systemd unit.
  Only `edjulien` uses opencode on cpd today, and a terminal process keeps the lifecycle visible: start it with `llama-server.sh up`, stop it with `down` or by interrupting the terminal.
- Use `UD-Q6_K_M` instead of `UD-Q4_K_M` now that two cards are available.
  The Q6 weights plus the 196608 token KV cache leave about 7 GiB free per card, and the measured generation speed is about 32 tok/s on two cards, above the single-card Q4 figure.
- Split across CUDA devices 1 and 2 with `--split-mode tensor` instead of device 0 alone.
  Device 0 stays free for the legacy service or other work; the default `CPD_GPUS=1,2` was chosen on 2026-11-06 so the upgrade can be tested while the old instance keeps serving this very session.
- Use port 8090 because 8080 is already taken; tests use `CPD_PORT=8091` or another free port while the legacy instance holds 8090.
- Keep the managed `/etc/opencode` configuration and the system-wide binary out of scope until a second user needs them.
  The managed file was reconsidered on 2026-11-05 as a way to stop one stowed file describing two machines, then left out again once opencode stopped being used against `ju-TP2`: see "Where the machine-specific keys live".

## Parameters and why

- Sampling follows the model card for the non-thinking mode: `--temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5`.
  The thinking sampling makes this model loop when reasoning is off.
- `--reasoning off` is explicit because the chat template defaults to `xhigh`.
- `--sleep-idle-seconds 1800` unloads the model after 30 minutes without a request; the next request reloads it.
  This still applies while the server runs, and `down` is the way to free the process and its VRAM.
- `CUDA_VISIBLE_DEVICES=1,2` restricts the process to the second and third cards, leaving device 0 free.
- `--split-mode tensor` splits weights and KV across the two cards in parallel; b9286 enables flash attention automatically for this mode, and it is the only split mode that keeps the KV cache on the GPUs at a 196608 context.
  The default layer mode would instead pipeline layers between cards and put most of the KV on one card.
- `--fit off` is required because b9286 aborts with "llama_params_fit is not implemented for SPLIT_MODE_TENSOR" while fitting is on.
  The budget is checked by hand: about 11.5 GiB of weights per card plus the KV cache leaves headroom in the measured 17606 MiB per card.
- No `--cache-type-k` or `--cache-type-v`: b9286 refuses to combine KV quantization with `SPLIT_MODE_TENSOR`, and the unquantized KV still fits at 196608 tokens on two cards.
- `--ctx-size 196608` triples the old context and matches the `cpd` provider's `limit.context` in `opencode.json`; it stays under the model's trained 262144.
- `--hf-repo unsloth/Qwen3.8-27B-GGUF:UD-Q6_K_M` lets llama.cpp fetch the GGUF into `/data2/llama.cpp` on first start; no `--offline`, because the download is the point of the flag and later starts hit the cache without a Hub call.
- `--jinja` and `--no-mmproj` follow the validated trial.

Hardware, measured 2026-09-24: two Xeon Silver 4110 sockets with 32 threads and about 92 GiB of RAM, plus three Quadro RTX 6000 cards with 24 GiB each.

## Reproduction

Link the packages:

```bash
cd ~/dotfiles
stow -v -t ~ bin opencode agents
mkdir -p ~/.claude/skills
stow -v -R --ignore='\.ruff_cache' -t ~ claude
```

`~/.claude/skills` must exist as a real directory before the `claude` package is stowed, so each skill becomes one directory link.

Clone the skills repository into this machine's own path:

```bash
mkdir -p ~/.local/share/opencode
git clone https://github.com/hebstr/skills.git ~/.local/share/opencode/skills
```

The stowed `opencode.json` already names this path under `skills.paths`, so no per-machine configuration step is needed here.
Check what opencode resolves from the clone, reading the output from a file because this command truncates when piped:

```bash
opencode debug skill > /tmp/skills.txt && rg -o '"location": "[^"]*opencode/skills[^"]*"' /tmp/skills.txt
```

Seven lines are expected, four under `audit` and three under `workflow`.
Nothing refreshes that clone on its own: `git pull --ff-only` there is what updates the skills.

Start the server in a terminal; the first run downloads the Q6_K_M GGUF into `/data2/llama.cpp`:

```bash
~/.opencode/bin/llama-server.sh up
curl -s http://127.0.0.1:8090/health
```

Test opencode in a throwaway repository, from another terminal while the server runs:

```bash
cd "$(mktemp -d)" && git init -q && opencode run "Reply exactly: ok"
```

## Operations

```bash
~/.opencode/bin/llama-server.sh status
~/.opencode/bin/llama-server.sh logs
~/.opencode/bin/llama-server.sh down
curl -s http://127.0.0.1:8090/props | jq '{model_alias, is_sleeping}'
```

`up` runs in the foreground until interrupted; `down` stops the instance it started and frees the VRAM.
A reboot leaves no server behind, which is the same posture the disabled unit gave.
The legacy `llama-server.service` unit still exists for the old single-GPU Q4_K_M run; it stays disabled at boot and is never `enable`d on this machine.

opencode reads its configuration only at startup, so restart it after a change to `opencode.json`.
The trial helpers in `_meta/cpd/` remain available: `trial-serve.sh` starts the model on 8090 with a 60 s idle timer and no GPU restriction, and `trial-check.sh` records the health, tool call, reasoning and sleep checks.

## Deferred

- Multi-user: install opencode in `/usr/local/bin`, add a provider in `/etc/opencode/opencode.json`, create the `llama` user, and change the unit to `User=llama`.
  Reading `/data2/llama.cpp` needs no grant, the cache being mode 777 with `other::rwx`.
  Two simultaneous users would need more VRAM than one card provides, so revisit `CUDA_VISIBLE_DEVICES` and `--ctx-size` at that point.
- Thinking A/B: install a build that supports `--reasoning-effort`, then replace `--reasoning off ${SAMPLING}` with `--reasoning on --reasoning-effort low --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0`.
- Claude Code is not installed on cpd, so no link farm exists here and the third-party plugin skills of its cache stay out. The seven skills of `hebstr/skills` reach opencode from the clone instead, decided 2026-11-08: see "Current state" above and `DESIGN-OPENCODE-HARNESS.md` § "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08".

## Caveats

- b9286 logs `--cache-idle-slots requires --kv-unified, disabling`.
  The trial still verified sleep and wake, so the flag is left out; add `--kv-unified` only if keeping the prompt cache across idle periods matters.
- The binary and its shared libraries belong to another user under `/data2`; removing or rebuilding that tree breaks the server.
  `git/.gitconfig` carries `[safe] directory = /data2/llama_cpp_bin/llama.cpp` (added 2026-11-05) so git accepts the foreign-owned tree without a dubious-ownership refusal.
- b9286 does not accept the short forms `--sm` and `--ctk`; the script uses `--split-mode` and would use `--cache-type-k` if KV quantization ever becomes possible, which it is not while flash attention is forced by the tensor split.
- The first `up` needs network access to the Hub for the Q6_K_M download; later starts read the cache directly.
