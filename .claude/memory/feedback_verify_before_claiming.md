---
name: feedback_verify_before_claiming
description: Always verify any factual claim with tools before stating it — never reason from assumptions
type: feedback
---

When making any factual claim — about the codebase, tool behavior, API semantics, CLI flags, file formats, or anything else — verify it before stating it. Use the appropriate tool (Grep, Read, Glob, Bash, WebSearch) or explicitly flag uncertainty.

**Why:** During blindspot-review design, I confidently stated that skill-adversary and mcp-adversary used `context: fork` — they actually use `context: main`. The correct answer was one Grep away. I built an entire justification on a false premise.

**How to apply:** Before asserting any verifiable fact, verify it first. If a tool can check it, use the tool. If no tool can check it, state the uncertainty explicitly. Never present an assumption as a fact.
