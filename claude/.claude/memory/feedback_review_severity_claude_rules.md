---
name: Review calibration for .claude/rules/ files
description: When auditing path-scoped rule files in .claude/rules/, do not propose relocating glob-scoped R/Python idioms back into CLAUDE.md, deduplication of structurally-local boilerplate, per-file version traces, mixing review-calibration into writing rules, or removal of alternate tools because of partial overlap with the main pipeline tool
metadata:
  type: feedback
---

When reviewing or auditing `.claude/rules/*.md` files (path-scoped rule files loaded by glob via `paths:` frontmatter), do **not** propose any of the following:

1. **Flagging the R/Python idioms in rule files as CLAUDE.md duplication, or proposing to move them back.** CLAUDE.md is loaded globally on every conversation; rule files are loaded only when their glob matches. The idiomatic conventions (pipe `|>`, `here::here()`, polars-over-pandas, etc.) now live canonically in `rules/r.md` and `rules/python.md`, removed from CLAUDE.md so the global file stays lean and the idioms load only when an R/Python edit matches the glob. They no longer duplicate CLAUDE.md. Do not propose relocating them back into CLAUDE.md or deleting them as redundant.

2. **Deduplicating boilerplate phrasing across rule files.** Patterns like "Mandatory pipeline after every create/edit" appear in multiple files with slight phrasing variation. This is intentional locality: each rule file is self-contained by design. A reader (Claude) sees one file at a time, not three. Normalization buys nothing.

3. **Per-file version-trace headers.** Lines like `# Verified against ruff X.Y / jarl X.Y, 2026-05` rot fast and lie within a quarter. The global CLAUDE.md rule "verify against current docs before writing" already covers this concern as behavior, not annotation.

4. **Mixing review-calibration content into writing-rule files.** Review tolerance and severity calibration belong in `feedback_*.md` memories (e.g., `feedback_review_severity_shell_installers.md`). The `rules/*.md` files describe how to write/edit code, not how to review it. The two scopes are orthogonal; mixing them dilutes both.

5. **Proposing removal of an alternate tool because it partially overlaps with the main pipeline tool.** Rule files often document a primary tool plus auxiliary commands (e.g. `python -m py_compile` next to `ruff check`; `--check` next to `ruff format`). Auxiliary tools in their own section signal "use when X, not as part of the mandatory pipeline": they are intentional optionality, not redundancy. Suggestions like "ruff check already does syntax parsing, remove py_compile" treat documented alternatives as bloat and narrow the toolchain for no gain.

**Why:** the 2026-05-10 walkthrough on `claude/.claude/rules/` produced 14 findings, 6 of which (43%) were false positives matching exactly the first four patterns. The 2026-05-16 walkthrough on `rules/python.md` added pattern 5: a Suggestion to remove `python -m py_compile` because `ruff check` covers syntax parsing. These patterns sound disciplined but produce bloat, duplication, or rotten lines.

**How to apply:** in any future audit of `.claude/rules/`, skip these five categories of suggestion immediately. They are recurring false positives, not actionable findings. Real findings still apply: factual errors in commands/flags, content stale relative to checked-in configs, scope mismatches (e.g., IDE setup polluting per-edit rules).
