---
name: Review calibration for ~/.claude harness config
description: When auditing ~/.claude config artifacts (settings.json, hooks/*.sh, format-on-edit), do not flag intentional minimalism as defects requiring defensive expansion
type: feedback
---

When reviewing or auditing the user's personal Claude Code harness config (`~/.claude/settings.json`, `~/.claude/hooks/*.sh`, `~/.claude/CLAUDE.md`, etc., or their real paths under `~/dotfiles/claude/...`), do **not** propose any of the following:

1. **Expanding the scope of `[[ "$REAL" == "$PWD"/* ]]` style guards in PostToolUse hooks.** The PWD + extension gate (e.g. in `format-on-edit.sh`) is the deliberate scoping primitive. Suggestions like "add a `~/dotfiles | ~/Documents/pro/` allowlist" introduce brittle coupling to a specific repo layout for rare edge cases (Claude editing third-party plugin sources, vendored shell scripts under $HOME). The user almost never edits those directly.

2. **Applying the "prefer `rg` over `grep`" rule to user-authored hook scripts.** The CLAUDE.md rule targets Claude's *interactive Bash searches*, not Claude-authored shell scripts that ship as part of the harness (e.g. `inject-project-context.sh`). Those hooks parse 1-3 single-token fields from small known-format files (DESCRIPTION, _quarto.yml, pyproject.toml). `grep | cut -d' ' -f2` is POSIX-portable and has nothing to gain from `rg`.

3. **Proposing message-aware desktop notifications when the existing hook emits a generic string.** Single-session workflows do not need per-notification context — the generic "Claude needs your attention" is enough as a desktop signal; tabbing back to the terminal shows the actual question. Only flag this if the user has stated they run multiple parallel Claude sessions and need to distinguish them.

4. **Expanding the `WebFetch(domain:...)` allow list with marketing or console domains** (e.g. `anthropic.com`, `console.anthropic.com`) when only the doc subdomain is listed (`docs.anthropic.com`). The narrow allow list is deliberate: a WebFetch confirmation prompt on the rare case the user needs the marketing site is preferable to expanding the surface for prompt-injection-driven exfil.

**Why:** the 2026-05-13 `/health` audit on `~/.claude` produced 5 findings; 4 (80%) were rejected as overstated. The pattern: treating intentional minimalism (narrow scope, plain tools, generic outputs) as defects requiring defensive expansion, often importing Claude's own behavioral rules into user-authored config code where they don't apply.

**How to apply:** in any future `/health`, code-review, or audit pass over `~/.claude/` config artifacts, skip these four categories of suggestion immediately. They are recurring false positives. Real findings still apply: leaked credentials in committed settings, hooks that fail open and corrupt files, scope guards that demonstrably don't gate what they claim to gate, and structural drift between CLAUDE.md and `rules/*.md` content.

Related: [[feedback_review_severity_claude_rules]] covers `.claude/rules/*.md` content; this memory covers harness config artifacts (settings, hooks, CLAUDE.md itself).
