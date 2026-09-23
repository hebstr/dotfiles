---
name: commit
description: À invoquer avant toute proposition de commit, demandée par l'utilisateur ou spontanée, avant d'écrire le moindre `git commit`, et pour clore une session, par le modèle lui-même dès que toutes les tâches de la session sont faites, sans renvoyer l'utilisateur à `/commit` ni lui demander s'il faut la lancer. Aussi quand un hook Stop (`commit-gate.sh`, `ending-gate.sh`) le demande.
---

# Proposition de commit

La skill clôt le travail en cours puis rend une proposition de commit fondée sur l'état réel du dépôt.
Elle ne lance aucune commande git d'écriture : l'utilisateur committe lui-même (section Git de `~/.claude/CLAUDE.md`).
Aucun bloc `git commit` ne s'écrit hors de cette skill : le hook `Stop` `commit-gate.sh` bloque une réponse qui en contient un quand du code a été écrit depuis le dernier passage du vérificateur.

## 0. Clore

Dans cet ordre, sans en sauter.

### 0.1 Vérificateur

1. Lire le journal de la session et les fichiers modifiés du dépôt, et prendre la valeur du tampon **avant** de lancer l'agent :

   ```bash
   journal="${XDG_RUNTIME_DIR:-/tmp}/claude-code-writes-${CLAUDE_CODE_SESSION_ID}.log"
   stamp_file="${journal%.log}.stamp"
   stamp_value=$(date +%s%N)
   top=$(git rev-parse --show-toplevel)
   printf 'JOURNAL=%s\nSTAMP_FILE=%s\nSTAMP_VALUE=%s\n' "$journal" "$stamp_file" "$stamp_value"
   { cut -f2 "$journal" 2>/dev/null; git -C "$top" status --porcelain=v1 -z --no-renames --untracked-files=all | while IFS= read -r -d '' e; do printf '%s/%s\n' "$top" "${e:3}"; done; } | sort -u
   ```

   La liste unit le journal et `git status`, parce que le journal ne voit ni les écritures d'une session antérieure à un `/clear` (l'id de session change), ni celles faites en Bash ou à la main.
   L'état du shell ne survit pas d'un appel Bash à l'autre : les commandes des étapes suivantes reçoivent ces trois valeurs recopiées telles qu'affichées, à la place de `<JOURNAL>`, `<STAMP_FILE>` et `<STAMP_VALUE>`.
   Liste vide : aucune écriture dans la session et un arbre propre, passer à 0.2.
   `CLAUDE_CODE_SESSION_ID` vide : le dire, et lancer quand même le vérificateur sur les fichiers que `git status` montre, sans tampon ; la porte bloquera de nouveau au prochain rendu de blocs hors de la continuation qu'elle a déclenchée, où le marqueur qu'elle a écrit en bloquant la fait sortir en 0, ce qui est le comportement voulu.
2. Lire `agents/verifier.md` (à côté de ce fichier) et lancer un agent `general-purpose` **au premier plan**, dont le prompt est ce fichier suivi de `REPO` (la racine git), `WRITES` (la liste ci-dessus), `STAMP_FILE` et `STAMP_VALUE`.
   Un contexte neuf est la raison d'être de l'étape : ne pas lui transmettre de résumé de la session, ni d'avis sur ce qui est à jour.
3. Appliquer ses constats par Edit, un par un, après avoir vérifié chacun : un constat que la vérification dément est écarté, et nommé comme tel.
   Un constat qui demande de modifier du code, et non du tracking, n'est pas appliqué d'office : le signaler à l'utilisateur.
4. Vérifier que le tampon est écrit (`cat '<STAMP_FILE>'` égal à `<STAMP_VALUE>`). Sinon, l'écrire soi-même avec la même valeur, en le disant.
   Si l'étape 3 a appliqué au moins un constat, lister les chemins journalisés après `<STAMP_VALUE>` et ceux de `git status` modifiés après lui, les deux sources que lit la porte :

   ```bash
   top=$(git rev-parse --show-toplevel)
   { { while IFS=$'\t' read -r ts p; do ((ts > <STAMP_VALUE>)) && printf '%s\n' "$p"; done <'<JOURNAL>'; } 2>/dev/null; git -C "$top" status --porcelain=v1 -z --no-renames --untracked-files=all | while IFS= read -r -d '' e; do p="$top/${e:3}"; m=$(stat -c %.9Z -- "$p" 2>/dev/null) && ((10#${m/./} > <STAMP_VALUE>)) && printf '%s\n' "$p"; done; } | sort -u
   ```

   Si chacun de ces chemins est un fichier de tracking visé par un constat appliqué, réécrire le tampon (`date +%s%N >'<STAMP_FILE>'`), sans quoi la porte déclarerait périmés les blocs rendus juste après ces corrections.
   Si au moins un chemin sort de ce cas, garder le tampon tel quel et nommer ce chemin à l'utilisateur : la porte ne rebloque pas dans la continuation qu'elle a déclenchée (le marqueur qu'elle a écrit en bloquant), et ne bloquera qu'au prochain rendu de blocs hors de celle-ci, ce qui est voulu.

Ce passage ne remplace pas la vérification que la session doit à chaque écriture de tracking ; il attrape ce qu'elle a laissé passer.

### 0.2 Suite ou clôture

Une recommandation sur la suite, en une phrase et sa raison en une ligne, ou l'indication explicite qu'il n'y a rien à poursuivre et que la session peut se clore.
Quand un fichier de tracking (PLAN, note de chantier) nomme l'étape suivante, la recommandation part de lui.

### 0.3 Revue

`git diff --numstat HEAD` pour les fichiers suivis, `git ls-files --others --exclude-standard` puis `wc -l` pour les fichiers nouveaux.
Proposer `/audit:walkthrough <fichier> --reviewer posit-dev:critical-code-reviewer` seulement pour un fichier de code exécutable nouveau ou changé d'au moins 30 lignes (ajouts plus suppressions).
Code exécutable : un langage de programmation (shell, Python, R, Rust, JS/TS, SQL, Lua, CSS/SCSS, Typst, Perl, bats), ou un fichier sans extension qui porte un shebang. Jamais la mémoire, `CLAUDE.md`, `rules/`, un `SKILL.md` ni un fichier de configuration : l'utilisateur lance ces revues quand il les veut.
Pas davantage pour un fichier qu'un `/audit:walkthrough` ou un `/audit:blindspot` a traité dans la session : ses corrections ferment le cycle de revue, et en proposer une nouvelle relance la boucle.
Prose destinée à un lecteur (README, CHANGELOG, documentation publiée) nouvelle ou réécrite : proposer `/workflow:write <fichier>`.
Ni l'un ni l'autre : ne rien proposer, sans le commenter.
Les deux skills sont invocables par l'utilisateur seul : donner la commande, ne pas l'invoquer.

### 0.4 Blocs

Les sections 1 à 3.

## 1. Lire l'état réel

- `git status --short`, qui montre aussi les fichiers non suivis.
- `git diff --stat` et `git diff --cached --stat`, puis le diff lui-même, pour qualifier chaque changement.
- `git log --format=%s -15`, pour les types et les scopes en usage.

La proposition repose sur ce que le diff montre, jamais sur le souvenir de la conversation : une modification faite à la main par l'utilisateur compte autant qu'une édition de la session.
Un fichier édité pendant la session et absent de `git status` passe par `git check-ignore` : ignoré, il est signalé comme tel et n'entre dans aucun staging, puisque `git add` sur un chemin ignoré échoue et casse la suite de la séquence.
Rien à committer : le dire et s'arrêter.

## 2. Découper

Un commit par sujet indépendant. Ce qui ne tient pas seul part ensemble : un changement et son test, un renommage et ses appels, une entrée de CHANGELOG et ce qu'elle décrit.

Deux sujets qui partagent un fichier ne se séparent pas par chemin : proposer un commit unique, ou nommer le fichier qui demande `git add -p`.
Un fichier non suivi est nommé, avec l'avis d'inclure ou non ; un seul avis contraire exclut `git add .` du commit qui le côtoie.
Un fichier dont le nom tombe dans la portée « Secret files handling » de `CLAUDE.md` n'entre dans aucun staging proposé : le signaler. La liste y est tenue à jour ; la recopier ici la ferait diverger au prochain edit de l'une ou de l'autre.
Un contenu déjà stagé est signalé, puisqu'il partira avec le premier commit.

## 3. Rendre

Chaque proposition de commit, demandée ou spontanée, porte son message :

- l'en-tête seul, sans corps, au format Conventional Commits (`type(scope): sujet`), le scope repris du `git log` récent quand le dépôt en utilise un ;
- chaque commit dans son propre bloc délimité étiqueté `bash`, qui contient sa commande de staging puis la ligne complète `git commit -m "<en-tête>"` ; jamais l'en-tête seul, jamais une commande en code inline ou en prose ;
- plusieurs commits : les blocs dans l'ordre d'exécution, pour que chacun s'exécute tel qu'écrit ;
- chaque chemin stagé vient de `git status`, jamais de ce que la session se souvient d'avoir édité ;
- `git add .` depuis la racine quand le commit prend tout ce que `git status` montre et qu'aucune commande antérieure de la séquence ne modifie `.gitignore` ni ne lance `git rm --cached` ; sinon des chemins explicites ou `git add -u`, jamais `git add -A` (voir `feedback_commit_sequence_add_all.md`).

Signaler en une ligne ce qui manque visiblement au diff, par exemple l'entrée de CHANGELOG d'un changement visible quand le dépôt en tient un, sans l'ajouter soi-même.

Quand la porte de commit a bloqué la réponse précédente, dire en tête que les blocs déjà affichés sont périmés et ne doivent pas être lancés, puis rendre les nouveaux.

## Après

Quand l'utilisateur annonce que c'est fait, vérifier avec `git log --oneline -<n>` et `git status --short` que la séquence a produit ce qui était proposé.
