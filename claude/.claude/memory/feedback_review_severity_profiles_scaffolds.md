---
name: Review calibration for _meta/profiles/ scaffolds
description: When auditing the reusable config templates in ~/dotfiles/_meta/profiles/, do not flag repo-specific excludes, partial language coverage, or values a sibling config already owns
metadata:
  type: feedback
---

When reviewing or auditing the reusable config templates under `~/dotfiles/_meta/profiles/` (`prek.toml`, `panache.toml`, `air.toml`, `ruff.toml`, `.vscode/`, ...), do **not** propose any of the following.

1. **Flagging a repo-specific exclude in the scaffold as a footgun for adopting projects.** Example: `exclude = '^bash/'` on the `shellcheck` and `shfmt` hooks, which names a stow package that exists only in the dotfiles repo. The scaffold is adapted per project, never copied verbatim: `.claude/PLAN-LUA.md:13` records the one real adoption (`quarto-hebstr-doc`) taking an adapted subset and dropping the Python and shell hooks entirely, so the exclude never reached it. See also [[feedback_review_severity_claude_rules]] pattern 6, which already rules the same `^bash/` scoping deliberate.

2. **Flagging a scaffold as incomplete because it covers fewer languages than a sibling scaffold.** Example: `.vscode/extensions.json` recommending only `Posit.air-vscode` and `jolars.panache` while `prek.toml` runs ruff, jarl, typstyle and stylua. The coherence test that matters for a distributable pair is internal: `extensions.json` must recommend exactly what `settings.json` configures. Recommending an extension the scaffold does not wire up is strictly worse, and each `rules/*.md` already owns its own Positron section.

3. **Proposing to duplicate into editor settings a value a formatter config already owns.** Example: adding `editor.tabSize: 2` to the `[r]` block because the user's live Positron profile has it. `_meta/profiles/air.toml` sets `indent-width = 2`, and format-on-save normalizes anyway, so the key would only affect pre-save typing while creating a second place to drift. `rules/lua.md` designs against exactly this ("single `stylua.toml`, no three-place drift"). A committed `.vscode/settings.json` also applies to every contributor, so personal typing preferences do not belong in it even when the live profile carries them.

**Why:** the 2026-07-23 `/workflow:sync` walkthrough over the panache 3.0.0 adoption produced 12 findings, 5 rejected. Three of the five were these patterns, all sharing one root error: treating a template as a drop-in artifact that must be complete and self-sufficient, when it is a starting point adapted per project and deliberately narrow.

**How to apply:** in any future audit touching `_meta/profiles/`, drop these three categories before reporting. Real findings still apply: pins that trail the live root config on a hook both files carry, a hook whose `files`/`exclude` regex cannot match what it claims to cover, and internal incoherence between two files of the same scaffold pair.

Related: [[feedback_review_severity_claude_rules]] (rule files), [[feedback_review_severity_claude_config]] (harness config artifacts), [[project_qmd_format_hook]] (the panache config the scaffold ships).
