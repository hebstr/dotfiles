---
name: Verify agent/subagent outputs before relaying
description: Subagent outputs (commands, URLs, syntax) are unverified claims — treat them like web search results, not facts
type: feedback
---

Never relay commands, URLs, API syntax, or CLI flags from subagent outputs without verifying they exist first.

**Why:** In a full-review skill session, two fabricated commands (`/install-skill`, `/reload-plugins`) were presented as facts because the `claude-code-guide` subagent produced plausible-sounding but non-existent commands, and the main context relayed them verbatim. This violated the existing CLAUDE.md rule "Never state a verifiable fact without checking it first."

**How to apply:** Subagent outputs are untrusted sources — same trust level as web search results. Before presenting any command, URL, or specific syntax from a subagent to the user: verify it exists (run the command with --help, check the filesystem, or search docs). If verification is not possible, explicitly state uncertainty ("I'm not sure this command exists — verify before running").
