---
name: Claude-facing content reaches English by re-authoring, not by rendering the French
description: Putting Claude-facing content into English, in the two cases that behave differently: migrating a French skill, rule or note keeps fidelity to each rule line by line, while a text Claude drafted in French is authored again from the facts with the draft set aside; a fidelity review flags calques as findings, not as style, and the 2026-09-30 prompt rejected twice names the tells
metadata:
  type: feedback
---

A French text moved to English (skills, rules, `.claude/` notes, per the English rule of `rules/claude-files.md`, "Language") is rewritten as idiomatic English in the imperative register of `rules/*.md`, keeping the meaning of each rule and word, never rendered word for word.

Two cases, and only the first is a translation. **Migrating a French document already in the tree** keeps fidelity to each of its rules, since the rules are what the file exists for. **Putting a text into English that Claude itself drafted in French**, or answering "write it in English", is not translation at all: author it again from the facts, and let the French draft go. Asking what the French sentence said is the wrong question there; the right one is what a native English writer would write knowing the same facts.

**Why:** the first translation of the `design` skill (commit `435a54c`, 2026-09-24) calqued the French sentence by sentence ("in words other than its own", "is not chosen alone", "hypothesis" for "hypothèse", "choose between two treatments"); the user called it catastrophic. Literal renderings also shifted four rules: a faux ami or a calqued construction changes what the model will do, so literalness is a fidelity defect, not a style one. A review that took "ignore pure style" to cover calques missed all of them.

**Why the second case is separate:** on 2026-09-30 a continuation prompt drafted in French was put into English word choice by word choice while keeping French sentence architecture, and the user rejected it twice. Fidelity to a French draft of Claude's own making protects nothing: there is no rule to preserve, only facts, so the line-by-line check below turns into the defect it was written to prevent. The tells were nominal chains ("the only route left is then a full verifier pass, whose measured median is"), participial openings ("Observed on a refusal naming"), `including when` for "y compris quand", `nothing but` for "n'accepte que", and `So under` for "Donc sous".

**How to apply:**
- In the migration case, translate each sentence from what the French rule asks for, then check the English against the source line by line so that no rule is lost, weakened or strengthened. In the re-authoring case, write from the facts and never open the French beside it.
- Watch faux amis that change a rule's scope: "hypothèse" is usually an assumption, "constater" is establish or observe (not record), "seul" in "ne se choisit pas seul" is unilaterally, "arbitrage" is weighing options (not any decision).
- In a fidelity review, report calqued phrasing as a finding alongside meaning shifts; "ignore pure style" covers word order and synonyms, not unidiomatic English.
- Two shapes the `review-comments` review found, to check first on the next one. A translated word that collides with a term of art the same file already owns: "written in their own register" for « rédigée sur son ton », where *register* is that skill's own word for its output file. And a rule that prescribes a `rg` whose target strings were translated while the strings on disk stayed French, so the instruction points at nothing.
- The remaining translations (`relire`, then `zotero`) are listed in `~/dotfiles/.claude/DESIGN-CADRER.md`, which now records this standard. `commit` and its verifier were translated and fidelity-reviewed on 2026-09-24 (`cfb3a40`); `depouiller` was translated and renamed `review-comments` on 2026-09-29 (`6e7eeaa`, French source at `17acef0`) and fidelity-reviewed the same day, its 17 findings over 20 sites applied in `b90813d`, no rule lost. Follow `b90813d`, not `6e7eeaa`, for the text as it now stands.
- A renamed skill takes its script names with it: the code text of a skill's scripts and tests is in English too (`rules/code.md`), while what the script writes into a French deliverable stays French.

Related: [[feedback_french_prose]].
