---
name: feedback_litrev_pipeline_patterns
description: "Recurring decisions on `/litrev` scoping runs: corpus sizing, snowball skip heuristic, audit_claims false positives, validate_gate workaround, pseudo-GRADE detection, post-generation prose cleanup."
metadata:
  type: feedback
---

Patterns from `/litrev` scoping runs (CHU Lille). Anticipate these instead of re-discovering them.

**Rule 1.** Broad scoping framing produces 200-300 included articles, well past the pipeline's 100-article comfort zone.

Seen on the epidemio PRISE run (2026-05-17): 608 screened → 294 included (48 % retention). Post-hoc filter took it down to 107 via regex on EU + qualifying design.

**Why:** When the user asks for a wide cadrage-style scoping covering several PICO outcomes (prevalence + incidence + burden + determinants), sensitive screening saturates mechanically. The pipeline never narrows it back down on its own.
**How to apply:** As soon as the included count crosses ~150 at Gate 3a, offer a post-hoc restriction by geographic priority + qualifying design (SR/MA, medico-administrative cohorts, registries); don't wait for the orchestrator warning at 100. Aim for 80-120 retained. Document the filter in `screening_log.md`.

**Rule 2.** Backward snowballing returns ~0 retained articles when the temporal window is ≥10 years recent.

Seen on the same run: 8 top-cited EU seeds, 321 backward candidates → 254 pre-2015, 67 out-of-scope, **0 retained**.

**Why:** Recent papers cite foundational work, most of it pre-2010. A strict recent window kills the backward yield. Forward snowballing is the productive direction here, but it needs S2 or OpenAlex citation lookups.
**How to apply:** Default to skipping backward snowballing on scoping reviews with a window ≥10 years recent. Run it only if the user insists after the warning. Forward stays useful when S2 is available.

**Rule 3.** `litrev-synthesize` self-check #9 (no DOI in BibTeX) used to break `audit_claims`. Fixed 2026-05-19.

Seen: valid `references.bib` with 107 `@article{Key, ... pmid = {...}}` entries → `audit_claims` reports `bib_keys_parsed: 0` → 420/726 UNVERIFIED. The parser now accepts PMID-only entries (`parse_bib_keys_to_ids` returns `{doi, pmid}` and `_resolve_key` falls back to a PMID bridge).

**Why:** The contract mismatch is resolved on the `audit_claims` side. `generate_bibliography` still has the same friction (DEFERRED F33).
**How to apply:** On a fresh `audit_claims` run with PMID-only `references.bib`, no need to bypass anymore. Still sample `multi_citation: True` UNVERIFIED claims before flagging hallucination; disambiguation false positives remain a separate bucket. For `generate_bibliography` PMID-only, the workaround (extract embedded BibTeX block from the review) is still required until F33 lands.

**Rule 4.** Bypass `validate_gate` MCP on first stall.

Seen: `validate_gate` hung ≥30 min on the first call after `protocol.md` was written. The tool itself is pure I/O + regex (see `mcp/src/litrev_mcp/tools/gates.py`), so the stall is in the MCP transport, not the code.

**Why:** No point waiting on a transport bug when the gate checks are trivial to reproduce manually.
**How to apply:** First sign of stall on `validate_gate`, drop to manual validation via Read/Bash. Log the bug in the project's `.claude/litrev_feedback.md` and move on.

**Rule 5.** Pseudo-GRADE in Conclusions. Self-check #10 now catches it (2026-05-19); remediation rule still applies.

Seen: `litrev-synthesize` produced a "certainty of evidence: moderate / low / high" Conclusion bullet when (a) GRADE isn't in the protocol, (b) PRISMA-ScR doesn't prescribe grading, (c) no grading procedure is described in Methods. `skills/litrev-synthesize/SKILL.md` self-check #10 now scans Conclusions and Results subsections for FR + EN GRADE vocabulary and fails BLOCKING when no GRADE rubric is declared in Methods.

**Why:** It reads as a methodological grade but is authorial. For a cadrage document feeding a protocol, that's a credibility risk.
**How to apply:** When self-check #10 fires, remediate per the rule in `SKILL.md` Step 5: either rewrite as narrative description (robust registries / methodological heterogeneity / limited corpus) or formally declare the rubric in Methods. Don't override the check by adding a one-word "GRADE" mention to Methods; the check also requires a rating procedure. See [[feedback_review_severity_litrev_mcp]] for related calibrations on the same plugin.

**Rule 6.** Post-generation prose cleanup: two passes, two different problems.

Seen on the PRISE epidemio book mise-en-forme (2026-05-18). Two distinct passes told two different stories.

*Pass 1, mechanical `/workflow:write` FR-core on 13 chapter files (~1070 lines), via parallel agents:* ~25 accepted edits, concentrated in audit findings (`08-audits.qmd`) and discussion (`07-discussion.qmd`); three batches over five files returned zero edits. The agents reported "prose already clean".

*Pass 2, substantive FR reformulation by main model after user override ("c'est à toi de reformuler le contenu de façon plus FR idiomatique"):* substantial edits on 10 of 13 files. The corpus had a real translated-from-English bureaucratic register the /workflow:write checklist missed entirely.

**Why:** PRISMA-ScR scaffolding eliminates the canonical AI-slop tics (négatif parallèle, questions rhétoriques, « il convient de noter », « révolutionne », triplets symétriques vides) by forcing a factual, inductive register. The `/workflow:write` checklist targets those, so it returns near-empty diffs. But litrev output still reads like translated English: heavy nominalisations (« constitue le cadrage », « la présente scoping review », « s'inscrit dans une démarche »), bureaucratic chaining (« compte tenu de », « ayant produit », « à partir d'une approche couplée »), empty adjectives (« détaillé », « exécutif », « significatif » without a number), and announce-then-state framings (« une donnée structurante pour la pratique : … », « trois points méritent d'être réitérés »). These are not on any AI-tic list; they are formal-register translationese.

**How to apply:**
1. *Mechanical pass:* `rg -l '[—–]'` to convert em-dash/en-dash in internal punctuation; targeted sed on finding titles (`— \*(minor|major|critical)\*` → `, *$1*`); a quick run on vocabulary inflation (« à l'instar de », « par conséquent », « permettre de + verbe » chaîné). Cheap, mechanical, do it first.
2. *Substantive pass:* don't delegate to `/workflow:write` agents; they apply the wrong checklist. The main model should rewrite directly, looking for nominalisation chains, bureaucratic openers (« la présente », « le présent document »), and announce-then-state ("X : Y" where Y is the actual content). Aim for verb-first, fact-first sentences. Cut adjectives that don't carry a constraint.
3. *Skip:* the canonical AI-tic checklist (négatif, rhétorique, rituel openers, vide triplets). Confirmed absent on this corpus type; running /workflow:write on it is wasted budget.
