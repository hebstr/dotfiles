---
name: typst skill adopted as the Typst knowledge base
description: lucifer1004/claude-skill-typst evaluated and adopted 2026-10-17 under the agents convention; the three grounds first raised against it and what resolved each, do not redo the pass
metadata:
  type: project
---

`lucifer1004/claude-skill-typst` (MIT, 132 stars, a `skills/typst/` subtree of 14 reference files, 4 stdlib-only Python scripts and 9.4 MB of JSON API indexes) was evaluated on 2026-10-17 and adopted under the convention of `.claude/DESIGN-AGENT-SKILLS.md` § "Third-party skills go through the `agents` package and its lock".
The verdict rests on the upstream tree read through `gh api`, a bare clone measured and deleted in the session scratchpad, and probes run against the `typst` 0.15.1 already installed.
Full pass, protocol and numbers in `~/dotfiles/_meta/notes/typst-skill-reco.md`.

The pass first concluded against adoption on three grounds, and each is recorded because re-deriving them costs a session:

- **Zero Quarto coverage.** The string `quarto` appears nowhere in its reference files, `SKILL.md`, agents or examples. Ruled out of the question by the user: the skill targets `.typ`, and a knowledge base is not judged on one project's current state.
- **The commit gate.** `prek.toml` carries `check-added-large-files --maxkb=500` with no exclusion, unlike the eight other hooks that exempt `^agents/`, and 9 of the 10 files in `skills/typst/data` exceed 500 KB. Accepted as a cost: the exclusion lifts it, at the price of every future vendored skill escaping the large-file guard.
- **Local edits erased weekly.** Asserted without checking, and wrong. It rested on `SKILL.md` invoking `python3 scripts/search-api.py` by a relative path. Claude Code prefixes every skill load with `Base directory for this skill: <path>`, observed on `poc`, a symlinked directory under `~/.claude/skills/` of exactly the shape the installer creates, so no local edit is needed and none is lost to the weekly reinstall. The constraint itself holds: `skills update -g` replaces the directory wholesale, so the 9.4 MB is taken whole and no local prune of the 5.9 MB of unusable indexes survives.

What the corpus measurement established, which bounds the bet rather than blocking it: the hand-authored `.typ` surface is `~/admin/pro-cv/cv-body.typ` (224 lines, active) plus `hebstr-template`, the user's own 8-file Typst template suite in `claude-code-litrev`, untouched since 2026-04-05. `quarto-hebstr-doc` dropped its Typst output format in commit `34e7003` on 2026-09-29, and `quarto-hebstr-book`, `quarto-hebstr-slide` and `quarto-cell-options` carry zero `.typ`.

Two measurements worth keeping. The content is accurate where checked: 11 of 12 sampled claims of `migration.md` and `debug.md` verified against the installed 0.15.1, the misses being `query(heading.within(<appendix>))`, which errors where `selector(heading).within(...)` compiles, and a symbol table telling the reader to paste a literal ⊗ when `sym.times.o` returns it (the `.o` modifier is general: `sym.plus.o` is ⊕). And the weight is about seven times smaller than the checkout suggests: 9.4 MB on disk costs 1.4 MB as git objects, four upstream weeks of drift add 0.6 MB, and the project's whole nine-month history packs to 4.44 MiB against a dotfiles pack of 2.89 MiB.

Installed and smoke-tested the same day from a project working directory: the scripts answer, `agent-skills-update` reports both lock entries current, and Claude Code discovered the skill without a restart. `check-added-large-files` took `exclude = '^agents/'` in `prek.toml`; without it nine of the ten `data/*.json` are refused once staged, and `prek run --all-files` is green on an unstaged tree because the hook reads `git diff --staged --diff-filter=A`.

Usage warning: the indexes and the prose disagree and the index is right. `search-api.py --name sym.times.o -v` returns ⊗ against a `debug.md` that denies the name exists. Data beats a reference file; `typst eval` beats the data.

Revisit trigger, for dropping it rather than reopening it: a second content defect found in use after the one in `debug.md`, with PR #3 still unmerged, which would establish that the prose half is unmaintained rather than slow. The data indexes are bot-maintained and stay current; the last human commit is 2026-09-03.

**Why:** The verdict turned twice, first on harness facts invisible from the repository page and then on a claim about skill loading that the pass had asserted instead of checking, so re-opening it without those three resolutions would repeat a full session and could land on the wrong answer again.
**How to apply:** Treat the skill as the Typst knowledge base for standalone `.typ`, and keep `typst eval '<expr>'` against the installed compiler as the authority when the two disagree: the index is a copy of it. The Quarto and Typst boundary is outside the skill and stays held by `rules/typst.md` § "Scope" and by `~/admin/pro-cv/.claude/DESIGN-TYPST-LAYOUT.md`. One correction came out of the pass and is applied: `rules/typst.md` now records that the snap sees non-hidden paths under `$HOME` only ([[user_quarto_typst_only]], [[project_ordo_typst_template]]).
