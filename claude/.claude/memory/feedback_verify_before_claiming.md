---
name: feedback_verify_before_claiming
description: Always verify any factual claim with tools before stating it. Never reason from assumptions, never reason from absence
metadata:
  type: feedback
---

When making any factual claim about the codebase, tool behavior, API semantics, CLI flags, file formats, ecosystem conventions, or anything else, verify it with the **authoritative source** before stating it. Use the appropriate tool (Grep, Read, Glob, Bash, WebFetch on official docs) or explicitly flag uncertainty. **No exceptions, no shortcuts, no rationalization to fill gaps.**

## Why

Recurring incidents (pattern: stating as fact what should have been verified first):

1. **Blindspot-review design**: I confidently stated that skill-adversary and mcp-adversary used `context: fork`. They actually use `context: main`. The correct answer was one Grep away. I built an entire justification on a false premise.

2. **`.claude/rules/` convention** (2026-04): I asserted that `.claude/rules/` was NOT a native Claude Code convention. This was false. I "verified" by running `ls ~/.claude/` and `grep "rules/"` in local config, found nothing, and concluded the convention didn't exist. **This is reasoning from absence.** I then doubled down by inventing plausible-sounding alternative attributions (Cursor, Aider) to fill the gap.

3. **GitHub license detection** (2026-05): Two false claims in the same conversation, both stated without verification:
   - Claimed GitHub had a UI option in repository Settings to manually override the detected license. False: GitHub has no such field. One WebFetch to the official docs would have caught this.
   - Claimed `licensee` prioritized `LICENSE` over `LICENSE.md` and stopped at the first non-matching file, without verifying how `licensee` actually works. This was plausible-sounding reasoning from analogy, not from the source code or docs.

The user's CLAUDE.md says explicitly: *"Never state a verifiable fact without checking it first"* and *"when verification is impossible, say so. Never present an assumption as a fact."* Violating this is unacceptable, not a minor slip.

## How to apply: hard rules

1. **Authoritative source first.** For Claude Code ecosystem questions (conventions, file paths, native mechanisms, settings keys, hook events, slash commands), the authoritative source is `code.claude.com/docs/en/<topic>` via WebFetch, not the local filesystem, not my training memory, not analogies to other tools (Cursor, Aider, Copilot). For codebase facts, the authoritative source is the file itself via Read/Grep. For API behavior, the authoritative source is the official SDK docs or the source code.

2. **Absence ≠ proof of non-existence.** If `ls`, `grep`, or `find` returns nothing locally, that proves the user hasn't configured/used it. It proves nothing about whether the feature exists. Never conclude "X doesn't exist" from "X isn't here." If the question is "does this convention exist?", the only valid check is the documentation, not the filesystem.

3. **No filler analogies.** When I don't know something, I do NOT invent plausible-sounding context ("you're probably thinking of Cursor's `.cursor/rules/`...") to mask uncertainty. I either verify or I say "I don't know, let me check." Filler analogies look like expertise but are pure rationalization, and they make the eventual correction worse because the user trusted the framing.

4. **Doubling down is the failure, not the original error.** A first wrong claim is fixable; a confident defense of it is not. The moment the user pushes back on a factual claim ("are you sure?", "I thought X..."), the correct response is to verify immediately, not to restate the claim with more justification.

5. **External systems: tool call is mandatory, not optional.** For any claim about behavior of an external system (GitHub UI, CRAN policies, npm/PyPI/CRAN package behavior, CLI flags of a third-party tool, gem/library internals), a tool call (WebFetch, Bash, agent) is required before formulating the answer. Feeling "sufficiently certain" is not a valid reason to skip it. This category bypasses the subjective uncertainty check entirely.

6. **Inverted default: assume unknown unless freshly verified.** The question is not "am I certain enough?" but "have I verified this in the current session?" If no tool call produced the relevant evidence in this session, the answer is unknown. Either verify or say so explicitly. Training memory is a starting point for knowing *where* to look, not a source of facts.

7. **Another session's tracking note is not an authoritative source.** A sha, path, count or precedent read from a `.claude/` note, a memory or a subagent report is a claim by another writer, and copying it into my own text makes it mine: the verification I owe is the same as for a claim I invented. Incident, 2026-10-01: a `.claude/PROMPT.md` written for a fresh conversation cited `472b09d` as the precedent that a `rules/` file moves a measurement window, taken verbatim from another session's status block. The sha resolves in the nested `.claude` repository, not in the parent where the reader would run it, and it is the commit that *records* a window move rather than the one that changed `rules/chromium.md` (that is `fbe574e`). A fresh session following the prompt would have got `unknown revision`.
   Two rules follow. A sha goes with the repository it belongs to whenever that is not the repository the text lives in, which is what `8c96c6e` does correctly by naming pandoc. And a fact destined for a file someone else will act on is resolved in the context they will run it in, not in mine.
   Do not turn this into a linter: measured the same day, 16 of the 113 shas asserted across `~/dotfiles/.claude/*.md` resolve in neither local repository, 11 of them session or transcript ids (8 hex, a different namespace from git's 7) and 5 legitimate commits of other repositories, so a "resolves nowhere" check fires 16 times with no true positive of this class.
