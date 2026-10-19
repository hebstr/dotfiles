---
name: ju-TP2 as the GPU dev and smoke-test machine
description: ju-TP2 carries an RTX A3000 12 GB and a llama.cpp build, reachable over ssh for dev and smoke tests only; what fits in 12 GB, the PATH and Syncthing traps, and why an LLM run there is never a production run
metadata:
  type: project
---

`ju-TP2` is the second machine with a GPU, and the only one reachable from `ju-TP` for an LLM run: an RTX A3000 12GB Laptop (11520 MiB, driver 596.52) under WSL2 with CUDA passthrough (`/dev/dxg`, `libcuda` in `/usr/lib/wsl/lib`), 24 threads, about 15 GB of RAM on the WSL side, and `llama.cpp` b11065 with a CUDA backend in `~/.local/opt`, exposed as `~/.local/bin/llama-server`. Relevé 2026-10-19 over ssh.

**Why:** the user settled on 2026-10-19 that it serves dev and smoke tests only, never a production annotation run, which stays on the 3-GPU CHU server. 12 GB rules out the whole model class the `eds-avc` bench uses (24B-35B Q4_K_M needs 14-20 GB), so a result measured there has no bench value, only pipeline value.

A long run detaches there in two ways, both verified 2026-10-19 and neither needing an install: `tmux` is at `/usr/bin/tmux` on `ju-TP2` (the client machine needs none, only `ssh`), and `systemd-run --user` works from a non-interactive `ssh` because `XDG_RUNTIME_DIR` and the user bus are set, with `Linger=yes` and `KillUserProcesses=no`. The user manager's default PATH holds `/usr/local/bin` (so `uv` resolves) but not `~/.local/bin`, which is why a launcher script must put `~/.local/bin` on the PATH itself for `llama-server` to be found.

**How to apply:** three traps, each measured rather than assumed. A non-interactive `ssh` PATH excludes `~/.local/bin`, so a remote command exports it or calls the binary by path, and `nvidia-smi` exists only as `/usr/lib/wsl/lib/nvidia-smi`. `hf` downloads are not reusable by `llama-server --hf-repo` (see [[reference_llama_server_gpu_serving]]), so a model already in `~/.cache/huggingface/hub` is still re-downloaded. And the Syncthing folder `Documents` is `sendonly` on `ju-TP` and `receiveonly` there, exactly like the trees of [[project_ju_tp2_receiveonly]]: project data arrives, nothing written on `ju-TP2` ever reaches `ju-TP`, and an output written there is a local addition that a "Revert Local Changes" deletes. Treat every artefact a run produces on `ju-TP2` as disposable. That `.stignore` also excludes `.git`, `.venv` and `.env`, hence an empty `.git` (no git there), an empty `.venv` that `uv run` rebuilds, and a hand-copied `.env` that nothing synchronises.
