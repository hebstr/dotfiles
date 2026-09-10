---
name: relire
description: Relecture assistée d'un document rédigé, section par section et point par point, invoquée par `/relire <section>`.
disable-model-invocation: true
---

# Relecture assistée d'une section

## Unité et périmètre

Le document est celui que l'invocation désigne ; à défaut, le document rédigé du projet, que son `CLAUDE.md` désigne.
L'unité est la section de deuxième niveau, ou la sous-section quand la section dépasse une trentaine de lignes de source.
Le titre le plus profond que le document porte est le plancher : sous lui, l'unité reste entière quelle que soit sa longueur, et le relevé annonce ses bornes en s'ouvrant.
Jamais la phrase, jamais le document entier.

Un titre passé en argument qui désigne plusieurs sections du document se lève auprès de l'utilisateur avant le relevé, jamais par choix du niveau ou de l'ordre d'apparition.

Avant le relevé, lire la section en entier sur le disque, plus ce dont elle dépend : l'amont du document, le plan du projet, les notes de design des chantiers que la section engage et que la table du plan nomme, et l'aval quand un déplacement est envisagé.
L'aval se consulte pour savoir où un énoncé déplacé atterrirait et s'il y ferait doublon, jamais comme texte validé.

## Temps 1, le relevé

Une réponse qui ne contient aucune édition.

Une liste numérotée, un point par défaut : où il est, ce qu'il est, ce qu'il coûte au lecteur.
Triée du fond vers la forme, contradictions et énoncés sans consommateur d'abord, répétitions et ponctuation ensuite.
Close par une recommandation d'ordre de traitement, et par les questions de fond qui demandent une réponse de l'utilisateur avant toute édition.

Un point dont la correction dépend d'un fait inconnu est une question, pas une proposition.

Avant toute édition, prendre l'inventaire des expressions en ligne du moteur de calcul portées par la section, sur l'arbre de travail et jamais sur le dernier commit, qui prend du retard dès qu'un tour n'est pas commité.

## Temps 2, les éditions

Un point par réponse, validé par l'utilisateur avant le suivant, et le minimum d'appels `Edit` que le point exige : un le plus souvent, deux quand il porte sur deux sites.
Une phrase d'intention avant l'appel, jamais de diff en prose : la permission affiche le diff.

L'utilisateur réécrit le fichier entre les tours, souvent en reprenant autrement ce qui vient d'être appliqué.
Relire la zone sur le disque avant chaque édition, ne jamais composer un `old_string` de mémoire, et ne pas re-proposer ce qu'il vient de reprendre à sa façon.

Un déplacement d'énoncé d'une section à l'autre est atomique : le retrait et l'arrivée dans la même réponse, sinon l'argument disparaît sans atterrir.

## Critères

Les critères propres au projet vivent dans son `CLAUDE.md` et dans ses notes de design : les y lire à l'invocation, ne pas les recopier ici, la duplication créant une seconde source de vérité qui dérive.

S'y ajoutent les critères de relecture, qui valent pour tout document rédigé.

- Ce qu'une section décrit et ce qui la justifie ne se mêlent pas : une phrase de justification logée dans une section descriptive se déplace, elle ne se supprime pas.
- Une contradiction entre deux passages est un défaut de fond, même quand chacun se défend isolément : la signaler avec ses deux localisations.
- Un terme employé sans avoir été introduit est un défaut, y compris quand il vient d'une note de design où il va de soi.
- Un membre de phrase qu'aucune mesure et aucune section n'utilise est un reliquat d'un état antérieur : proposer le retrait.
- Une redite dont le second membre vit hors de l'unité ne s'arbitre pas depuis l'unité : la signaler comme question, avec ses deux localisations, et la trancher au tour qui atteint le second membre.
- Une phrase qui annonce ce que la suivante va dire, un connecteur qui pose une opposition inexistante, une anaphore qui remonte par-dessus une frontière de paragraphe, un terme répété dans un même paragraphe.

## Vérification

Aucun fait affirmé sans l'avoir vérifié dans le tour même : recherche dans le dépôt, lecture du script ou du fichier de déclaration concerné, recherche web pour un fait externe.
Une valeur que le document publie se lit sur la sortie rendue et jamais sur la source, qui porte l'expression et non son résultat ; quand cette sortie est absente ou périmée, la valeur est une question, pas une affirmation.
Quand la vérification est impossible, le dire et poser la question plutôt que d'écrire une formulation plausible.

## Temps 3, la clôture de section

Le linter de prose du projet doit sortir en 0.
Comparer les expressions en ligne du moteur de calcul à l'inventaire pris au Temps 1, au caractère près : identiques, sauf écart annoncé et justifié dans le tour.
Un compte ne suffit pas, un renommage à nombre constant y passe au vert.
Ne relancer le render que si une expression, un script ou un renvoi croisé a bougé ; une passe de prose seule ne le demande pas.

Faire les greps de cohérence quand un titre, un objet ou un chemin a changé, et vérifier qu'aucun renvoi ne casse.

Un contrôle qui ne passe pas laisse la section ouverte : sa cause revient en point de Temps 1, et l'entrée de plan le dit plutôt que d'annoncer une clôture.

L'utilisateur arrête où il veut, la liste n'a pas à être épuisée.
Écrire l'entrée dans le plan du projet dans la même réponse : les points appliqués, ceux qui restent ouverts, et tout énoncé descendu dans un autre document, faute de quoi la mise à jour de ce document se perd.
Puis re-vérifier chacune de ses affirmations contre le fichier et contre les commandes : les comptes, les titres, les objets cités par nom.

## Ce que la passe ne fait pas

Pas de verdict par phrase, pas de grille à remplir, pas de journal par verdict : la cérémonie se règle sur les défauts trouvés, pas sur la longueur du texte.

Pas d'édition dans la réponse qui propose.

Pas de relevé sur une section sans matière rédigée : le dire, et proposer d'en écrire le fond plutôt que de juger un titre.

Pas d'écriture dans les fichiers de travail personnels de l'utilisateur, qui se lisent et se citent mais n'appartiennent pas à la passe.
