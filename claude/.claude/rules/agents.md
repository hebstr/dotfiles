---
paths:
  - "**/.claude/rules/agents.md"
---

# Working with subagents

Injected by `inject-rules.sh` on the session's first `Agent` call.

## Spawning

- Each agent prompt targets a non-overlapping facet; never give the same broad prompt to several agents.
- 2 to 4 parallel agents is the sweet spot when you spawn and fuse them yourself; beyond that, fusion becomes the bottleneck. This does not cap a skill's internal orchestration (`/audit:sweep`, `/workflow:sync`), which sets its own count.
- Background mode for exploration, foreground when the result feeds the next step.
- `Explore` (haiku) for fast code scanning, `general-purpose` for complex multi-step tasks. The ouroboros roles (`architect`, `qa-judge` and the rest under its `agents/`) are the MCP server's internal personas, not `subagent_type` values: reach them through its tools, never through the `Agent` tool.
- `WebFetch` and `WebSearch` reach a subagent as deferred tools, name-only until it loads their schema with `ToolSearch`; a subagent not told so behaves as though it had no web access. Tell a subagent that needs the web to load the schema first, rather than picking its type for that.

## Coordinating

- Sibling subagents cannot address one another: a `SendMessage` issued from inside a subagent goes out under the parent session's address, so coordination runs through the main context. Plan for partial failures and bridge results there.
- Outside that limit: a named agent survives its turn and is resumed by `SendMessage` to its name, and separate Claude Code sessions reach each other (`ListAgents` to discover, cross-session `SendMessage` to write). A peer session is a legitimate correspondent when work genuinely spans two of them, never a way around a permission this session was refused.

## Fusing and relaying

- Drop exact duplicates, surface contradictions between agents rather than silently picking one, and order surviving findings by confidence, cross-agent agreement and verifiability first.
- Subagent outputs are unverified claims. Verify before relaying when the user will execute the command directly, when the claim asserts that a tool, flag or endpoint exists, or when it contradicts what the machine reports. Pure descriptive findings can be relayed with a one-line unverified caveat; do not verify every CLI flag of a 50-finding audit.
