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
Rien à committer : le dire et s'arrêter.

## 2. Découper

Un commit par sujet indépendant. Ce qui ne tient pas seul part ensemble : un changement et son test, un renommage et ses appels, une entrée de CHANGELOG et ce qu'elle décrit.

Deux sujets qui partagent un fichier ne se séparent pas par chemin : proposer un commit unique, ou nommer le fichier qui demande `git add -p`.
Un fichier non suivi est nommé, avec l'avis d'inclure ou non ; jamais de balayage.
Un fichier dont le nom évoque un secret (`.env*`, `credentials*`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`) n'entre dans aucun staging proposé : le signaler.
Un contenu déjà stagé est signalé, puisqu'il partira avec le premier commit.

## 3. Rendre

Les blocs, dans l'ordre d'exécution, chacun avec sa commande de staging puis `git commit -m "<en-tête>"`.
Signaler en une ligne ce qui manque visiblement au diff, par exemple l'entrée de CHANGELOG d'un changement visible quand le dépôt en tient un, sans l'ajouter soi-même.

## Après

Quand l'utilisateur annonce que c'est fait, vérifier avec `git log --oneline -<n>` et `git status --short` que la séquence a produit ce qui était proposé.
