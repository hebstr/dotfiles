---
name: depouiller
description: Dépouillement point par point des commentaires qu'un relecteur a portés sur un `.docx`, invoqué par `/depouiller <docx>`.
disable-model-invocation: true
---

# Dépouillement des commentaires d'une relecture Word

L'invocation reçoit un `.docx` commenté par un tiers et rend un registre où chaque commentaire porte une décision de l'utilisateur.
La conversation se mène dans la langue de l'utilisateur ; ce qui s'écrit dans le registre suit la langue des notes du projet, et les libellés posés par le script restent tels quels, puisque le bilan se compte sur eux.

## Unité et périmètre

L'unité est le commentaire, question ou remarque, avec ses réponses rangées sous lui.
Les corrections suivies, les surlignages et tout ce qui relève de la forme sont hors périmètre, sauf demande de l'utilisateur ; ils se citent quand ils éclairent un commentaire, jamais comme points.

La source rédigée n'est pas modifiée pendant la passe : le registre reçoit les décisions, le report dans la source vient après et hors passe.

Sans docx, ou si le script le dit illisible, le demander.
Le registre se crée au chemin que l'utilisateur donne. Sans chemin, le demander, et demander aussi la source rédigée dont le docx est le rendu, s'il y en a une.
Un registre existant ne s'écrase jamais : le script refuse, et `--force` ne se passe que sur instruction explicite, après avoir dit qu'il renumérote et efface les décisions déjà portées. Une nouvelle relecture du même document ouvre un registre à un autre chemin. Un répertoire ignoré par git n'a pas de filet.

## Temps 1, le squelette

Le script pose la liste, sans jugement :

```
uv run --script ~/.claude/skills/depouiller/scripts/squelette.py <docx> -o <registre> [--source <source>]
```

Il transcrit chaque commentaire mot pour mot depuis `word/comments.xml`, range les réponses sous leur racine par `word/commentsExtended.xml`, rétablit l'extrait visé en texte d'origine, suppressions remises et insertions ignorées, et donne la section par les niveaux de plan du document.
Ne jamais recopier un commentaire à la main : `officer::docx_comments()` et `pandoc --track-changes=all` rendent tous deux une réponse comme un commentaire isolé, et une transcription recopiée s'altère sans que rien ne le signale.

Le résumé du script donne le compte des commentaires, des points, des réponses, des points sans ancre, de ceux ancrés hors du corps du document et de ses notes (en-tête, pied de page) et, avec `--source`, des extraits non retrouvés ou ambigus.
Il signale aussi un fichier sans `word/commentsExtended.xml`, où les réponses ne peuvent être rangées et comptent chacune comme un point : le dire à l'utilisateur avant le tri.
Chaque extrait non retrouvé ou ambigu se résout en lisant la source, dans la ligne `**Localisation**` de l'entrée, dont le statut entre parenthèses posé par le script est remplacé par le résultat : un extrait court se complète par la phrase qui le porte, un extrait introuvable se situe par sa section et le dit.

Relever ensuite les commentaires liés, par numéro, dans la section prévue du registre, et les présenter à l'utilisateur : un lien pèse sur ce qu'il écartera.

La numérotation est fixée à ce temps et ne bouge plus.

## Temps 2, le tri

L'utilisateur lit le registre et désigne dans la conversation les entrées qui ne valent pas un tour.
Chacune reçoit, à sa place, `**Décision** : écartée au tri, AAAA-MM-JJ.` à la date de la session, et ses lignes de reformulation et de proposition gardent leur « à établir ».

Ne jamais supprimer une entrée ni renuméroter : les liens, les renvois entre points et le bilan tiennent par les numéros, et un commentaire écarté peut appeler une réponse plus tard.

## Temps 3, la revue

Un point par tour, dans l'ordre, les entrées écartées passées sous silence.

Le tour présente le commentaire transcrit, puis trois choses.

1. **Reformulation et contexte.** Ce que le relecteur demande dans d'autres mots que les siens, et ce qui le justifie ou le dément. Lire avant d'affirmer : la section visée, les passages liés, les notes de design du projet, et la référence citée quand le commentaire la met en cause, dans le PDF lui-même selon `rules/pdf.md`.
2. **Proposition.** Une réponse au relecteur, rédigée sur son ton : s'il écrit bref et informel, la réponse est brève et informelle, au tutoiement s'il tutoie. Elle dit ce qui sera fait, pas comment.
3. **La question de décision** : valider la proposition, telle quelle ou modifiée, sauter le point, ou le reporter.

Un commentaire qui admet deux lectures menant à des réponses différentes les expose et demande laquelle est la bonne, avec une proposition par lecture.

L'entrée ne s'écrit qu'après la décision, dans la même réponse que le tour suivant ou seule : reformulation, proposition et décision, y compris pour un point sauté, dont la matière reste utile.
Vocabulaire de décision, porté par la ligne `**Décision** :` de l'entrée : « proposition validée », que la proposition soit gardée telle quelle ou modifiée, « sauté en revue », avec la mention de ce que l'utilisateur fera lui-même quand il le dit, « reporté », avec l'endroit où la tâche est consignée.

Un report qui demande un travail propre, une recherche de références par exemple, se consigne comme cahier des charges dans la note de design du chantier concerné, que le `CLAUDE.md` du projet ou la table de son plan désigne : ce qui est déjà couvert et vérifié, les questions à instruire, les bornes.

## Vérification

- Un numéro de référence cité par le relecteur se lit sur la bibliographie du rendu relu, jamais sur la source : l'ordre des numéros est celui du rendu.
- L'auteur d'une modification, surlignage compris, se lit dans le XML, `w:rPrChange`, `w:ins` ou `w:del` et leur attribut `w:author`, jamais par déduction d'une absence dans la source.
- Un chiffre que le commentaire met en cause se vérifie contre la référence, et la vérification se dit dans la reformulation.
- Ce que le rendu relu ne montre pas se vérifie aussi : un élément présent dans la source mais absent du docx explique souvent un commentaire.

## Pièges d'écriture

Le formateur Markdown du poste coupe une citation « » après une ponctuation finale et laisse « » » seul en tête de ligne : l'extrait cité s'écrit sans point, point d'interrogation ni deux-points final.
Après chaque écriture, `rg '^»' <registre>` doit rendre zéro.

Relire la zone de l'entrée sur le disque avant chaque `Edit` : le formateur réécrit le fichier entre deux tours.

## Clôture

L'utilisateur arrête où il veut, la liste n'a pas à être épuisée.

Le bilan se compte sur le registre et non de mémoire, par `rg` sur les lignes de décision : validées, sautées, reportées, écartées au tri, et ce qui reste « à prendre ».
Le linter de prose du poste passe sur le registre.
Le bilan entre dans les fichiers de suivi que le `CLAUDE.md` du projet désigne, avec les points ouverts : report des décisions dans la source, reports consignés, points sautés.

## Ce que la passe ne fait pas

Pas d'édition de la source rédigée.
Pas de traitement des corrections suivies hors demande.
Pas de suppression ni de renumérotation d'entrée.
Pas de proposition écrite avant la lecture de ce qu'elle engage, ni de propositions rédigées d'avance pour plusieurs points.
Pas d'écriture d'entrée avant la décision.

## Ce que « fini » veut dire

- Le squelette vient du script, et son résumé est rapporté à l'utilisateur, extraits non retrouvés et ambigus résolus.
- Les commentaires liés sont relevés avant le tri.
- Chaque entrée porte une décision ou reste explicitement « à prendre » parce que l'utilisateur a arrêté.
- Aucune entrée n'est supprimée, la numérotation est celle du temps 1.
- `rg '^»'` rend zéro et le linter de prose passe.
- Le bilan est compté sur le fichier et consigné dans le suivi du projet.

## Entretien du script

Toute modification de `scripts/squelette.py` repasse ses tests, qui fabriquent leurs docx eux-mêmes et ne dépendent d'aucun fichier binaire :

```
uv run --no-project --with pytest pytest ~/.claude/skills/depouiller/scripts/test_squelette.py
```

Un défaut constaté sur un vrai docx s'y reproduit d'abord par un docx minimal, avant la correction.
