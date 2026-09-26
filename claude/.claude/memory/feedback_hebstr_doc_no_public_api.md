---
name: quarto-hebstr-doc has no public API constraint, no contributor policy
description: quarto-hebstr-doc is still in development with one developer; no public-API or versioning-policy argument, no CONTRIBUTING.md (removed 2026-09-26), consumer breakage is not a design constraint
metadata:
  type: feedback
---

When designing or releasing a change to the quarto-hebstr-doc extension, do not weigh it against a "public API" surface, a versioning policy or a no-consumer clause, and do not argue against breaking consumer projects: every consumer (eds-prise, md-nesrine and the others) is the user's own, the user is the sole developer, and the extension is still in development. Stated by the user on 2026-09-26 when rejecting a backward-compatible `filetree.yml` schema in favour of a breaking one, then again the same day, annoyed, when asking to delete `CONTRIBUTING.md` ("ce fichier est inutile, je suis le seul dev, il n'y a pas de contributeurs ; on le recréera au moment voulu"). The user also migrates consumer projects themselves, from those projects.

**Why:** the user migrates their own consumers; compatibility shims, "keep the old key" variants and policy wording cost more than that migration, and raising them repeatedly irritates the user.

**How to apply:** when a breaking change is the cleaner design, propose it directly and name the consumer files to migrate once; add no alias or legacy key unless asked; do not propose recreating `CONTRIBUTING.md` or rewording a versioning policy unless the user brings it up; do not offer to edit the consumer projects from this repository. This project is an exception to the `rules/css.md` line asking the repo's contributing docs to state `npm ci`: that line does not justify recreating `CONTRIBUTING.md` here. Related: [[feedback_review_severity_hebstr_doc]].
