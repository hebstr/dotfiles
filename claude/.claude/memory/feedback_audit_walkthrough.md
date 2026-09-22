---
name: audit:walkthrough and audit:blindspot operating lessons
description: "Running /audit:walkthrough and /audit:blindspot here: weigh blindspot findings by the evidence they needed rather than by bucket, read the judge's coverage line first, never collapse a near-miss, brief L1 with the competing reading, re-read fixes as a set at wrap-up, check ListAgents before writing"
metadata:
  type: feedback
---

Ouroboros specifics for the Step 3 evaluate and the drift check live in [[feedback_ouroboros_tools]]. L2 has called `audit/walkthrough/scripts/openrouter-verdict.py` since 2026-09-15; every L2 count recorded before that date is intra-family agreement.

## Calibration loading

The loader in `audit/walkthrough/agents/orchestrator.md` ("Load target project memories") resolves the store, globs `feedback_review_severity*.md`, filters by each file's `description` and prints `kept K/N: ...; skipped: ...`. Validated live on 2026-09-15 on a repository root and on a cited-files target. Still untested: a walkthrough-only report about another repository than the cwd, where `DEFERRED.md` must also go to the repo the findings concern, not the cwd's. Watch the status line on the first such run.

**Plugin skill naming: trust the live session over the docs page.** On 2026-09-15 the docs said a plugin skill's frontmatter `name` sets the command's last segment; Claude Code 2.1.271 named plugin skills after their directory (`name: ouroboros-config` registered as `ouroboros:config`). `scan-reviewers.py` follows the observed behaviour; compare against the session's own skill list before changing it.

## Blindspot buckets: weigh the evidence a finding needed

`audit:blindspot` frames `external-only` findings as Claude's blind spots. Measured over six runs, the bucket predicts little on its own; what predicts acceptance is what the external model had to read or run.

- **Read the judge's `**Truncated:**` line before any bucket rate.** A finding the judge made about a contradiction inside text it had in full is usually right (11 of 11 `external-only` accepted on an untruncated instruction document, 2026-09-20). A finding resting on a mechanism the judge could not run is usually wrong (0 of 8 on `export.py`, 2026-07-31: a critical on a premise one command refutes, two vectorization requests that measured at 0.7 % and 1.7 % of build time; on a rules corpus, three findings declaring installed tools hallucinations).
- **`agreed` stays the most reliable bucket** (near-perfect across runs), `claude-only` sits between. Never quote a bucket's historical rate without saying what the judge could see.
- **Accepted is not correct.** None of the eleven accepted `external-only` findings of 2026-09-20 survived as written: each needed its mechanism replaced, its scope cut or its remedy refused. The rate says where to look, never what to write.
- **Two findings sharing a false premise are not corroboration**, and a real observation can arrive with a remedy that loosens a contract the repository just tightened.

**The judge's 80,000-character cap drops whole files and fakes `claude-only` buckets.** The cap in `audit/blindspot/agents/cross-model-judge.md` is sized for small-context models: on `audit/walkthrough` it left the judge 2 files of 13, and eight Claude findings sat in `claude-only` only because the judge never saw their file. When the coverage line names dropped files, run a second judge pass scoped to them **before** the walkthrough, since the bucket decides L2 routing. Price it at its failure: one second-pass call (2026-09-21) looped until `finish_reason: length` for 0.82 USD and zero findings, four times the cost of a successful one; on a rules corpus, retry with a different model family. A finding whose evidence spans a dropped and a kept file stays untestable either way; say so.

**Never collapse a near-miss pair into `agreed`.** The convergence rule fires on 2 of 3 signals, and "same file and line" plus "same fix surface" reach 2 without the defects being one. Three near-miss pairs each held one real defect and one false positive on the same line. Match on the defect and the remedy, never on the location.

**A hand-written blindspot report spells the heading `### Convergence Analysis`, three hashes.** `audit:walkthrough` matches that literal string to switch on bucket routing; at `##` it silently falls back to severity-only routing.

## Running the walkthrough

- **Give L1 the competing reading to attack, not your own conclusion.** A brief handing L1 both the finding and the reframing against it returned a third, better answer carrying a harness fact neither side had; a brief framed around Claude's defence got the defence echoed back.
- **Read an L2 rationale, not only its verdict.** An `invalid` whose stated reason exhibits the ambiguity the finding describes is evidence for the finding. L1 and L2 earn most by correcting the drafted remedy where the diagnosis holds.
- **A point-by-point walkthrough does not see what its own fixes change, and cross-checks validate a fix's direction, never its breadth.** Fixes interact across points (an escape hatch widening a later false positive, a rule forbidding a merge the same walkthrough performed), and the scope a fix is written with is never reviewed: on 2026-09-21 a source-file carve-out meant for one secret-pattern token was applied to all five and opened a hole on `secrets.py`. Re-read every sentence the walkthrough authored, as a set, at wrap-up, before writing the summary.
- **Run `ListAgents` before a walkthrough that will write, not only `git status`.** On 2026-09-20 a peer session on the same repository rewrote four files mid-walkthrough on a tree `git status` had reported clean; nothing but `ListAgents` names such a session. Its edits arrive as harness notices saying the change is "usually deliberate", which reads as the user's doing. Check `ListAgents` before naming a culprit, and correct a wrong attribution plainly. A clean tree is a snapshot, not a lock.
