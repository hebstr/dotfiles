---
name: A probe that condemns an option must exercise that option's strongest form
description: When a measurement is used to rule an option out, check that the probe covered the form of the option a competent advocate would have proposed; a probe over the weakest form yields a true observation and a false conclusion
metadata:
  type: feedback
---

A measurement that eliminates a design option carries the weight of the whole arbitration. Before writing it into a recommendation, ask what the strongest version of the condemned option looks like, and check that the probe exercised that version rather than the first one that came to mind.

## Why

Two instances in the same session, 2026-09-01, `eds-prise`, arbitrating `gtsummary::tbl_hierarchical()` against a hand-built table of indicator columns.

**Probe over the weakest form.** I measured that `tbl_hierarchical()` drops the row of a level absent from the data, using a `character` column. I wrote "les niveaux absents sont supprimés" into the framing note as one of two grounds for rejecting the function. But `tbl_summary()` honours declared factor levels, so any reader would ask about a factor, and that was the form worth testing. The conclusion happened to hold when I finally tested it under challenge, so the recommendation survived by luck rather than by method.

**Conclusion wider than the probe.** I measured that one montage of a three-column ventilation failed, and wrote that the ventilation had to be given up. A second montage existed (`by =` plus a separately built overall column) and worked, verified in one command. The user's question, "pourquoi faut-il y renoncer ?", is what surfaced it. The observation was true; the statement built on it was false.

Both are downstream of the same reflex: a probe returns a clean result, the result fits the direction the argument is heading, and the probe's scope goes unexamined. Neither is covered by [[feedback_verify_before_claiming]], which governs claims made with no verification at all; here the verification ran and answered a narrower question than the one being decided.

The asymmetry matters. A probe that *supports* an option costs little when too narrow, since the option stays open and later work exercises it. A probe that *condemns* an option closes it, and nothing downstream ever revisits it: the whole arbitration then rests on a case that was never tested.

## How to apply

- **Trigger**: about to write "X is impossible / X fails / X must be given up" into a recommendation, framing note, or design document, on the strength of a measurement.
- Name the strongest form of X before running the probe, not after. Concretely: does a declared type change it (factor levels, an ordered factor)? Is there a second assembly reaching the same result? Does an argument already exist for the behaviour observed?
- Prefer "X, in the form probed, does Y" to "X does Y". The narrower sentence is both true and enough to argue with, and it exposes its own scope to the reader.
- A user question of the form "pourquoi faut-il ...?" or "qu'est-ce qui te fait choisir ...?" is not a request to restate the argument. Treat it as a prompt to re-audit the probe behind it before answering, per rule 4 of [[feedback_verify_before_claiming]].
- When the re-audit confirms the conclusion, say that the check was re-run and on what, rather than repeating the original claim. When it overturns it, correct the statement plainly and carry the corrected reason into whatever note already recorded the wrong one: a framing note that outlives the conversation will otherwise teach the next session the false reason.
