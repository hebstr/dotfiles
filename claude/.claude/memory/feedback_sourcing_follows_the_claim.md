---
name: feedback_sourcing_follows_the_claim
description: In a document whose convention is one store entry per sourced claim, rewriting an unsourced sentence inherits the citation obligation; a correction is not exempt because it edits rather than adds, and the new entry owes a render
metadata:
  type: feedback
---

In a document that carries its evidence as `.comments/collab-comments.json` entries, one per factual claim, the obligation attaches to the **claim that ends up published**, never to the kind of edit that put it there. Rewriting a sentence is therefore not exempt: if the replacement asserts something about the outside world, it owes its page, its bare URL and its verbatim exactly as a new sentence would.

**Why:** the exemption feels automatic because a `/relire` turn is framed as prose work, and a correction reads as subtraction rather than assertion. The skill's own brief states the convention as "each factual claim of the unit", which reads as the unit's existing claims to audit rather than the ones my edits introduce, so the instruction can be in context and still miss.

Incident, 2026-11-01 on `eds-prise`'s `docs/plan/snds/docs_plan_snds.qmd`, section « Critères de ciblage »: the callout's premise « Le volet national ne dispose que de données codées, donc il repose entièrement sur les définitions à base de codes CIM-10 et CCAM » was replaced because it overclaimed, measured against the declaration at 27 concepts of which 14 carry no code, over 7 nomenclatures and not 2. The replacement, that the arm holds no report text, is a documentable fact about the SNDS, and it went in from recall with no entry. The user caught it by noticing that no edit of the pass had gained a comment. Four edits, one at fault: the other three asserted only what `_variables.yml` and `tbl-plan-snds-cohorte.R` hold, which has no page.

**How to apply.** Before an `Edit` on sourced prose, ask what the replacement asserts and who owns that fact.

- The project's own declaration is verified against the file and needs no entry.
- An external fact needs the page **first**, so the wording is built onto the verbatim instead of paraphrased and patched after: here the SNDS documentation gave « ni résultats d'examen ou d'actes (imagerie médicale, biologie médicale, compte-rendu opératoire, etc.) », which tightened the published sentence a second time.
- A claim that only restates an upstream sentence already carrying an entry inherits that entry rather than duplicating it, and saying so in the turn is part of the answer.
- A new entry changes the docx, so it owes the render that a prose-only pass does not: read the filter's stderr and count `w:comment` and the HYPERLINK fields, the filter dropping a bad entry in silence at exit 0.

Mechanism and anchor hazards in [[project_collab_comments_evaluation]]; the verification half in [[feedback_verify_before_claiming]].
