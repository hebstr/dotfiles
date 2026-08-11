# Ancrage des notes de design : symbole plutôt que ligne

Décision différée (2026-08-10), issue d'un `/workflow:sync` sur `eds-prise`.
Rien n'est écrit dans `claude/.claude/CLAUDE.md` ni dans `claude/.claude/memory/`.
Elle existe pour que l'arbitrage n'ait pas à être repris de zéro.

## Constat

Les notes de design d'`eds-prise` (`.claude/DESIGN-*.md`, `.claude/DEFERRED.md`, `.claude/PLAN-*.md`) portaient 109 renvois de la forme `fichier.R:42`.
Un seul passage d'`air` sur `collect/prise_collect-eds.R` et `scripts/_setup.R` en a périmé environ 25 d'un coup, sans qu'aucune gate ne le signale : le formateur déplace les lignes, le renvoi continue de pointer une position qui décrit désormais autre chose.

Le sync a aussi révélé deux défauts qu'un décalage de lignes ne produit pas, et que la vérification des renvois a fait tomber :

- `DESIGN-COLLECT.md` décrivait un bug `pat_cs_ortho` corrigé depuis par `7a036cd`, envoyant chercher un défaut inexistant.
- `DESIGN-TTE.md` citait les bonnes lignes du mauvais fichier (`prise_collect-cache.R:67-69` pour du contenu de `prise_collect-eds.R`), erreur qui survit aux relectures parce que les numéros paraissent plausibles.

## Ce qui est déjà fait

63 renvois convertis dans les cinq `DESIGN-*.md` et `DEFERRED.md` d'`eds-prise`, forme retenue : symbole plus fichier, sans numéro.

  | Avant                                            | Après                                                          |
  | ------------------------------------------------ | -------------------------------------------------------------- |
  | `conn$from$eds$sej` (`prise_collect-eds.R:139-169`) | `conn$from$eds$sej` (`prise_collect-eds.R`)                    |
  | le filtre `RDV_D_RDV <= collect_cache` de `:119` | le filtre `RDV_D_RDV <= collect_cache` de `conn$from$eds$pat_cs_epaule` |
  | `collect-eds.R:194-198`                          | `conn$from$eds$doc`, filtre `TYPE_DOC`/`TITRE`                 |

Une clause au milieu d'un pipeline n'a pas de symbole propre : elle se nomme par son symbole porteur plus la clause.
Critère de validation appliqué : `rg '<symbole>' <fichier>` retrouve la cible pour chacun (30 symboles distincts, 30 OK).

Deux classes de renvois gardent leur numéro à dessein :

- ceux épinglés à un commit (« au commit `c6e5b96`, `prise_collect-eds.R:16` faisait ... »), que `git show c6e5b96:<fichier>` restitue exactement, donc déjà stables ;
- ceux dans du texte barré ou une entrée close, où le numéro documente l'état au moment du constat.

## Ce qui reste différé

Porter la convention dans `claude/.claude/CLAUDE.md` ou dans un fichier de `claude/.claude/memory/`, en portée globale : elle vaut dans tout projet où des notes de design pointent du code.

Motif du report : rien ne presse tant qu'`eds-prise` est le seul dépôt concerné et que ses notes sont converties.
Le risque assumé est la régression silencieuse, la convention n'étant portée que par l'exemple des fichiers déjà convertis.

## Ce qui est écarté, et pourquoi

Un hook `prek` refusant tout `fichier.R:N` nouvellement introduit dans les notes de design.
Deux raisons, la première suffisante :

1. `.claude/` est gitignoré dans `eds-prise` (`.gitignore:38`, zéro fichier suivi). Un hook pre-commit ne se déclenche pas sur des fichiers que git ne voit jamais. Le dépôt a pourtant un `prek.toml` fourni (air, jarl, ruff, pyrefly, shellcheck, shfmt, sqlfluff) : l'obstacle est le périmètre de git, pas l'absence de plomberie.
2. Même monté ailleurs, il viserait à côté. Il bloquerait l'introduction de nouveaux renvois, alors que la panne observée porte sur des renvois existants que le formateur périme. Les 25 cassés du sync étaient tous anciens.

## À la reprise

Trancher entre `CLAUDE.md` global et fichier mémoire, puis écrire la règle en trois points : ancrer sur le symbole, nommer le symbole porteur plus la clause quand il n'y a pas de symbole propre, ne garder un numéro que s'il est épinglé à un commit.
Proposer `/audit:blindspot` sur le fichier modifié, la règle touchant tous les projets.
