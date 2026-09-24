---
name: FR to EN translation of Claude-facing content is idiomatic, never word for word
description: When translating a French skill, rule or note into English (the English-for-agents migration), write idiomatic English that keeps each rule's meaning; a fidelity review flags calques as findings, not as style
metadata:
  type: feedback
---

A French text moved to English (skills, rules, `.claude/` notes, per the "All content meant for Claude or agents in English" rule of `CLAUDE.md`) is rewritten as idiomatic English in the imperative register of `rules/*.md`, keeping the meaning of each rule and word, never rendered word for word.

**Why:** the first translation of the `design` skill (commit `435a54c`, 2026-09-24) calqued the French sentence by sentence ("in words other than its own", "is not chosen alone", "hypothesis" for "hypothèse", "choose between two treatments"); the user called it catastrophic. Literal renderings also shifted four rules: a faux ami or a calqued construction changes what the model will do, so literalness is a fidelity defect, not a style one. A review that took "ignore pure style" to cover calques missed all of them.

**How to apply:**
- Translate each sentence from what the French rule asks for, then check the English against the source line by line so that no rule is lost, weakened or strengthened.
- Watch faux amis that change a rule's scope: "hypothèse" is usually an assumption, "constater" is establish or observe (not record), "seul" in "ne se choisit pas seul" is unilaterally, "arbitrage" is weighing options (not any decision).
- In a fidelity review, report calqued phrasing as a finding alongside meaning shifts; "ignore pure style" covers word order and synonyms, not unidiomatic English.
- The remaining translations (`relire`, `depouiller`, `zotero`, then `commit`) are listed in `~/dotfiles/.claude/DESIGN-CADRER.md`, which now records this standard.

Related: [[feedback_french_prose]].
