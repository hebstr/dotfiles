# pdf-inspector : intégrer ou non dans le process de lecture PDF

2026-08-20. Décision demandée : faut-il câbler `pdf-inspector` dans les instructions globales du harness Claude, et sous quelle règle de routage.

## Reformulation

La demande initiale ("est-ce que cet outil est intéressant à intégrer") n'est pas décidable telle quelle : elle mélange trois questions dont les réponses divergent.

1. `detect-pdf` (classification texte/scanné, pages à router vers l'OCR, pages avec tableaux ou colonnes) remplace-t-il l'étape de reconnaissance actuelle, qui se limite à `pdfinfo` ?
2. `pdf2md` (conversion Markdown) remplace-t-il `pdftotext -layout` comme extracteur par défaut ?
3. L'intégration crée-t-elle une charge de maintenance qui n'existe pas aujourd'hui ?

Ce que "done" veut dire ici :

- une réponse par question, appuyée sur des mesures faites sur le corpus PDF réel de la machine, pas sur le benchmark du README ;
- une règle de routage exprimable en trois lignes, applicable sans jugement au cas par cas ;
- l'identification explicite de ce que l'outil ne couvre pas, pour ne pas croire un trou comblé.

Hors périmètre : l'OCR (traité en fin de note comme problème distinct), les bindings Python et Node, la brique WASM.

## L'outil

Vérifié le 2026-08-20 : dépôt `firecrawl/pdf-inspector`, licence MIT, Rust, `v1.15.0` sur crates.io (151 036 téléchargements), dernier push le 2026-08-19. Installé par `cargo install pdf-inspector --locked`, ce qui déploie trois binaires : `pdf2md`, `detect-pdf`, `dump_ops`.

Le build par défaut ne contient pas d'OCR. La feature `ocr` existe mais exige PDFium et ONNX Runtime installés séparément.

## Protocole

Corpus : 25 PDF tirés au hasard dans `~/Documents`, de 1 à 544 pages. Producteurs relevés : PowerPoint (5), Word (7), Qt (3), Skia (2), Acrobat Distiller, Adobe PDF Library dont un article Springer, Ghostscript, PDFCreator, Quartz. Aucun document produit par pdfTeX, donc l'article de revue à deux colonnes composé en LaTeX, cas archétypal, n'est pas représenté : le résultat sur l'ordre de lecture repose sur des deux-colonnes de composition éditoriale. Comparateur : `pdftotext` de poppler, dans ses deux modes, `-layout` et nu.

Quatre métriques, dont trois objectives :

1. volume de sortie en caractères, proxy du coût en tokens ;
2. ordre de lecture, mesuré par la monotonie de la séquence "Question N" sur cinq pages à deux colonnes ;
3. césures non recollées, comptées par `\p{Ll}- \p{Ll}` et `\p{Ll}-\n\p{Ll}` ;
4. fidélité des tableaux produits, inspectée à la main.

## Résultats

### Volume : aucun gain

| Comparaison | Ratio total sur les 25 PDF |
|---|---|
| `pdf2md` contre `pdftotext -layout` | 0,76 |
| `pdf2md` contre `pdftotext` nu | 1,01 |

Le gain de 24 % contre `-layout` mesure le remplissage par espaces de ce mode, pas une qualité de `pdf2md`. Contre `pdftotext` nu, les deux sorties pèsent le même poids. L'argument "moins de tokens" ne tient pas.

### Ordre de lecture : gain décisif

Sur les pages 478 à 482 d'un ouvrage à deux colonnes, séquence des numéros de question extraits dans l'ordre du flux de sortie :

| Outil | Séquence |
|---|---|
| `pdftotext` nu | 4 5 6 7 8 9 10 12 13 14 15 1 2 11 3 7 8 5 9 6 10 4 ... |
| `pdftotext -layout` | 6 4 7 8 5 9 10 11 12 13 14 1 15 2 7 8 3 9 4 5 10 6 ... |
| `pdf2md` | 4 5 6 7 8 9 10 11 12 13 14 15 1 2 3 4 5 6 7 8 9 ... |

`pdf2md` est le seul à restituer une séquence monotone. Les deux modes de `pdftotext` entrelacent les colonnes, ce qui produit un texte dont l'apparence reste plausible alors que l'enchaînement logique est faux : c'est le pire mode d'échec possible pour un document lu par un modèle.

Sur ce corpus, `detect-pdf --analyze` signale des pages multi-colonnes dans 20 des 25 documents. Le problème n'est pas marginal.

### Césures : régression

Nombre de mots restés coupés sur l'ensemble du corpus :

| Outil | Césures non recollées |
|---|---|
| `pdftotext` nu | 11 |
| `pdf2md` | 242 |

Le contrôle écarte l'artefact de mesure : `pdftotext` ne laisse aucune césure sous forme `mot-\nsuite`, poppler recolle en amont. La documentation de `pdf-inspector` annonce la fonction ("Hyphenation | Rejoins words broken across lines"), le corpus la contredit. Effet concret : `déter- minations` au lieu de `déterminations`, ce qui casse toute recherche textuelle sur le mot coupé.

### Tableaux : régression grave sur les diaporamas

La détection heuristique par alignement se déclenche sur des diapositives qui ne contiennent aucun tableau, et fabrique un tableau Markdown qui détruit l'appariement des données. Exemple sur une diapositive de chronologie :

```
|• 1972|HISTORIQUE 1974|Retrait autorisation du HCH 1976 1978|(02/02/1972) 1980|,organochloré ... 1982 1984 1986 1988 1990 1992 1993|
```

Les dates, les libellés et les valeurs se retrouvent répartis dans des cellules sans correspondance. Sur une autre diapositive, le triplet `600 000 / 90 000 / 50 000` est séparé de `accidents du travail / accidents de trajet / maladies professionnelles`, rendant les chiffres inexploitables. `pdftotext -layout` préserve la disposition spatiale, dont l'appariement reste déductible.

Le danger tient au format : un tableau Markdown se lit comme une donnée structurée et fait autorité, alors que son contenu est ici une recomposition arbitraire. Aucune option CLI ne désactive cette heuristique.

Sur les documents linéaires produits par Word ou par un moteur de composition, les tableaux sortis sont corrects.

### Classification : capacité nouvelle

`detect-pdf` n'a aucun équivalent dans l'outillage actuel.

| Document | Pages | Verdict | Temps |
|---|---|---|---|
| Ouvrage Elsevier | 544 | `mixed`, confiance 0,76, OCR pour la page 1 | 132 ms |
| Diaporama Print-To-PDF | 38 | `mixed`, confiance 0,70, OCR pour 5 pages | 6 ms |
| Diaporama PowerPoint | 53 | `text_based`, confiance 1,00 | 14 ms |

Le cas de l'ouvrage de 544 pages est celui qui tranche. L'heuristique actuelle (lancer `pdftotext` et regarder si la sortie est vide) le classait scanné, parce que sa couverture l'est. `detect-pdf` isole la page 1 et confirme que les 543 autres sont extractibles. L'ancienne méthode aurait envoyé un ouvrage entier vers un chemin OCR inexistant.

`--analyze` ajoute `pages_with_tables` et `pages_with_columns`, ce qui permet de cibler une plage de pages avant un appel `Read` coûteux plutôt que de la deviner.

### Vitesse

`pdftotext` reste plus rapide, jusqu'à trente fois sur certains documents (57 pages : 132 ms contre 3 907 ms). Sur le document de 544 pages l'écart s'inverse presque (1 066 ms contre 1 212 ms). Les valeurs absolues restent négligeables devant la latence d'un appel modèle. Ce critère ne départage pas.

## Décision

**Question 1, `detect-pdf` : intégrer.** Capacité nouvelle, sans substitut, sans faux positif observé, coût en dizaines de millisecondes. Elle classe le document ; `pdfinfo` reste la seule source des champs de taille de page, de rotation et de producteur que consomme le point 4.

**Question 2, `pdf2md` : intégrer sous condition, ne pas remplacer `pdftotext`.** Il gagne sur l'ordre de lecture, qui est le mode d'échec le plus dangereux, et perd sur les césures et sur les tableaux fabriqués. Le partage se fait sur le type de document, pas sur une préférence globale.

**Question 3, maintenance : rien à construire.** `sys-update` comporte déjà un module `cargo` qui exécute `cargo install-update -a`, lequel couvre tout binaire installé par `cargo install`. Aucun module dédié, aucune entrée de configuration. C'est le seul point de la note où la réponse est "déjà couvert, on ferme".

### Règle de routage retenue

Appliquée le 2026-08-20 dans `~/.claude/rules/pdf.md`, chargée par la section `## PDF reading` de `~/.claude/CLAUDE.md`. Cette note reste la source des mesures ; le rules-file est la source de la règle, et c'est lui qu'il faut modifier, pas ce paragraphe.

1. Systématiquement, `detect-pdf <f> --analyze --json` en premier. Il donne le type, les pages sans texte, les pages à colonnes et les pages à tableaux, en une seule passe.
2. Recherche ciblée dans un document texte : `pdftotext` nu, filtré par `rg`. Inchangé.
3. Lecture suivie d'un document linéaire ou multi-colonnes (article, rapport, ouvrage, thèse) : `pdf2md --raw`, pour l'ordre de lecture et les titres.
4. Diaporama, ou page dont la disposition spatiale porte le sens : `pdftotext -layout`, jamais `pdf2md`.
5. Pages dont l'entrée `ocr_reasons_by_page` vaut `scanned`, ou besoin de voir les figures : outil `Read` natif sur la plage de pages concernée. Les deux autres raisons, `suspected_garbled_text` et `vector_text`, laissent une couche texte en place : extraire la page avec `pdftotext` d'abord, et ne rendre l'image que si le retour est inexploitable ou visiblement incomplet.

Le critère du point 4 est l'union de deux sondes `pdfinfo`, et les deux moitiés portent : largeur de page supérieure à la hauteur une fois `Page rot` replié, OU `Creator` / `Producer` nommant PowerPoint, Impress, Keynote ou Google Slides. Aucune des deux ne suffit seule. Un diaporama exporté via Chrome annonce `Skia/PDF` et un diaporama imprimé depuis PowerPoint annonce `Microsoft: Print To PDF` : le test sur le producteur les manque tous les deux, dont précisément le diaporama ATMP qui a servi à documenter la corruption de tableaux. Inversement il existe des diaporamas PowerPoint en portrait, que le test d'orientation manque. Sur les 154 fichiers de `~/Documents`, l'union signale 55 documents : majoritairement des diaporamas, le reste des figures, posters et formulaires en paysage. Biaiser vers le signalement : un document signalé à tort ne perd que le reflow d'ordre de lecture, un diaporama manqué voit ses données brouillées.

### Avertissement d'usage

`detect-pdf` échantillonne 8 pages par défaut. `pages_needing_ocr` est donc une liste issue de l'échantillon, jamais un inventaire exhaustif : sur l'ouvrage de 544 pages, 8 pages ont été inspectées. À traiter comme un signal de routage, pas comme un décompte.

Le champ `title` du JSON sort parfois mal encodé (`Sant� publique`). Ne pas s'en servir pour nommer un fichier.

## Ce qui reste non couvert

L'OCR. Le build par défaut n'en a pas, et la feature `ocr` réclame PDFium et ONNX Runtime installés à part. Un PDF réellement scanné reste traité par l'outil `Read` natif, page par page. `pdf-inspector` améliore ce cas sur un seul point : il dit désormais quelles pages en relèvent, au lieu de laisser deviner.

Si ce trou devait être comblé un jour, `ocrmypdf` avec `tesseract-ocr-fra` reste le chemin le plus court, et il est indépendant de la présente décision.
