---
name: cadrer
description: Cadrage d'une suggestion d'implémentation avant tout code, invoqué par `/cadrer <suggestion>`.
disable-model-invocation: true
---

# Cadrage d'une suggestion d'implémentation

L'invocation reçoit une idée d'implémentation, plus ou moins formée, et rend une décision arbitrée.
La suggestion est celle que l'invocation porte ; à défaut, celle que la conversation vient de poser, la reformulation de l'étape 1 exposant un mauvais choix avant qu'il coûte quoi que ce soit.
Elle n'écrit aucun code et ne crée aucun fichier hors la note. Elle s'arrête sur l'accord de l'utilisateur.

La conversation se mène dans la langue de l'utilisateur.
Deux familles de cas écartent le cadrage complet : trois sorties qui se constatent à l'entrée, avant l'étape 1, et trois abrègements qui se constatent aux étapes 1, 2 et 3. Lire « Quand le cadrage complet ne s'applique pas » avant de commencer.

## 1. Reformuler

Restituer la demande en quelques lignes, dans d'autres mots que les siens : reprendre sa formulation ne prouve rien, la reformuler expose ce qui a été compris de travers.

Nommer ensuite ce que la demande laisse indéterminé, et pour chaque point, trancher entre deux traitements.
Une ambiguïté est bloquante quand deux lectures conduisent à des travaux différents : là, poser la question et ne rien proposer avant la réponse.
Tout le reste avance sous hypothèse explicite, énoncée comme telle.
Un indéterminé qu'une lecture ou une commande en lecture seule tranche n'est pas une hypothèse : l'étape 2 le tranche, et la proposition en donne la réponse.

Une demande qui ne laisse rien d'indéterminé existe ; le dire alors, plutôt que fabriquer une ambiguïté pour remplir la rubrique.

## 2. Lire avant de proposer

Le critère d'idiomaticité n'a de sens que rapporté à un référent, et le référent est le dépôt, pas le goût général.

Avant d'ouvrir la moindre voie : lire les fichiers que la suggestion touche, et chercher le précédent, c'est-à-dire la façon dont une chose comparable est déjà faite ici.
Vérifier au passage si la capacité existe déjà, sous forme d'un helper interne ou d'une fonction d'une dépendance déjà déclarée. Ne rien trouver sur le disque ne ferme rien : cela établit l'absence dans les dépendances courantes, jamais dans l'écosystème.

Quand le dépôt ne porte aucun précédent pour ce type d'artefact, la convention est probablement établie dans un projet voisin plutôt qu'absente : le dire, nommer le candidat trouvé ou demander lequel prendre pour modèle, et ne pas en inventer une localement.

Lire aussi, en entier, les notes du chantier concerné (son fichier de plan `PLAN*.md`, ses notes `.claude/DESIGN-*.md` ou `_meta/notes/`) et l'entrée de plan correspondante : une décision antérieure ne vit pas dans les scripts, et c'est elle que l'étape 5 demande de constater renversée.

## 3. Ouvrir plusieurs voies

Deux à quatre, sans que le nombre fasse quota : si une seule tient, le dire et dire ce qui condamne les autres.

Deux voies sont distinctes quand la responsabilité y vit à un endroit différent. Un nom qui change, un argument de plus, un drapeau : c'est une variante, et deux variantes d'un même mécanisme comptent pour une voie.

« Ne rien faire » est une voie de plein droit dès qu'un mécanisme déjà en place couvre le besoin, et elle l'emporte par défaut quand c'est le cas. Une fonctionnalité sans consommateur est une métadonnée morte.

Chaque voie porte trois choses et pas davantage : le mécanisme en deux phrases, ce qu'elle coûte (une dépendance, un couplage, une charge d'entretien, un fichier de plus que le lecteur doit connaître), et ce qu'elle interdit plus tard.

## 4. Trancher

Une recommandation, jamais une liste laissée ouverte.

Idiomatique se lit dans cet ordre : conforme à un précédent de ce dépôt, à défaut à l'idiome de la pile, à défaut à celui de la bibliothèque dominante du domaine.
Citer le précédent par son nom, fichier plus objet ou fichier plus section, plutôt qu'affirmer la propriété.

Quand la voie recommandée n'est pas la plus robuste, dire ce qu'elle échange contre quoi.
Nommer enfin l'hypothèse la plus fragile sur laquelle elle repose : « cela tient tant que X ; si X tombe, Y ».
Quand un test sans effet de bord la vérifie (commande en lecture seule, essai dans le scratchpad), le lancer avant de recommander et en donner le résultat ; sinon la déclarer non testée. Une sonde à effet de bord, processus lancé ou machine distante, se demande avant.

Une voie qui suppose une dépendance nouvelle ne se choisit pas seul : elle se propose, chiffrée à une dépendance de plus, avec l'alternative sans elle à côté.

## 5. La note, ou pas

La note s'écrit après la validation de l'utilisateur, jamais avant.

Écrire une note quand au moins une de ces trois conditions tient : la décision contraint les sessions suivantes, elle renverse une décision antérieure, ou les voies écartées seraient reproposées par quiconque n'a pas assisté à cette conversation.
Dire en une ligne laquelle tient ; sinon l'arbitrage reste dans la conversation, et le dire aussi, avec la raison, plutôt que le passer sous silence.

Emplacement : la note du chantier quand elle existe, `.claude/DESIGN-<SUJET>.md` quand rien ne couvre le sujet.
La note suit la langue des notes du projet.

Ce que la note porte : la décision en tête, la raison, les voies écartées avec ce qui condamne chacune, et les points laissés ouverts nommés comme ouverts, aucun tranché par défaut.
Les titres de section affirment au lieu d'étiqueter.
Le code et la prose se citent par leur nom, jamais par numéro de ligne, selon la règle « Cite by name » du `CLAUDE.md` global.
Les dates sont absolues.

## Arrêt

Aucun code, aucun échafaudage, aucun pseudo-code, aucun fichier hors la note : le cadrage ne produit rien de tout cela, avant validation comme après. L'essai jetable de l'étape 4 reste dans le scratchpad, qui ne compte pas comme un fichier du projet.
La validation est explicite : ni le silence, ni un accord donné sur un point de détail ne la constituent.
La question qui la demande nomme la voie, et sépare chaque décision que la proposition regroupe, pour qu'un accord ne couvre que ce qu'il nomme.
Elle déclenche l'écriture de la note quand l'étape 5 la retient, et clôt le cadrage là. L'implémentation demande une instruction neuve, et relève du socle global à partir de là.
La réponse de clôture finit sur la suite recommandée, implémenter maintenant ou dans une conversation neuve, et l'accord donné à cette suite est l'instruction neuve.

Un refus rouvre l'étape 4 sur les voies déjà ouvertes. Quand elles sont toutes refusées, l'étape 3 rouvre et les refus deviennent sa matière : ce qu'ils écartent borne les voies neuves. Les étapes 1 et 2 ne se refont que si la demande elle-même a changé.

## Quand le cadrage complet ne s'applique pas

Le cadrage arbitre entre plusieurs façons d'implémenter une suggestion. Ce qui n'appelle pas cet arbitrage en sort avant l'étape 1, et ce qui l'appelle à peine reçoit une réponse abrégée.

### Sortir avant l'étape 1

Trois cas, constatés à l'entrée sur l'invocation, la conversation et un grep ciblé du sujet dans les fichiers `.claude/*.md` et `_meta/notes/` du projet :

- la décision existe déjà, dans une note, une entrée de plan ou plus haut dans la conversation : la citer par son nom et demander si l'invocation la rouvre. Une réouverture confirmée lance le cadrage complet, et l'étape 5 retient alors la note au titre de la décision renversée ;
- aucune suggestion ne se dégage, ni de l'invocation ni de la conversation : demander laquelle cadrer, sans en construire une ;
- la demande relève d'autre chose qu'un arbitrage d'implémentation, par exemple un bug à corriger, une question d'explication, une recommandation qui tient à des sources externes (`/workflow:reco`) ou un travail d'analyse de données : dire en une ligne pourquoi, nommer ce qui convient, et s'arrêter.

Une sortie signale et rend la main sans refuser : l'utilisateur a invoqué le cadrage délibérément, et sa confirmation le lance tel quel.
Un sujet dont aucune note ne porte le nom échappe au grep ; la décision antérieure ne se découvre alors qu'à l'étape 2, qui la traite comme matière du cadrage.

### Abréger

Ramener la réponse à un paragraphe, recommandation et risque unique, dans trois cas : la demande est un correctif ou une édition que l'utilisateur a lui-même cadrée ; l'étape 2 montre que la capacité existe déjà et qu'elle couvre le besoin en entier, et la réponse est alors « déjà couvert, on ferme », qui est une issue de plein droit, une couverture partielle relevant au contraire du cadrage complet où « ne rien faire » concourt avec les voies qui feraient mieux ; une seule voie tient et son coût est négligeable.

Dire que la réponse est abrégée, et pourquoi.

## Ce qui vient avant

`ouroboros:interview` d'abord, sur les critères du socle global. La résistance se constate à n'importe quelle étape et suspend le cadrage, qui reprend sur la réponse : constatée à l'étape 1 elle ne coûte rien, plus tard la reprise recommence les étapes que la réponse invalide.
La décomposition en fonctionnalités ordonnées par dépendances ensuite, quand la demande couvre plusieurs chantiers imbriqués.
Ces deux étapes alimentent le cadrage : les lancer après lui impose de le refaire.

## Ce qui vient après, et que ce cadrage ne fait pas

La barrière lint, format, test du langage concerné, les greps de cohérence post-changement et la proposition de revue adverse relèvent du socle global et s'appliquent à l'implémentation, une fois la décision validée. Ne pas les redire ici.
L'entrée de plan qui consigne la décision validée relève du même socle : le critère « aucun fichier hors la note » borne le cadrage, il ne suspend pas la tenue du plan.

## Ce que « fini » veut dire

Pour un cadrage complet :

- La reformulation nomme au moins un indéterminé de la demande, ou déclare qu'elle n'en laisse aucun.
- Les fichiers touchés par la suggestion ont été lus, et le précédent local est nommé ou son absence déclarée.
- Chaque voie porte son mécanisme en deux phrases, son coût et ce qu'elle interdit plus tard.
- La recommandation est unique et nomme le référent atteint dans la cascade, précédent du dépôt cité par son nom, à défaut idiome de la pile, à défaut bibliothèque dominante.
- L'hypothèse la plus fragile de la voie retenue est énoncée, et testée ou déclarée non testée.
- La décision d'écrire ou non une note est motivée en une ligne.
- Aucun fichier hors la note n'a été touché.

Pour une réponse abrégée : le motif de l'abrègement est dit, la recommandation et son risque unique sont énoncés.

Pour une sortie : le cas est nommé, la décision existante citée par son nom quand c'est elle qui motive la sortie, et aucune étape du cadrage n'a été engagée.
