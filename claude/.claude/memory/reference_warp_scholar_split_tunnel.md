---
name: reference_warp_scholar_split_tunnel
description: "Google Scholar answers 403 through the Cloudflare WARP exit; the split-tunnel fix needs a WARP excluded host and a Firefox TRR exclusion together"
metadata:
  type: reference
---

On ju-TP, `scholar.google.com` returns the 403 "We're sorry... automated queries" page through the always-on WARP tunnel, in every browser and for every query, while `www.google.com/search` returns 200 by the same exit (measured 2026-10-24). Tunnel down, Scholar returns 200 by the mobile uplink address. The block is Scholar's own policy against the Cloudflare ranges, so no user agent, cookie or query shape works around it.

The fix has two halves, and either one alone leaves Firefox broken:

- `warp-cli --accept-tos add-excluded-host scholar.google.com`, persisted in `/var/lib/cloudflare-warp/settings.json`. It excludes the IPs **WARP's own resolver** returned, so it follows Google's rotation without upkeep, and it covers curl, R, Python and Chromium, which all use the system resolver.
- `network.trr.excluded-domains` in the stow-managed `user.js`, because Firefox runs `network.trr.mode` 3 against `clean.dnsforge.de` and gets different Google edge IPs, which stay in the tunnel. Measured: `142.251.14.99` (dnsforge answer) gave 403 while `142.250.110.103` (WARP answer) gave 200 at the same moment.

`scholar.l.google.com` publishes no AAAA, so there is no IPv6 path to exclude. `add-excluded-route` on Google's CIDRs works whatever the resolver but takes the whole Google edge out of the tunnel, and was rejected for that.

Detail and measurements in `~/dotfiles/_meta/notes/warp-state.md` § "Google Scholar refuse la sortie WARP" and `dns-dnsforge-firefox.md` § "Domaines rendus au résolveur système". Related: [[reference_warp_hotspot_bufferbloat]].
