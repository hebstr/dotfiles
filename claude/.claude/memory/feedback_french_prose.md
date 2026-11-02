---
name: French prose conventions
description: Authorities, anglicism policy, typography, and registration rules for French prose work, plus the languages the work covers (English and French only, Chinese refused) and inclusive writing kept as the source has it
metadata:
  type: feedback
---

When editing or producing French prose for the user, apply these decisions. Do not relitigate them.

**Authorities (retained):** TLFi (cnrtl.fr) for sense and etymology; Le Grevisse and Riegel-Pellat-Rioul (*Grammaire méthodique du français*) for grammar; *Lexique des règles typographiques en usage à l'Imprimerie nationale* and Lacroux (*Orthotypographie*) for typography. Empirical AI-tic baselines: Bortzmeyer, sebsauvage, Maître Eolas, OCTO/Sfeir/Doctolib engineering blogs.

**Authority rejected:** the Académie française. Treated as a literary institution without descriptive authority over actual usage. Do not cite it, do not defer to its rulings.

**Variety:** français de France (fr_FR), not Québec. No anti-anglicism crusade.

**Languages covered:** English and French only. Chinese support was weighed and refused while the skill was being built, so a request for it is a new decision, not an extension.

**Inclusive writing (`utilisateur·ice·s`):** an editorial choice belonging to the source text, never a translation drift. Keep it where the source has it; never introduce it, never strip it.

**Anglicism policy:**
- *Idiomatic technical anglicisms preserved as-is* (FR is the running prose): framework, runtime, deploy, debug, push, ship, refactor, mock, scope, log, parser, build, embedding, pipeline, stack, commit, merge, rollback, prompt, token, backend, frontend, benchmark, lifecycle, payload, binding, week-end. Target is anti-AI-slop, not anti-English.
- *Reformulation zeal trap.* When rewriting bureaucratic FR for idiomatic feel, do not additionally re-translate preserved anglicisms. Concrete example (2026-05-18): renamed chapter title "Pipeline log" → "Journal du pipeline" while reformulating a Quarto book chapter; user reverted to "Pipeline logs". The gain from FR reformulation lives in nominalisation reduction and bureaucratic-opener removal, not in lexical purification; those are two different passes and the second is already covered by the preserved-list rule above. If a term appears in the preserved list, leave it alone even when the surrounding sentence is being rewritten.
- *Corporate francised verbs to translate back to French*: leverager, actionner, onboarder, scaler (en métaphore floue), pusher (une idée), driver, challenger.
- *Structural calques to translate*: adresser un problème → traiter ; supporter une feature → prendre en charge ; définitivement (au sens *certainly*) → certainement ; ça fait du sens → c'est cohérent ; compléter une tâche → terminer ; en charge de → chargé de.

**Typography:**
- No em-dash or en-dash as internal punctuation. Use comma, colon, parentheses, or restructure. En-dash for numeric ranges (`5–15 %`) is fine.
- Non-breaking space before `:`, `;`, `!`, `?`, `»`; after `«`.
- Capitales accentuées obligatoires (État, École, À).
- Quotation marks `« »` with non-breaking space inside, never `" "` in running French prose.
  - **Overridden in `eds-prise`, where a quotation takes the straight `"`**: arbitrated by the user on 2026-08-28 for `index_eds.qmd`, recorded in that project's `.claude/DESIGN-INDEX.md`, and again on 2026-11-02 for the `collab-comments` store, whose 24 pairs were converted and committed at `ff2aa17`.
  - Measured on 2026-11-02: `docs/csi/docs_csi.qmd` carries 98 straight quotes against 3 guillemets, and the annotator guide 74 against 0, split since that day's fragment cut into 40 in `docs/annot/docs_annot.qmd` and 34 in `docs/annot/docs_annot-chunk.qmd` (re-measured 2026-11-03, the 74 holding at `f2f5c37^`). A `/relire` or `/workflow:write` pass on that project never converts them back. Under `lang: fr` Pandoc's `smart` renders them `“ ”`, a consequence the user accepts.
  - **The override reaches what an upstream referential publishes, 2026-11-02**: in `eds-prise` the SNDS schema workbook's labels are normalised at the read (`.df_field` of `docs/plan/snds/scripts/_common.R`), never overridden row by row, so a guillemet never reaches a published table.
- **A cardinal number is written in digits, not spelled out, in `eds-prise`** (`6`, not `six`): directed by the user on 2026-11-02 against the FR convention of spelling out numbers under ten, and applied to `docs/plan/snds/docs_plan_snds.qmd` alone so far. Ordinals stay in letters (« une seconde étape », « la septième »), and so does pronominal « les deux » meaning *both*. Extending it to `docs_csi.qmd` (44 occurrences) and `docs_plan_eds.qmd` (25) is an open arbitration recorded in that project's `PLAN.md`.

**Standing refusal:** only an essentials distillation lives always-on in `~/.claude/CLAUDE.md` under `## Prose hygiene`. Do not promote the full FR reference there; `/workflow:write` loads it on demand.

**Why:** Without these guardrails, Claude reverts to slop-prone defaults: invoking the Académie as authority, "translating back" idiomatic anglicisms (cadriciel, étalonnage), inserting em-dashes by EN contagion, or letting calques pass the orthographic filter. Each of these has been explicitly corrected in prior sessions and validated empirically in the Apr 2026 `/workflow:write` test pass.

**How to apply:**
- When asked to edit, polish, or write French prose: invoke `/workflow:write` for full reference, or apply these rules directly for short edits.
- Bilingual FR↔EN parity reviews: see `Bilingual Review Mode` in `~/Documents/packages/claude-code-plugins/workflow/write/SKILL.md`.
- If the user contradicts a rule above, treat it as a new directive and update this memory accordingly. Do not silently re-derive the rejected position.
