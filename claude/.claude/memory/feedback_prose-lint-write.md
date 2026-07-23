---
name: feedback_prose-lint-write
description: prose-lint scope (user-facing only, typographic vs rhetorical em/en dash), when to use /workflow:write, and what to never touch
metadata:
  type: feedback
---

## Scope: user-facing prose only

Prose hygiene rules (anti-AI-slop, em/en dash) apply only to text **rendered to a human user**: READMEs, public docs, SKILL.md/CONTEXT.md content shipped with skills, marketplace-distributed markdown, articles, release notes. They do **not** apply to transient Claude working notes: everything under a project's `.claude/` directory (PLAN.md, DEFERRED.md, DESIGN-*.md, REVIEW-*.md, *-context.md, the project `CLAUDE.md`, etc.), `~/.claude/memory/**`, and any working note Claude reads but no user does. The **global** instruction files `~/.claude/CLAUDE.md` and `rules/*.md` are the exception and are NOT exempt: they get `prose-lint` per the CLAUDE.md gate (the user enforces the dash rules on them, and CLAUDE.md content audits reject em dashes in its prose). The global config is told apart from a project's `.claude/` because its stow-managed files resolve into `~/dotfiles/claude/.claude/`; the `format-on-edit` hook keys on that resolved path (`$REAL`) to decide whether to run `prose-lint`, while the portable `prose-lint` tool stays generic and self-skips only `.claude/memory/` and the working-file basenames (decided 2026-07-21). Soft-wraps fall outside this scope: `panache` owns them from the same hook under a different skip set, and it does skip `CLAUDE.md` and `rules/*.md`, which keep their one-sentence-per-line layout by hand while still getting `prose-lint`. See [[project_qmd_format_hook]].

**Why:** the AI-tell rule is about audience perception. Internal notes are read by Claude only, where the rules' purpose (avoiding the AI register tells when humans read the output) does not apply. Enforcing them on working notes is busywork.

**Enforcement via gitignore + prek (verified 2026-05-20):**
- When `.claude/` is gitignored (default in this project), `prek` (pre-commit runner) skips it even with `--all-files`. Empirically verified: an em-dash inside `.claude/sweep-context.md` did not trigger the prose-lint hook. So a redundant `exclude = '^\.claude/'` in `prek.toml` is unnecessary when the directory is already gitignored.
- The hard guarantee is `.gitignore`; the pre-commit skip is a consequence, not an independent layer.

**How to apply:**
- Before scanning a directory with prose-lint or /workflow:write, skip a project's `.claude/`, `~/.claude/memory/`, or another working-notes location. Exception: the global config `~/.claude/CLAUDE.md` and `~/.claude/rules/*.md` (stowed under `~/dotfiles/claude/.claude/`) stays checked.
- When in doubt: "does a human other than the author read this?" If no, it's a working note.
- If you find working-note content in a user-facing path (session logs inside a SKILL.md sibling, dated test runs in a CONTEXT.md), trim or migrate to `.claude/` before applying prose hygiene to the surrounding files. Concrete precedent: `audit/sweep/CONTEXT.md`, `audit/blindspot/CONTEXT.md`, `audit/walkthrough/DEFERRED.md` migrated to `.claude/` on 2026-05-20.

## Typographic vs rhetorical em/en dash

The `prose-lint` AI-tell rule targets em dashes used as **rhetorical punctuation in continuous prose** (the AI-tic of `"Result — devastating"`, `"Not X — but Y"`). It does NOT target em/en dashes used as **typographic separators**: column placeholders (`| — |` meaning "no value"), label/description separators in table cells (`| /flag — what it does |`), section-header decoration (`### Section — Subtitle`), or numeric ranges (`2–4`, `v2.1–v2.2`, `5–15 %`, `pages 12–18`).

**Why:** these are two semantically different uses of the same glyph. Conflating them produces ugly false fixes (`| — |` → `| n/a |`, `### X — Y` → `### X : Y`) that degrade typography without removing any AI tell. Concrete incident (2026-05-20): a /workflow:write pass on this repo replaced ~15 typographic em dashes in table cells and section headers with `n/a`/`none`/colons, triggering an explicit "STOP" from the user.

**How the linter encodes this** (as of 2026-05-20, in `~/dotfiles/bin/.local/bin/prose-lint`):
- Lines starting with `|` (table rows) or `#` (markdown headers) are exempt from em/en dash checks.
- En-dashes between alphanumeric tokens (`[A-Za-z0-9.]+–[A-Za-z0-9.]+`) are stripped before the check, so numeric ranges and version ranges pass everywhere, including bullets and prose.
- Verbatim-rule lines that need to quote forbidden punctuation (e.g. `Pas de tiret cadratin (—) ...` in `write-fr-*.md`) still need the `<!-- prose-lint:ignore -->` marker, because the em-dash is inside parens between non-alphanumerics, in a bullet line.

**How to apply:**
- When prose-lint flags em/en dash violations, fix only the ones that are actual rhetorical punctuation in continuous prose. Convert to comma, semicolon, colon, parens, or restructure.
- Never "fix" a typographic em dash by replacing the glyph with a word (`n/a`, `none`, `for`, etc.) or converting a `### X — Y` header to `### X : Y`. If the linter flags such cases, the linter rule is wrong and should be tightened at the source.
- The source of prose-lint is at `~/dotfiles/bin/.local/bin/prose-lint`. Stow-managed; edit the dotfiles path, never the `~/.local/bin/` symlink.

## When to invoke /workflow:write

Invoke `/workflow:write` to fix prose-lint violations only when the replacement requires judgment (e.g. choosing between colon, comma, parentheses, or restructure for a genuine prose em-dash). Do not invoke it as a reflex on every prose-lint output, and especially not on bulk runs across many files: the cost of an over-aggressive pass (see incident above) is higher than the cost of leaving a few rhetorical em dashes in place.

**Why:** mechanical violations with a single obvious fix (an em-dash that can only be a colon) don't need the reference. Bulk passes amplify any misclassification across the whole repo.

**How to apply:** before invoking `/workflow:write` on a prose-lint finding, ask whether the replacement choice is unambiguous AND whether the finding is actually rhetorical (not typographic per above). If yes to both, fix directly. If no on judgment, invoke `/workflow:write`. If no on rhetorical classification, fix the linter at the source.
