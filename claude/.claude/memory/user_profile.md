---
name: user_profile
description: Environment details and accounts not covered in CLAUDE.md
metadata:
  type: user
---

- GitHub account: hebstr
- Has multiple active R packages (edstr, hebstr)
- Data engineer / data scientist at CHU de Lille, on real-world-evidence / pharmaco-epidemiology work in a hospital EDS (Entrepôt de Données de Santé) context; works at the intersection of health data engineering and biostatistics
- Asks short questions and expects the assistant to infer the full context; comfortable with technical depth when needed
- Actively improving agentic methodology; self-identifies difficulty formulating intent precisely: frame guidance concretely, favor examples over abstractions
- Machines:
  - `ju-TP`: the daily driver, Ubuntu 24.04, no usable GPU for inference.
  - `ju-TP2`: Ubuntu under WSL2, reachable as `ssh ju-TP2`, with a CUDA-capable GPU; anything needing a GPU runs there (`~/dotfiles/.claude/DESIGN-GPU-REMOTE.md`). See [[project_ju_tp2_receiveonly]] before writing anything there.
- Network:
  - No home router: connectivity is a personal mobile plan through a relay, so router-level configuration is out of reach and bandwidth is a real cost.
  - Cloudflare WARP owns system DNS, so any system-wide resolver change means dropping WARP (`~/dotfiles/_meta/notes/warp-state.md`).
  - Firefox does DoH with `network.trr.mode=3`, never 2: in mode 2 a filtering resolver's block falls back to system DNS and filters nothing (`~/dotfiles/_meta/notes/dns-dnsforge-firefox.md`).
