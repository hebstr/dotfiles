---
name: feedback_review_severity_litrev_mcp
description: "Calibrate adversarial review severity for the litrev-mcp MCP server: five established design choices recurring reviewers misread as defects."
metadata:
  type: feedback
---

Adversarial reviewers (skill-adversary, mcp-adversary, cross-model judges) tend to misread five established design choices in `mcp/src/litrev_mcp/`. Do not re-litigate them on every audit.

**Rule 1.** In-memory pipeline transformations are not "mutations" of the persisted source of truth.

`process_results` filters, ranks, deduplicates, and formats results in memory before writing the output. `combined_results.json` is preserved on disk. Reviewers flagging "filter mode mutates the in-memory list" as a violation of a non-mutating philosophy are conflating two layers:
- File-level: `combined_results.json` is the canonical record, never mutated by `process_results`.
- Memory-level: the in-process result list IS the transformation pipeline.

**Why:** Distinguishing file vs in-memory state-mutation is the core design pattern. Caused a false-positive `critical` from Gemini in the 2026-05-17 blindspot audit (Point 21 / external-only E1).
**How to apply:** When a reviewer flags "mutation" inside `process_results`, check whether the persisted file on disk is touched. If not, it is likely a false positive and the documented behavior.

**Rule 2.** Reactive env-var tips are the idiomatic FastMCP pattern, not a "discoverability gap".

The `_with_tips` helper in `lib/http.py` surfaces "set `LITREV_EMAIL` / `NCBI_API_KEY` / `S2_API_KEY` / `LITREV_REVIEW_DIR`" hints in the tool's response on first call. Reviewers occasionally flag this as suboptimal vs proactive schema-level declaration of required env vars.

**Why:** FastMCP doesn't expose a clean schema hook for required env vars. The first call still succeeds (or fails gracefully) and the LLM caller sees the tip in the response. Proactive declaration would either clutter every tool signature or require non-standard MCP plumbing. Rejected in the 2026-05-17 audit (Point 24 / external-only E4).
**How to apply:** Don't auto-accept "env-var declaration should be at schema level" findings unless FastMCP's API has evolved to support it cleanly.

**Rule 3.** Empty-string is the schema sentinel for "absent value", not a "schema inconsistency".

All record types (PubMed, S2, OpenAlex) share the same key set with empty-string sentinels for absent fields (e.g. OpenAlex always returns `abstract: ""` because the API doesn't expose abstracts). Reviewers flagging "OpenAlex hardcodes empty abstract creating downstream breakage" misread the convention.

**Why:** All downstream consumers use truthiness checks (`if r.get("abstract")`), not key-presence checks. Shared-shape schema is intentional for downstream uniformity; the constraint is documented in the tool docstring ("OpenAlex does not return abstracts; use fetch_abstracts to retrieve them from PubMed"). Rejected in the 2026-05-17 audit (Point 25 / external-only E5).
**How to apply:** When a reviewer flags "field present but always empty for source X", verify that consumers use truthiness checks. If they do, the sentinel IS the design.

**Excluded from this calibration (despite REJECTED status):** path-traversal findings on `output_path` parameters (Point 13 of 2026-05-17 audit) fall in the **excluded category** (security/path traversal) per the walkthrough spec; never auto-suppressed. The MCP threat model places write-path gating at the host layer (Claude Code), not the tool. That architectural reasoning re-applies but the finding itself remains case-by-case, never silently dismissed.

**Rule 4.** MCP tool error dicts are LLM-consumed; don't add programmatic error code taxonomies.

Tools return `{"status": "error", "error": "<message>"}` on failure. Reviewers may suggest adding a `code` field (e.g. `"missing"` / `"malformed"` / `"io_error"`) so callers can "retry intelligently."

**Why:** The consumer is an LLM reading the message string, not a retry loop. Distinct `code` fields are unused dead surface; the text message already differentiates outcomes for the LLM. Rejected in the 2026-05-17 critical-code-reviewer walkthrough (Finding 13).
**How to apply:** Decline error-taxonomy proposals unless a programmatic non-LLM consumer is introduced.

**Rule 5.** Don't tighten regex on user-authored / structured-context fields.

Prose regex (e.g. PMID detection in markdown) needs strict bounds to avoid noise; structured BibTeX field regex (`pmid={...}`) can be laxer because the user explicitly annotated. Asymmetric permissiveness across contexts is intentional, not inconsistency.

**Why:** Tightening BibTeX-side regex introduces false negatives without any false-positive gain on user-authored, annotated input. Rejected in the 2026-05-17 walkthrough (Findings 4, 5).
**How to apply:** Before recommending regex tightening, check whether the input context is user-annotated (structured) or free-form (prose). User-annotated → keep lax.
