---
name: Skill autoresearch évalué et non adopté
description: Décision 2026-09-11 de ne pas installer le skill uditgoenka/autoresearch ; la boucle métrique exige des commits git par itération, interdits ici, et le reste doublonne ouroboros et les plugins audit/workflow ; analyse complète déjà faite, ne pas la refaire
metadata:
  type: project
---

Le 2026-09-11, évaluation complète du skill Claude Code `uditgoenka/autoresearch` (v2.2.2, MIT, 6 288 étoiles), généralisation de l'autoresearch de Karpathy.
Décision : ne pas l'installer en l'état.
Analyse, mesures et conditions de réouverture dans `~/dotfiles/_meta/notes/autoresearch-skill-reco.md`.

**Why:** son unique apport net est la boucle métrique keep/discard (baseline, une modification atomique, `Verify` qui sort un nombre, `Guard`, garder ou `git revert`, journal TSV). Cette boucle exige un `git commit` par itération et un dépôt propre, or `settings.json` refuse `git add`, `git commit`, `git reset`, `git checkout`, `git stash` et `git restore` : elle s'arrête à la première itération. Les 13 autres commandes doublonnent `ouroboros:interview`, `ouroboros_lateral_think`, `/audit:blindspot`, `/audit:walkthrough`, `/ouroboros:evaluate`, `posit-dev:describe-design`, `security-review` et `/loop`. L'installation en plugin ajouterait en plus 9 hooks Node globaux, dont un `simplify-gate` sur `UserPromptSubmit` qui bloque le prompt au-delà de 800 lignes modifiées et dont les phrases de désamorçage sont uniquement anglaises. Les problèmes difficiles du stack (fidélité docx, typographie Quarto/Typst) n'ont pas de métrique mécanique locale, donc sont hors de portée par construction.

**How to apply:** si le sujet revient, lire la note plutôt que refaire l'analyse. Trois conditions rouvrent la décision : une branche jetable où des commits automatiques sont acceptables (le créneau reste la couverture `covr` de `R-hebstr` et `R-edstr`), l'apparition d'une métrique scalaire rapide sur un projet du stack, ou une version de l'outil qui dissocie la boucle de git. Si adoption un jour, passer par la copie manuelle du skill et des commandes (option C du README), jamais par le plugin, pour ne pas hériter des hooks. Même forme que [[project_arity_evaluation]].
