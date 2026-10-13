---
name: feedback_review_severity_litrev_mcp
description: "Calibrate adversarial review severity for the litrev-mcp MCP server: the design choices recurring reviewers misread as defects (in-memory transformations, reactive env tips, the empty-string sentinel, LLM-consumed error dicts, context-asymmetric regex, nine further dismissals) and the five won't-fix shapes no file in the repo records."
metadata:
  type: feedback
---

Adversarial reviewers (skill-adversary, mcp-adversary, cross-model judges) tend to misread established design choices in `mcp/src/litrev_mcp/`. Do not re-litigate them on every audit. Rules 1 to 5 come from the 2026-05-17 audits; rules 6 and 7 were migrated on 2026-10-13 from the legacy harness store, whose project key no longer resolves.

**Rule 1.** In-memory pipeline transformations are not "mutations" of the persisted source of truth.

`process_results` filters, ranks, deduplicates, and formats results in memory before writing the output. `combined_results.json` is preserved on disk. Reviewers flagging "filter mode mutates the in-memory list" as a violation of a non-mutating philosophy are conflating two layers:
- File-level: `combined_results.json` is the canonical record, never mutated by `process_results`.
- Memory-level: the in-process result list IS the transformation pipeline.

**Why:** Distinguishing file vs in-memory state-mutation is the core design pattern. Rejected in the 2026-05-17 blindspot audit.
**How to apply:** When a reviewer flags "mutation" inside `process_results`, check whether the persisted file on disk is touched. If not, it is likely a false positive and the documented behavior.

**Rule 2.** Reactive env-var tips are the idiomatic FastMCP pattern, not a "discoverability gap".

The `_with_tips` helper in `server.py` surfaces "set `LITREV_EMAIL` / `NCBI_API_KEY` / `S2_API_KEY` / `LITREV_REVIEW_DIR`" hints in the tool's response on first call. Reviewers occasionally flag this as suboptimal vs proactive schema-level declaration of required env vars.

**Why:** FastMCP doesn't expose a clean schema hook for required env vars. The first call still succeeds (or fails gracefully) and the LLM caller sees the tip in the response. Proactive declaration would either clutter every tool signature or require non-standard MCP plumbing. Rejected in the 2026-05-17 audit.
**How to apply:** Don't auto-accept "env-var declaration should be at schema level" findings unless FastMCP's API has evolved to support it cleanly.

**Rule 3.** Empty-string is the schema sentinel for "absent value", not a "schema inconsistency".

All record types (PubMed, S2, OpenAlex) share the same key set with empty-string sentinels for absent fields (e.g. OpenAlex always returns `abstract: ""` because the API doesn't expose abstracts). Reviewers flagging "OpenAlex hardcodes empty abstract creating downstream breakage" misread the convention.

**Why:** All downstream consumers use truthiness checks (`if r.get("abstract")`), not key-presence checks. Shared-shape schema is intentional for downstream uniformity; what carries the constraint is the OpenAlex parser itself, which sets `abstract: ""`, and no tool docstring states it. Rejected in the 2026-05-17 audit.
**How to apply:** When a reviewer flags "field present but always empty for source X", verify that consumers use truthiness checks. If they do, the sentinel IS the design.

**Excluded from this calibration (despite REJECTED status):** path-traversal findings on `output_path` parameters fall in the **excluded category** (security/path traversal) per the walkthrough spec; never auto-suppressed. The MCP threat model places write-path gating at the host layer (Claude Code), not the tool. That architectural reasoning re-applies but the finding itself remains case-by-case, never silently dismissed.

**Rule 4.** MCP tool error dicts are LLM-consumed; don't add programmatic error code taxonomies.

Tools return `{"status": "error", "error": "<message>"}` on failure. Reviewers may suggest adding a `code` field (e.g. `"missing"` / `"malformed"` / `"io_error"`) so callers can "retry intelligently."

**Why:** The consumer is an LLM reading the message string, not a retry loop. Distinct `code` fields are unused dead surface; the text message already differentiates outcomes for the LLM. Rejected in the 2026-05-17 critical-code-reviewer walkthrough.
**How to apply:** Decline error-taxonomy proposals unless a programmatic non-LLM consumer is introduced.

**Rule 5.** Don't tighten regex on user-authored / structured-context fields.

Prose regex (e.g. PMID detection in markdown) needs strict bounds to avoid noise; structured BibTeX field regex (`pmid={...}`) can be laxer because the user explicitly annotated. Asymmetric permissiveness across contexts is intentional, not inconsistency.

**Why:** Tightening BibTeX-side regex introduces false negatives without any false-positive gain on user-authored, annotated input. Rejected in the 2026-05-17 walkthrough.
**How to apply:** Before recommending regex tightening, check whether the input context is user-annotated (structured) or free-form (prose). User-annotated → keep lax.

**Rule 6.** Nine further dismissals, migrated 2026-10-13 from the legacy harness store with every subject re-checked in `mcp/src/litrev_mcp/` on that date.

The four module-level `httpx.Client` instances of `lib/http.py` are correct in a long-lived server process: do not flag them as "never closed". Natural-language ambiguity between tool descriptions is the LLM's discrimination job, not a schema defect. The `_regex` suffix of `extract_claims_regex` deliberately marks the automated first pass against a future LLM-based extraction. `study_types: list[str] | None` is correctly open, its values coming from external APIs with no fixed enum. `timeout: int = 10` as a tool parameter is an operational knob, not an implementation leak. `except Exception` inside the HTTP retry wrappers of `lib/` is acceptable, FastMCP catching tool-level exceptions. A missing `Path.exists()` check is not a gap, FastMCP surfacing `FileNotFoundError`. The `full_dedup[len(existing_deduped):]` slice of `citation_chain` correctly returns only the new candidates. And `process_results`'s formatters handle a `str` and a `list[str]` author at render time by design. One item of that legacy list was dropped at migration: the `Literal["s2", "openalex", "s2,openalex"]` with a `sources.split(",")` is gone, `citation_chain` now declaring `sources: list[Literal["s2", "openalex"]] | None`.

**Rule 7.** Five won't-fix shapes the user settled once and no file in the repo records.

Migrated 2026-10-13 from the legacy `skipped_review_points`, which lived under a harness path that no longer resolves; `claude-code-litrev` has no `CLAUDE.md` and no review-calibration file, so nothing else carries them. No `defusedxml` against the `ET.fromstring` of `lib/pubmed.py` and `lib/fulltext.py`: CPython's expat resolves no external entities and the sources are trusted NCBI APIs. Author parsing duplicated at about twelve sites, each call site parsing a different input shape for a different purpose, so factoring buys complexity. No test for the PMC to Unpaywall to S2 cascade of `fetch_and_cache`, a linear cascade whose components are tested (`tests/test_fulltext.py` covers the parser and the cache, and exercises `fetch_and_cache` on the cache-hit path alone). `seen_keys = set(md_keys.values())` in `tools/verify.py` pre-seeds the markdown keys on purpose, reserving them so an orphan DOI cannot collide. And the collision branch of `unique_key` in `lib/bibtex.py` keeps the bare key in `seen_keys` deliberately, since removing it would break collision detection.

Three further items of that list lost their subject before this migration and are not carried: the Sci-Hub default fallback (no `sci-hub` string anywhere in the tree, the cascade being PMC, Unpaywall then S2 in `lib/fulltext.py`), `sys.path.insert` for sibling imports (`mcp/` is a package with relative imports and a `py.typed`), and `process_articles` mutating its input dicts (the function is gone). Its two remaining blocks, the deliberate design decisions and the dismissed `SKILL.md` ambiguities, were not re-checked item by item: treat them as unverified if one resurfaces.
