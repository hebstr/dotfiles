---
name: Explore subagent has no WebFetch/WebSearch
description: When a task needs web access, do not use the `Explore` subagent — it cannot reach WebFetch/WebSearch despite the "All tools except…" wording. Use `general-purpose` instead.
type: feedback
originSessionId: 0f4d50f9-a24c-4976-8f00-747cbd48d0dd
---
The `Explore` subagent is described as "All tools except Agent, ExitPlanMode, Edit, Write, NotebookEdit", which suggests it has WebFetch and WebSearch — it does not in practice. Confirmed 2026-04-25 when an Explore agent tasked with scanning emilhvitfeldt.com replied "Je ne peux pas accéder à WebFetch ou WebSearch directement". A second Explore run on a similar task produced a structured-looking report with hallucinated details (suspect dates, fabricated YAML).

**Why:** the user lost time relaunching the same scan in `general-purpose`, and the hallucinated Explore output is dangerous because it looks plausible at first glance.

**How to apply:** when delegating a task that requires fetching web pages, GitHub READMEs, or running a web search, default to `general-purpose` (which has `*` tools). Reserve `Explore` strictly for local code search where its haiku speed matters. If an Explore agent ever returns content that should have required web access, treat the output as suspect and rerun in `general-purpose` rather than salvaging it.
