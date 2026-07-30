---
name: YAML gate deferred, research already done
description: Decision (2026-07-30) to defer the dotfiles YAML gate; the /workflow:reco research is written up in _meta/notes/yaml-gate-reco.md, so do not redo it
metadata:
  type: project
---

The `~/dotfiles` YAML gate was researched on 2026-07-30 via `/workflow:reco`, then deferred by the user.
Nothing was installed, no config written, no hook added.
The full write-up lives in `~/dotfiles/_meta/notes/yaml-gate-reco.md`; read it before touching this topic again.

Conclusions that survive without reopening the research:

- **Formatter is prettier, not yamlfmt.** yamlfmt converts `|` block scalars to escaped strings (upstream issue #185, open, labelled `yaml_v3_problem`), and `run: |` blocks are exactly the content of the four repos with GitHub Actions workflows. prettier is already pinned in `~/.local/share/css-gate/` and already tracked by `sys-update`'s `css-toolchain` module, so it adds no maintenance surface. See [[project_qmd_format_hook]] for the neighbouring formatter split.
- **Linter is yamllint via `uv tool install`**, and a blocker has to be cleared first: `/usr/local/bin/yamllint` is a symlink to the npm `yaml-lint` 1.7.0 package, which has no style rules at all. The real yamllint is not installed.
- **`actionlint` on `.github/workflows/` only**; that is the one class with no existing coverage.
- **No schema validation on Quarto configs.** SchemaStore has zero Quarto and zero pkgdown entries (catalogue inspected directly, 1402 schemas), and `rules/quarto.md` already forces a full `quarto render` on any `_quarto.yml` edit, which is stricter than a generic schema.

**Why:** the research cost two parallel web agents and a round of URL verification; the note captures the reasoning that overturned the obvious choice (yamlfmt), which is not recoverable from the tool docs alone.

**How to apply:** if the YAML gate comes back up, read the note first and start at its "Suite proposée" section (install yamllint, measure violations on existing files, only then write `rules/yaml.md`). Do not re-run `/workflow:reco` on this topic.
