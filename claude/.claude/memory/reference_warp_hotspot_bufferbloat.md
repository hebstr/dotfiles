---
name: reference_warp_hotspot_bufferbloat
description: "Claude Code stalls on ju-TP traced to uplink bufferbloat, not to WARP or wifi: the cake shaper that fixes it, and the checks already ruled out"
metadata:
  type: reference
---

On ju-TP behind the `ju-DG` wifi hotspot, Claude Code "waiting for API" stalls come from uplink bufferbloat, not from a broken link (measured 2026-10-01).

Chain: laptop → hotspot `ju-DG` (172.30.227.0/24) → Cloudflare WARP always-on (tun `CloudflareWARP`, MTU 1280, all v4 and v6 routed in, table 65743) → Anthropic. `api.anthropic.com` resolves to `2607:6bc0::10`, reachable in IPv6 only through WARP, since the wifi link carries no global v6 address.

Measured uplink: 775 kB/s (6.2 Mbit/s). RTT at rest 44 ms avg / 53 ms max; during a 12 MB upload it rose to 369 ms avg / 877 ms max with 0 % loss. `fq_codel` on the tunnel showed 0 drops and an empty backlog, so the saturated queue sits downstream in the hotspot or the carrier, not on the machine.

The trigger is Claude Code's traffic shape: the Messages API is stateless, so every request re-uploads the whole conversation plus all tool definitions, and the two always-on MCP servers (ouroboros, litrev) ride along each time. The tunnel sent 185 MiB against 52 MiB received in 3 h 34. WARP turns a local slowdown into a global one, since every TCP stream shares one UDP flow: the two `HANDSHAKE(KEEPALIVE + REKEY_TIMEOUT)` warnings in the journal are the tunnel's own rekey stuck behind the full queue.

Fix: `tc qdisc replace dev CloudflareWARP root cake bandwidth 5Mbit` (`sch_cake` ships with the 6.8 kernel). It pulls the queue back under cake, which drains it in 8 ms: RTT under upload dropped to 35.5 ms avg / 50.9 ms max, at the cost of 27 % of peak upload. Keep the ~20 % margin under the measured peak: a mobile uplink varies with signal and cell load, and a shaper above the real bottleneck gives the queue back to the carrier. The qdisc dies whenever WARP recreates its interface, hence the `warp-cake.service` unit bound to `sys-subsystem-net-devices-CloudflareWARP.device`, sourced in `~/dotfiles/_meta/warp-cake/`.

Already ruled out, do not re-investigate: wifi (signal 94 %, -52 dBm, no errors, no disconnect), the tunnel itself (loss 0.0 %, latency p50 48 ms), DNS, and TTFB to the API (150–190 ms, v4 and v6 alike). No API or network error entry appears in the transcripts. A naive grep returns two kinds of false hit, both verified as such: an earlier eds-prise session's own investigation command, which carries `overloaded_error` as a search pattern, and the substring `stream error` inside "downstream errors" in a memory file's content.
