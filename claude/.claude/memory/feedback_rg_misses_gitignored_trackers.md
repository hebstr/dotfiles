---
name: rg silently skips the Claude trackers when .claude/ is gitignored
description: A dependency grep with bare rg can return zero hits on .claude/ trackers because rg skips hidden AND gitignored paths; pass --hidden --no-ignore when the question is "what documents this symbol"
metadata:
  type: feedback
---

`rg` skips hidden paths and honours `.gitignore` by default, and `.claude/` is both hidden and, in several projects (`eds-avc` and `py-edscrib` among them, the latter through a `/.claude/` line in its `.gitignore`), gitignored. A bare `rg -l '<symbol>' .` looking for what depends on a change therefore returns only the tracked source files and reports the tracker set as clean, when `ANNOT-PKG.md`, `ANNOT.md`, `DEFERRED.md` and the project `CLAUDE.md` are exactly the files that describe the changed symbol.

**It recurred on 2026-07-30**, in `py-edscrib`, on the very grep CLAUDE.md makes mandatory after removing a public symbol: a bare `rg` over the repo reported zero residual references to `estimate_prefix` / `estimate_values` / `has_note_values` and read as a clean pass, while `.claude/CLAUDE.md` and `.claude/DEFERRED.md` were never opened. The re-run with `--hidden --no-ignore` cleared them too, but that was luck rather than method. **The post-structural-change greps in CLAUDE.md are exactly the case this memory covers**: run them in the `--hidden --no-ignore` form by default, since their whole purpose is finding what documents a symbol.

**Why:** the failure is a false negative that reads as a pass. During a `/workflow:sync` on `eds-avc` (2026-07-28) the first dependency grep returned 4 files, all of them already-modified sources, which would have concluded "no stale dependents"; `rg --hidden --no-ignore` on the same pattern returned the four `.claude/` trackers, which held two genuinely stale claims and a wrong line citation. The global preference for `rg` over `grep` says nothing about this, so the default silently narrows the search.

**How to apply:** when the question is "what else references this", not "where is this code", run `rg --hidden --no-ignore -g '!.git'` and add `-g '!.venv'`, `-g '!node_modules'`, `-g '!rv/'` or the local vendored-dependency equivalents, since `--no-ignore` also unmasks installed packages and produces long noise tails. Reserve the bare form for source-code search. Same reasoning applies to `fdfind` for file discovery. Related: [[feedback_personal_working_files]] applies on top, though only to what follows the grep: the scratchpads are read like any other hit, and never rewritten.
