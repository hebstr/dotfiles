---
name: Syncthing ju-TP to ju-TP2: what breaks the link and how it was fixed
description: The ju-TP/ju-TP2 Syncthing link once showed every device DISCONNECTED with both daemons healthy; the inbound Hyper-V rule for WSL and a daemon restart fixed it, and a static address is the fallback if discovery goes empty again
metadata:
  type: project
---

Diagnosed and repaired 2026-10-19. The symptom to recognise: both daemons running (`syncthing.service` enabled on `ju-TP2`, two `syncthing serve` processes on `ju-TP` started outside systemd, its user unit reading `inactive`), no device paused, `Documents` shared with `ju-TP2-ubuntu` (`MOFXAU5`), and every device nonetheless `DISCONNECTED`.

**Why:** two unrelated failures at once. Inbound to `ju-TP2` was firewalled: WSL runs mirrored, so it shares the host's `/24` and its daemon listens on `*:22001`, but the Hyper-V firewall (`DefaultInboundAction Block`) passed only the ssh rule, so a TCP dial to 22001 from `ju-TP` was refused while port 22 answered. Outbound from `ju-TP2` had nothing to dial: `syncthing cli show discovery` returned `{}` there, so no address for `ju-TP` was ever learned.

**How it was fixed, and what actually did it.** An inbound Hyper-V rule now exists on the Windows host, created by the user from an elevated PowerShell, modelled field by field on the existing `WSL-SSH-2222`:

```
New-NetFirewallHyperVRule -Name WSL-SYNCTHING-22001 -DisplayName WSL-SYNCTHING-22001 -Direction Inbound -Action Allow -Protocol TCP -LocalPorts 22001 -RemoteAddresses 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
```

TCP to `ju-TP2:22001` passes since. But the link itself came back through the other side: after a `syncthing cli operations restart` on `ju-TP2`, its discovery filled with `ju-TP`'s addresses (LAN, WARP, Cloudflare public, relays, which is the global discovery answering) and it dials out, the connection reading `tcp-client` there and `tcp-server` on `ju-TP`. So the restart is what restored it; the rule buys a second path, letting `ju-TP` dial in when `ju-TP2`'s discovery is empty. Do not credit the rule with the repair.

**How to apply:** if the link breaks again, restart the `ju-TP2` daemon first and check `syncthing cli show discovery` there. If it stays `{}`, add a static address as a fallback, `syncthing cli config devices <ju-TP device id> addresses add tcp://10.174.119.188:22000`, remembering that `ju-TP`'s address is DHCP and that `dynamic` must stay as entry 0. Interop to Windows works from `ju-TP2` by absolute path (`/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe`), not through `command -v`, and the account's token is already elevated, so reads of the firewall need no prompt; writes to it are refused by the auto-mode classifier and belong to the user. Nothing here changes that the trees of [[project_ju_tp2_receiveonly]] stay read-only on `ju-TP2`, while the Syncthing config under `~/.local/state/syncthing/` is a real file there and may be edited.
