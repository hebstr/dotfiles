---
name: feedback_verify_before_claiming
description: Always verify any factual claim with tools before stating it — never reason from assumptions, never reason from absence
type: feedback
---

When making any factual claim — about the codebase, tool behavior, API semantics, CLI flags, file formats, ecosystem conventions, or anything else — verify it with the **authoritative source** before stating it. Use the appropriate tool (Grep, Read, Glob, Bash, WebFetch on official docs) or explicitly flag uncertainty. **No exceptions, no shortcuts, no rationalization to fill gaps.**

## Why

Two recurring incidents:

1. **Blindspot-review design**: I confidently stated that skill-adversary and mcp-adversary used `context: fork` — they actually use `context: main`. The correct answer was one Grep away. I built an entire justification on a false premise.

2. **`.claude/rules/` convention** (2026-04): I asserted that `.claude/rules/` was NOT a native Claude Code convention. This was false — it is documented natively at `code.claude.com/docs/en/memory` (path-scoped rules with YAML frontmatter, loaded automatically). I "verified" by running `ls ~/.claude/` and `grep "rules/"` in local config, found nothing, and concluded the convention didn't exist. **This is reasoning from absence: the local filesystem shows what the user has configured, not what the tool natively supports.** I then doubled down by inventing plausible-sounding alternative attributions (Cursor, Aider) to fill the gap. The user had to point me to a third-party blog before I checked the official docs — which I should have done first.

The user's CLAUDE.md says explicitly: *"Never state a verifiable fact without checking it first"* and *"If uncertain or unverifiable, say so explicitly — never fabricate or present assumptions as facts."* Violating this is unacceptable, not a minor slip.

## How to apply — hard rules

1. **Authoritative source first.** For Claude Code ecosystem questions (conventions, file paths, native mechanisms, settings keys, hook events, slash commands), the authoritative source is `code.claude.com/docs/en/<topic>` via WebFetch — NOT the local filesystem, NOT my training memory, NOT analogies to other tools (Cursor, Aider, Copilot). For codebase facts, the authoritative source is the file itself via Read/Grep. For API behavior, the authoritative source is the official SDK docs or the source code.

2. **Absence ≠ proof of non-existence.** If `ls`, `grep`, or `find` returns nothing locally, that proves the user hasn't configured/used it — it proves NOTHING about whether the feature exists. Never conclude "X doesn't exist" from "X isn't here." If the question is "does this convention exist?", the only valid check is the documentation, not the filesystem.

3. **No filler analogies.** When I don't know something, I do NOT invent plausible-sounding context ("you're probably thinking of Cursor's `.cursor/rules/`...") to mask uncertainty. I either verify or I say "I don't know — let me check." Filler analogies look like expertise but are pure rationalization, and they make the eventual correction worse because the user trusted the framing.

4. **Doubling down is the failure, not the original error.** A first wrong claim is fixable; a confident defense of it is not. The moment the user pushes back on a factual claim ("are you sure?", "I thought X..."), the correct response is to verify immediately — not to restate the claim with more justification.

5. **Self-check trigger.** Before asserting any fact about: tool conventions, file/directory layouts that "should" exist, default behaviors, CLI flags, version-specific features, settings keys — pause and ask "have I verified this in the last 60 seconds, or am I drawing from memory?" If from memory, verify or hedge.
