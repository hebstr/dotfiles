# mDNS names between ju-TP and ju-TP2 (WSL mirrored)

*2026-09-18T23:22:32Z by Showboat 0.6.1*
<!-- showboat-id: 797b8fa5-3c00-4eea-9626-08d418714f43 -->

Step 3 of `.claude/DESIGN-SSH.md`, done 2026-09-19. Every change below ran on `ju-TP2` (WSL, Ubuntu 24.04) and is reported by that machine's session, since `~/dotfiles` is receive-only there; the commands are tilde fences so `verify` on `ju-TP` never runs them.

WSL networking switched from NAT to mirrored, so multicast reaches the Linux side. File `C:\Users\julien\.wslconfig` (Windows side, outside the dotfiles):

~~~text
[wsl2]
networkingMode=mirrored
~~~

Applied from Windows with `wsl --shutdown`; afterwards `wslinfo` reports `mirrored` and WSL carries the Windows LAN address.

mDNS resolution on the Linux side:

~~~text
sudo apt install libnss-mdns
~~~

Observed: `libnss-mdns 0.15.1-4build1`, pulling `avahi-daemon 0.8-13ubuntu6.2`; `/etc/nsswitch.conf` reads `hosts: files mdns4_minimal [NOTFOUND=return] dns`. No Hyper-V firewall rule was needed for the mDNS replies.

Checks observed on `ju-TP2`: `getent hosts ju-TP.local` returns `ju-TP`'s LAN address, and `ssh ju-TP hostname` answers `ju-TP` with `HostName ju-TP.local`, reusing the `known_hosts` entry through `HostKeyAlias ju-TP`.

Side finding: the user unit `syncthing.service` was disabled on `ju-TP2` and did not come back after `wsl --shutdown`. Fixed there with:

~~~text
systemctl --user enable --now syncthing
~~~

On `ju-TP`, `ju-TP.local` resolves locally to `docker0`'s `172.17.0.1` (avahi answers for the local host); the alias is only used from `ju-TP2`, where the LAN address comes back.

Replayable from `ju-TP`: the other direction resolves too (the address itself changes with the hotspot, so only resolution is asserted).

```bash
getent hosts ju-TP2.local >/dev/null && echo resolved
```

```output
resolved
```
