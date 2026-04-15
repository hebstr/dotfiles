# Context: mcp-adversary

## Goal

Adversarial review skill for MCP servers, complementary to `skill-adversary` (which targets Claude Code skills).

## Prior art (research conducted 2026-03-30)

### Security-focused tools (exist, different scope)

- **mcp-scan** (Snyk/Invariant Labs, ~2k stars) — scans tool descriptions for prompt injection, tool poisoning, rug-pull attacks. Security only.
- **Pipelock** (~150 stars) — agent firewall. DLP, injection scanning, SHA-256 fingerprinting. Security only.
- **mcpserver-audit** (Cloud Security Alliance, ~14 stars) — server source code security audit. Early stage.
- **APIsec MCP Audit** — configuration hygiene, secrets exposure. Niche.
- **SlowMist MCP Security Checklist** — 62-point manual checklist. Guide, not tool.
- **OWASP MCP Top 10** — classifies tool poisoning as MCP03:2025.

### Quality/usability review tools (the gap)

**Nothing exists** that reviews:
- Tool description quality (clarity, completeness, LLM-discoverability)
- Inter-tool discrimination (can the LLM pick the right tool among N similar ones?)
- Schema hygiene (types too broad, missing enums, ambiguous defaults)
- Semantic drift (description vs code behavior)
- Workflow dependencies (implicit tool ordering)

mcp-adversary fills this gap.

## Architecture decisions

### 3 agents (not 2)

skill-adversary uses 2 agents (trigger-attacker + instruction-critic). MCP servers have 3 non-overlapping audit surfaces:

1. **What the LLM sees** (tool descriptions) → tool-surface-attacker
2. **What the LLM sends** (parameter schemas) → schema-critic
3. **What the code does** (implementation) → contract-auditor

### FastMCP only (V1)

The tool metadata extraction logic is framework-specific. FastMCP (Python) is the only supported framework in V1. TypeScript SDK support is a clean incremental add for V2.

### Independent of mcp-scan

No runtime dependency on mcp-scan. Report footer mentions it for complementary security scanning. Reason: mcp-scan may not be installed, and coupling adds fragility without value (mcp-adversary's scope is usability/correctness, not security).

### Contract-auditor reads full source

Full source with focus constraint in the prompt. Reason: resource lifecycle and workflow dependency issues live in helpers, not in tool functions. The agent is instructed to start from tools and follow call chains, not audit everything.

## Bias mitigation (same as skill-adversary)

1. Context isolation — agents receive only extracted metadata/code
2. Persona forcing — 4 user personas for discoverability testing
3. Cross-model critique — Opus ↔ Sonnet

## V2 ideas

- TypeScript SDK support
- Live tool invocation testing (call tools with edge-case inputs, verify responses)
- Integration with skill-adversary for reviewing skills that consume MCP tools
- Output format validation (verify MCP response payloads match expected structure)
