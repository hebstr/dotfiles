---
name: Review scope for third-party / vendored content
description: CLAUDE.md prose style rules (em-dashes, AI tics, etc.) target Claude's own output, not third-party skill descriptions, plugin docs, or forked content
type: feedback
---

When reviewing a Claude Code config audit or a skill/plugin directory, do not flag style violations (em-dashes, AI-slop patterns, marketing tone) in content written by upstream authors: frontmatter `context: fork`, plugin descriptions from `~/.claude/plugins/`, or any third-party material read as input by Claude.

**Why:** the user's CLAUDE.md prose-hygiene rules ("Avoid em dashes", "No ritual openers", etc.) are scoped to **prose Claude generates**. They are about output quality, not input filtering. Rewriting third-party text creates maintenance debt (forks diverge from upstream on every re-sync) for zero functional gain. Flagged once during the 2026-05-10 audit on `bookmarks-manager/SKILL.md` (a `context: fork` skill with 15 em-dashes); rejected because the rule was misapplied.

**How to apply:**
- A skill with `context: fork` in its frontmatter is vendored: its description is upstream's responsibility.
- Plugins under `~/.claude/plugins/cache/` are read-only mirrors of remote sources.
- Style rules apply to: code Claude writes, doc/PR/commit prose Claude drafts, replies to the user, fix descriptions in walkthroughs.
- Style rules do NOT apply to: third-party SKILL.md descriptions, vendored plugin docs, MCP server tool descriptions written by external authors.
- A genuine fix in third-party content (security flaw, broken instruction, factual error) is still in scope. Only the cosmetic style category is off-limits.
