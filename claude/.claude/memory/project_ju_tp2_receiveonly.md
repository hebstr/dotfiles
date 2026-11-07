---
name: "ju-TP2, the second machine: receive-only trees, the GPU, the Syncthing link"
description: "Everything about ju-TP2 in one file: ~/dotfiles and ~/.claude are receive-only there and ju-TP is the single writer; the RTX A3000 12 GB and its llama.cpp serve dev and smoke tests only, never a bench; and what broke the Syncthing link on 2026-10-19, what actually fixed it and the fallback if discovery goes empty again"
metadata:
  type: project
---

## The trees are receive-only, ju-TP is the single writer

`~/dotfiles` and `~/.claude` are Syncthing `sendonly` on `ju-TP` and `receiveonly` on `ju-TP2` (see `_meta/notes/wsl-init-tuto.md`, "Git se pratique sur la machine principale").
Any write on `ju-TP2` stays a local change that never reaches `ju-TP` or git, and is silently replaced whenever `ju-TP` touches the same file.

**Why:** on 2026-09-19 a `ju-TP2` session edited README, CLAUDE.md, tracking files and a new stow package locally while a `ju-TP` session did the same step; three `ju-TP2` edits were lost to overwrites and the rest duplicated work already done on `ju-TP`.

**How to apply:** on `ju-TP2`, treat both trees as read-only. A change they need is made on `ju-TP`, either by the `ju-TP` session or over `ssh ju-TP`, and only while no `ju-TP` session is editing the same files. Stray local edits on `ju-TP2` are staged to a directory outside the synced trees, merged on `ju-TP`, then discarded with Syncthing's "Revert Local Changes" on `dotfiles`. Never revert `claude` while a Claude Code session runs on `ju-TP2`: the harness itself writes its session state under `~/.claude`, and what `syncthing/.claude/.stignore` does not exclude shows up there as local changes that a revert deletes. The rule binds authored edits, not the harness's own writes. Check the hostname before any write in these trees. Since 2026-09-19 `ssh ju-TP2` works from `ju-TP` (`.claude/DESIGN-SSH.md` in the dotfiles), so a read on `ju-TP2` no longer needs its session.

## The GPU serves dev and smoke tests, never a bench

`ju-TP2` is the second machine with a GPU, and the only one reachable from `ju-TP` for an LLM run: an RTX A3000 12GB Laptop (11520 MiB, driver 596.52) under WSL2 with CUDA passthrough (`/dev/dxg`, `libcuda` in `/usr/lib/wsl/lib`), 24 threads, about 15 GB of RAM on the WSL side, and `llama.cpp` b11065 with a CUDA backend in `~/.local/opt`, exposed as `~/.local/bin/llama-server`. Relevé 2026-10-19 over ssh.

**Why:** the user settled on 2026-10-19 that it serves dev and smoke tests only, never a production annotation run, which stays on the 3-GPU CHU server. 12 GB rules out the whole model class the `eds-avc` bench uses (24B-35B Q4_K_M needs 14-20 GB), so a result measured there has no bench value, only pipeline value.

A long run detaches there in two ways, both verified 2026-10-19 and neither needing an install: `tmux` is at `/usr/bin/tmux` on `ju-TP2` (the client machine needs none, only `ssh`), and `systemd-run --user` works from a non-interactive `ssh` because `XDG_RUNTIME_DIR` and the user bus are set, with `Linger=yes` and `KillUserProcesses=no`. The user manager's default PATH holds `/usr/local/bin` (so `uv` resolves) but not `~/.local/bin`, which is why a launcher script must put `~/.local/bin` on the PATH itself for `llama-server` to be found.

**How to apply:** three traps, each measured rather than assumed. A non-interactive `ssh` PATH excludes `~/.local/bin`, so a remote command exports it or calls the binary by path, and `nvidia-smi` exists only as `/usr/lib/wsl/lib/nvidia-smi`. `hf` downloads are not reusable by `llama-server --hf-repo` (see [[reference_llama_server_gpu_serving]]), so a model already in `~/.cache/huggingface/hub` is still re-downloaded. And the Syncthing folder `Documents` is `sendonly` on `ju-TP` and `receiveonly` there, exactly like the trees of the first section: project data arrives, nothing written on `ju-TP2` ever reaches `ju-TP`, and an output written there is a local addition that a "Revert Local Changes" deletes. Treat every artefact a run produces on `ju-TP2` as disposable. That `.stignore` also excludes `.git`, `.venv` and `.env`, hence an empty `.git` (no git there), an empty `.venv` that `uv run` rebuilds, and a hand-copied `.env` that nothing synchronises.

## The Syncthing link, what broke it and what actually fixed it

Diagnosed and repaired 2026-10-19. The symptom to recognise: both daemons running (`syncthing.service` enabled on `ju-TP2`, two `syncthing serve` processes on `ju-TP` started outside systemd, its user unit reading `inactive`), no device paused, `Documents` shared with `ju-TP2-ubuntu` (`MOFXAU5`), and every device nonetheless `DISCONNECTED`.

**Why:** two unrelated failures at once. Inbound to `ju-TP2` was firewalled: WSL runs mirrored, so it shares the host's `/24` and its daemon listens on `*:22001`, but the Hyper-V firewall (`DefaultInboundAction Block`) passed only the ssh rule, so a TCP dial to 22001 from `ju-TP` was refused while port 22 answered. Outbound from `ju-TP2` had nothing to dial: `syncthing cli show discovery` returned `{}` there, so no address for `ju-TP` was ever learned.

**How it was fixed, and what actually did it.** An inbound Hyper-V rule now exists on the Windows host, created by the user from an elevated PowerShell, modelled field by field on the existing `WSL-SSH-2222`:

```
New-NetFirewallHyperVRule -Name WSL-SYNCTHING-22001 -DisplayName WSL-SYNCTHING-22001 -Direction Inbound -Action Allow -Protocol TCP -LocalPorts 22001 -RemoteAddresses 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
```

TCP to `ju-TP2:22001` passes since. But the link itself came back through the other side: after a `syncthing cli operations restart` on `ju-TP2`, its discovery filled with `ju-TP`'s addresses (LAN, WARP, Cloudflare public, relays, which is the global discovery answering) and it dials out, the connection reading `tcp-client` there and `tcp-server` on `ju-TP`. So the restart is what restored it; the rule buys a second path, letting `ju-TP` dial in when `ju-TP2`'s discovery is empty. Do not credit the rule with the repair.

**How to apply:** if the link breaks again, restart the `ju-TP2` daemon first and check `syncthing cli show discovery` there. If it stays `{}`, add a static address as a fallback, `syncthing cli config devices <ju-TP device id> addresses add tcp://10.174.119.188:22000`, remembering that `ju-TP`'s address is DHCP and that `dynamic` must stay as entry 0. Interop to Windows works from `ju-TP2` by absolute path (`/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe`), not through `command -v`, and the account's token is already elevated, so reads of the firewall need no prompt; writes to it are refused by the auto-mode classifier and belong to the user. Nothing here changes that the trees of the first section stay read-only on `ju-TP2`, while the Syncthing config under `~/.local/state/syncthing/` is a real file there and may be edited.
