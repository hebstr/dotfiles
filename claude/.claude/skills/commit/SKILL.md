---
name: commit
description: Proposition de commit pour le travail en cours du dépôt, invoquée par `/commit`.
disable-model-invocation: true
---

# Proposition de commit

La skill rend une proposition de commit fondée sur l'état réel du dépôt.
Elle ne lance aucune commande git d'écriture : l'utilisateur committe lui-même (section Git de `~/.claude/CLAUDE.md`).
Le format du message et des blocs est celui de la règle « Every commit suggestion carries its message » de cette même section ; la skill fixe la procédure, pas le format.

## 1. Lire l'état réel

- `git status --short`, qui montre aussi les fichiers non suivis.
- `git diff --stat` et `git diff --cached --stat`, puis le diff lui-même, pour qualifier chaque changement.
- `git log --format=%s -15`, pour les types et les scopes en usage.

La proposition repose sur ce que le diff montre, jamais sur le souvenir de la conversation : une modification faite à la main par l'utilisateur compte autant qu'une édition de la session.
Un fichier édité pendant la session et absent de `git status` passe par `git check-ignore` : ignoré, il est signalé comme tel et n'entre dans aucun staging.
Rien à committer : le dire et s'arrêter.

## 2. Découper

Un commit par sujet indépendant. Ce qui ne tient pas seul part ensemble : un changement et son test, un renommage et ses appels, une entrée de CHANGELOG et ce qu'elle décrit.

Deux sujets qui partagent un fichier ne se séparent pas par chemin : proposer un commit unique, ou nommer le fichier qui demande `git add -p`.
Un fichier non suivi est nommé, avec l'avis d'inclure ou non ; un seul avis contraire exclut `git add .` du commit qui le côtoie.
Un fichier dont le nom tombe dans la portée « Secret files handling » de `CLAUDE.md` n'entre dans aucun staging proposé : le signaler. La liste y est tenue à jour ; la recopier ici la ferait diverger au prochain edit de l'une ou de l'autre.
Un contenu déjà stagé est signalé, puisqu'il partira avec le premier commit.

## 3. Rendre

Les blocs, dans l'ordre d'exécution, chacun avec sa commande de staging puis `git commit -m "<en-tête>"`.
Signaler en une ligne ce qui manque visiblement au diff, par exemple l'entrée de CHANGELOG d'un changement visible quand le dépôt en tient un, sans l'ajouter soi-même.

## Après

Quand l'utilisateur annonce que c'est fait, vérifier avec `git log --oneline -<n>` et `git status --short` que la séquence a produit ce qui était proposé.
