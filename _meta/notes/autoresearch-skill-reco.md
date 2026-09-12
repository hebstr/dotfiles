# autoresearch : adopter ou non le skill d'itération autonome

2026-09-11. Décision demandée : le skill `uditgoenka/autoresearch` mérite-t-il d'entrer dans le stack Claude Code de la machine.

Verdict : non, pas en l'état. Le seul apport net est inopérant sous la politique git en vigueur, et le reste doublonne ce qui est déjà installé. Conditions de réouverture en fin de note.

## L'outil

Vérifié le 2026-09-11 : dépôt `uditgoenka/autoresearch`, licence MIT, 6 288 étoiles, 462 forks, 4 issues ouvertes. Version `v2.2.2` publiée le 2026-08-12, dernier commit le même jour. 72 des 78 commits viennent d'un seul auteur. Cadence de publication soutenue de mars à juin 2026, puis une seule livraison en août.

Se présente comme une généralisation de l'autoresearch de Karpathy, que son README décrit comme un script Python de 630 lignes optimisant un GPT en autonomie pendant la nuit. Le dépôt d'origine (`karpathy/autoresearch`, 95 591 étoiles, créé le 2026-03-06) tient effectivement dans un unique `train.py` de 26 Ko.

Le contenu est à 95 % du markdown : un `SKILL.md` de 107 lignes qui route vers 13 fichiers de commande de 94 à 136 lignes. Les seuls artefacts exécutables sont `scripts/orchestrate.sh` (448 lignes, présenté comme le « seam déterministe » où vit le routage), `score-regression.sh`, et 9 hooks Node d'environ 900 lignes cumulées. Le dépôt livre le même contenu en cinq copies, une par hôte supporté (Claude Code, OpenCode, Codex), ce qui explique ses 256 fichiers pour une surface réelle bien plus petite.

## Le mécanisme

Une seule idée porte l'ensemble, et elle est correctement écrite :

```
baseline (itération 0) → UNE modification atomique → git commit
  → Verify: <commande qui sort un nombre> → delta
  → Guard: <commande qui doit toujours passer>
  → keep, ou `git revert HEAD --no-edit`
  → ligne TSV → itération suivante
```

Git tient lieu de mémoire : à chaque tour l'agent lit `git log --oneline -20` et `git diff HEAD~1` pour savoir ce qui a fonctionné et ce qui a échoué. Le journal TSV donne la trajectoire de la métrique, et `--evals` insère des points de contrôle qui détectent les plateaux.

Les 14 commandes sont soit des variantes de cette boucle avec une métrique préconfigurée (`fix` sur le compte d'erreurs, `debug` sur les hypothèses réfutées, `security` sur les findings), soit des protocoles de personas sans boucle (`predict`, `probe`, `reason`, `improve`), soit des analyses de journal (`evals`, `regression`).

## Le blocage dur

Chaque commande bouclante impose en préconditions explicites « git repo exists, clean working tree », puis un commit à chaque itération et `git revert` comme rollback.

Le `settings.json` de la machine refuse `Bash(git add*)`, `Bash(git commit*)`, `Bash(git reset*)`, `Bash(git checkout*)`, `Bash(git stash*)` et `Bash(git restore*)`, et le CLAUDE.md global pose que l'utilisateur gère seul toutes les opérations git. Les règles `deny` sont dures : la boucle s'arrête à la première itération, phase commit.

Sans commit, le rollback disparaît aussi, et `git log` cesse d'être une mémoire. Il ne reste que « fais une modification, mesure, garde ou défais à la main », soit le squelette privé de son moteur.

Lever la garde aurait une conséquence directe et durable : des dizaines de commits `experiment: ...` dans l'historique de `R-hebstr` ou `R-edstr`, historique tenu à la main.

## Redondance avec le stack installé

| Commande autoresearch | Déjà couvert |
|---|---|
| `:probe` (8 personas interrogent les exigences) | `/ouroboros:interview`, `/ouroboros:pm` |
| `:predict` (5 experts débattent avant implémentation) | `ouroboros_lateral_think`, `/think` |
| `:reason` (débat adversarial, juges aveugles) | `/audit:blindspot`, `/audit:skill-adversary` |
| `:plan` (objectif vers Scope/Metric/Verify validés) | discipline « what does done look like », `ouroboros_generate_seed` |
| `:fix` et `:debug` | gate lint+format+test par langage, `/audit:walkthrough` |
| `:evals` et `:regression` | `/ouroboros:evaluate`, `ouroboros_measure_drift` |
| `:learn` (scout, génération de docs, validation) | `posit-dev:describe-design`, `/workflow:doc-structure`, `/init` |
| `:security` | `security-review` (builtin) |
| `:ship` | git et déploiement tenus à la main |
| boucle planifiée | `/loop` (builtin) |
| boucle autonome sans fin | `ouroboros:ralph` |

La seule brique authentiquement absente du stack est la boucle métrique keep/discard avec journal TSV, celle que la politique git rend inopérante.

## Le coût des hooks

L'installation en plugin enregistre 9 hooks globaux, actifs dans toutes les sessions et pas seulement pendant une boucle :

- `scout-block` sur `Read|Edit|Write|Glob|Grep|Bash` : bloque les chemins contenant `.git/`, `node_modules/`, `__pycache__/`.
- `privacy-block` sur les mêmes événements : bloque `.env`, `.pem`, `.ssh/`, `credentials.json`. Recouvre `rules/secrets.md`, dont il ignore les exemptions (`.env.example`, allowlist `~/dotfiles/**`).
- `simplify-gate` sur `UserPromptSubmit`, timeout 30 s : si le prompt contient `ship|merge|deploy|pr|publish|release` en mot entier et que `git diff HEAD --numstat` dépasse 800 lignes cumulées, il bloque le prompt. Les phrases de désamorçage sont uniquement anglaises, donc un « ne pas merger encore » ne l'annule pas. Il lit aussi intégralement chaque fichier non suivi pour en compter les lignes, ce qui coûte cher si un gros fichier non ignoré traîne.
- `dev-rules-reminder` et `session-init` réinjectent leur propre contexte projet, en concurrence avec `inject-project-context.sh`.

Trois hooks locaux occupent déjà `PreToolUse(Edit|Write)`, `PostToolUse(Edit|Write)` et `SessionStart`. Rien ne casse mécaniquement, mais cela ajoute 9 processus Node sur des événements très fréquents pour un outil dont la fonction principale reste hors d'atteinte.

L'installation par copie manuelle (option C du README) ne pose que le skill et les commandes, sans les hooks. C'est la seule forme d'adoption défendable si la question se rouvre.

## Le seul créneau viable

La couverture de tests des packages R. `covr`, `testthat` et `devtools` sont installés, `covr::package_coverage()` sort un scalaire, `devtools::test()` fait un Guard crédible. `R-hebstr` (55 fichiers `.R`, 22 fichiers de test) et `R-edstr` (43 et 12) sont les cibles naturelles. C'est le cas canonique de Karpathy transposé tel quel.

Deux réserves : il faudrait lever la garde git sur ce projet précis, et chaque vérification est un `package_coverage()` complet, donc la boucle est lente.

Les autres candidats s'effondrent à l'examen.

**Scripts shell de `~/dotfiles`** (23 scripts dans `bin/.local/bin/`, 26 fichiers `.bats` dans `_meta/tests/`) : la métrique existe, compte de violations `shellcheck` et tests bats. Mais le gate lint+format+test tourne à chaque édition, donc l'état « base cassée avec N erreurs à écraser » que présuppose `:fix` ne se produit jamais. Rien ne consommerait la boucle.

**Quarto, Typst, docx** : hors de portée par construction. `rules/docx.md` établit qu'aucun outil de la machine ne rend un docx comme Word et que la divergence LibreOffice tombe précisément sur la justification et les coupures de ligne. `hyphens: auto` n'est pas mesurable localement non plus, faute de dictionnaire de césure dans Chromium. Sans métrique mécanique, pas de boucle possible. C'est là que sont les problèmes difficiles, et c'est exactement là que l'outil ne peut rien.

**Code d'analyse biostatistique** : hors périmètre par la règle de préservation.

**Conventions du dépôt** : les exemples et l'auto-détection sont npm et TypeScript (`npm test`, `tsc --noEmit`, taille de bundle). Rien ne connaît R, Quarto, `air`, `jarl` ou `rv`.

## Ce qu'il reste à en prendre

Le patron, pas l'outillage. Sur la couverture R, une session dédiée suffit : fixer la baseline `covr::package_coverage()`, appliquer une modification atomique par tour, faire tourner le gate existant comme Guard, journaliser dans un TSV, garder ou annuler soi-même via git. Cela reproduit le mécanisme de Karpathy sans céder la garde git ni installer 9 hooks. `/loop` cadence les tours si l'automatisation devient souhaitable.

## Conditions de réouverture

La décision change si l'une de ces conditions se réalise :

1. La politique git s'assouplit sur un dépôt précis, par exemple une branche jetable `experiment/` où des commits automatiques sont acceptables. La boucle redevient alors exécutable et le créneau couverture R s'ouvre.
2. Un projet du stack acquiert une métrique scalaire rapide qui n'existe pas aujourd'hui, typiquement un temps de rendu Quarto ou un score de conformité mesurable sur un gabarit.
3. L'outil dissocie la boucle de git, par exemple avec un rollback par copie de fichiers. Rien dans le dépôt actuel ne va dans ce sens.

Ne pas refaire l'analyse : les mesures et le relevé de redondance ci-dessus tiennent tant que le stack ne bouge pas.

## Références

- Dépôt : https://github.com/uditgoenka/autoresearch
- Origine : https://github.com/karpathy/autoresearch
