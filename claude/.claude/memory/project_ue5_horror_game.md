---
name: UE5 solo horror game project
description: Personal game-dev project (2026-08-19) reproducing the Darkphobia Games process in Unreal Engine 5; pipeline note lives in dotfiles, project folder in sandbox, Windows machine validated, next step is installing Unreal
metadata:
  type: project
---
The user is starting a solo game-dev project: a short first-person horror game in Unreal Engine 5, reproducing the process of Darkphobia Games (two-person studio, ex-TeaserPlay, one 1h game per year, photorealistic rendering built on marketplace assets and lighting work). The user is a novice in game development; this is outside their data science and biostatistics domain.

Two artifacts exist, neither auto-loaded: the dotfiles note is tracked in the dotfiles repo (last commit `047b5be`, 2026-09-20), and the project folder is not a git repo at all.

- `~/dotfiles/_meta/notes/ue5-horror-solo-pipeline.md`: full research note. Darkphobia's model, the hardware verdict on both machines, the toolchain with costs, Blueprint versus IDE, the eight-step project sequence, and the Windows hardware table measured 2026-09-20.
- `~/Documents/sandbox/ue5-le-relais/`: three companion documents, all written and gate-passed. `script.md` is the filled v1 (premise: isolated weather station Poste 7, register: invisible presence, eight beats, ten minutes, no creature model). `plan.md` is the floor plan in Unreal units (four rooms off one 1600 uu corridor, doors D3 and D4 facing each other to stage beat 6, walk speed set to 250). `assets.md` is the Fab shopping list by search term.

**Why:** the project spans several sessions, so nothing carries it forward on its own. The user's default working directory is `/home/julien`, from which neither artifact is discoverable.

**How to apply:**
- When the user raises the game project, read the dotfiles note first rather than re-researching Darkphobia or re-deriving the hardware verdict.
- Hardware settled: the Ubuntu laptop (Intel Iris Xe, 15 GiB RAM) cannot drive Lumen or Nanite and is fine only for writing and audio prep; the Windows machine (`ju-TP2`, RTX A3000 12 GB, under the 16 GB of Epic's reference workstation) is validated and passes all four thresholds measured 2026-09-20 (31.7 GiB RAM, 16 cores, 515 GiB free on `C:`). What remains is installing Unreal.
- No `.claude/PLAN.md` exists in the project folder, deliberately. Decision (2026-08-19): create it when Unreal is installed and steps are actually in flight, triggered by the first session opened from `~/Documents/sandbox/ue5-le-relais`. Until then it would duplicate the dotfiles note and rot unread. Do not re-propose it earlier.
- Fab licensing settled: the Standard license Personal tier and Professional tier grant the same rights, the tier tracks the buyer's revenue (100 k$ threshold over 12 months), not the use. Personal permits selling on Steam. Do not re-research this.
- Standing cheap action, independent of hardware: claim Fab Limited-Time Free every two weeks, claims are permanent.
- The engine work is Blueprint, not text code: no IDE involved, `.uasset` files are binary, and Positron and VSCode have no role. See [[user_profile]] for the user's usual stack, which does not apply here.
