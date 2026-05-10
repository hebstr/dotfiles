---
name: Review calibration for .claude/rules/ files
description: When auditing path-scoped rule files in .claude/rules/, do not propose duplication of CLAUDE.md content, deduplication of structurally-local boilerplate, per-file version traces, or mixing review-calibration into writing rules
type: feedback
---

When reviewing or auditing `.claude/rules/*.md` files (path-scoped rule files loaded by glob via `paths:` frontmatter), do **not** propose any of the following:

1. **Duplicating CLAUDE.md style/convention rules into rule files.** CLAUDE.md is loaded globally on every conversation; rule files are loaded only when their glob matches. Adding R or Python idiomatic conventions (pipe `|>`, `here::here()`, polars-over-pandas, etc.) to `rules/r.md` or `rules/python.md` creates a sync burden for zero signal gain (Claude already has CLAUDE.md in context).

2. **Deduplicating boilerplate phrasing across rule files.** Patterns like "Mandatory pipeline after every create/edit" appear in multiple files with slight phrasing variation. This is intentional locality: each rule file is self-contained by design. A reader (Claude) sees one file at a time, not three. Normalization buys nothing.

3. **Per-file version-trace headers.** Lines like `# Verified against ruff X.Y / jarl X.Y — 2026-05` rot fast and lie within a quarter. The global CLAUDE.md rule "verify against current docs before writing" already covers this concern as behavior, not annotation.

4. **Mixing review-calibration content into writing-rule files.** Review tolerance and severity calibration belong in `feedback_*.md` memories (e.g., `feedback_review_severity_shell_installers.md`). The `rules/*.md` files describe how to write/edit code, not how to review it. The two scopes are orthogonal; mixing them dilutes both.

**Why:** the 2026-05-10 walkthrough on `claude/.claude/rules/` produced 14 findings, 6 of which (43%) were false positives matching exactly these four patterns. They sound disciplined but produce bloat, duplication, or rotten lines.

**How to apply:** in any future audit of `.claude/rules/`, skip these four categories of suggestion immediately. They are recurring false positives, not actionable findings. Real findings still apply: factual errors in commands/flags, content stale relative to checked-in configs, scope mismatches (e.g., IDE setup polluting per-edit rules).
