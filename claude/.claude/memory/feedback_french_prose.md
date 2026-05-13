---
name: French prose conventions
description: Authorities, anglicism policy, typography, and registration rules for French prose work
type: feedback
---

When editing or producing French prose for the user, apply these decisions. Do not relitigate them.

**Authorities (retained):** TLFi (cnrtl.fr) for sense and etymology; Le Grevisse and Riegel-Pellat-Rioul (*Grammaire méthodique du français*) for grammar; *Lexique des règles typographiques en usage à l'Imprimerie nationale* and Lacroux (*Orthotypographie*) for typography. Empirical AI-tic baselines: Bortzmeyer, sebsauvage, Maître Eolas, OCTO/Sfeir/Doctolib engineering blogs.

**Authority rejected:** the Académie française. Treated as a literary institution without descriptive authority over actual usage. Do not cite it, do not defer to its rulings.

**Variety:** français de France (fr_FR), not Québec. No anti-anglicism crusade.

**Anglicism policy:**
- *Idiomatic technical anglicisms preserved as-is* (FR is the running prose): framework, runtime, deploy, debug, push, ship, refactor, mock, scope, log, parser, build, embedding, pipeline, stack, commit, merge, rollback, prompt, token, backend, frontend, benchmark, week-end. Target is anti-AI-slop, not anti-English.
- *Corporate francised verbs to translate back to French*: leverager, actionner, onboarder, scaler (en métaphore floue), pusher (une idée), driver, challenger.
- *Structural calques to translate*: adresser un problème → traiter ; supporter une feature → prendre en charge ; définitivement (au sens *certainly*) → certainement ; ça fait du sens → c'est cohérent ; compléter une tâche → terminer ; en charge de → chargé de.

**Typography:**
- No em-dash (—) or en-dash (–) as internal punctuation. Use comma, colon, parentheses, or restructure. En-dash for numeric ranges (`5–15 %`) is fine.
- Non-breaking space before `:`, `;`, `!`, `?`, `»`; after `«`.
- Capitales accentuées obligatoires (État, École, À).
- Quotation marks `« »` with non-breaking space inside, never `" "` in running French prose.

**Skill placement:**
- The FR reference is split into `references/write-fr-core.md` (~230 lines, always loaded on FR input) and `references/write-fr-extended.md` (~680 lines, loaded on top for bilingual mode, deep-review requests, or specific registers). Both live under `~/Documents/pro/packages/claude-code-plugins/workflow/write/references/`. Loaded on-demand by the `/workflow:write` skill.
- The skill is part of the `workflow` plugin in the public `hebstr` marketplace (`claude plugin install workflow@hebstr`). Edit in place at `~/Documents/pro/packages/claude-code-plugins/workflow/write/`.
- Only an essentials distillation (~10 bullets) lives always-on in `~/.claude/CLAUDE.md` under `## Prose hygiene`. Do not promote the full FR reference into CLAUDE.md.

**Why:** Without these guardrails, Claude reverts to slop-prone defaults: invoking the Académie as authority, "translating back" idiomatic anglicisms (cadriciel, étalonnage), inserting em-dashes by EN contagion, or letting calques pass the orthographic filter. Each of these has been explicitly corrected in prior sessions and validated empirically in the Apr 2026 `/write` test pass.

**How to apply:**
- When asked to edit, polish, or write French prose: invoke `/write` for full reference, or apply these rules directly for short edits.
- Bilingual FR↔EN parity reviews: see `Bilingual Review Mode` in `~/Documents/pro/packages/claude-code-plugins/workflow/write/SKILL.md`.
- If the user contradicts a rule above, treat it as a new directive and update this memory accordingly. Do not silently re-derive the rejected position.
