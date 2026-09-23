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

**Question 3, maintenance : rien à construire.** `sys-update` comporte déjà un module `cargo` qui exécute `env GGSQL_SKIP_GENERATE=1 cargo install-update -a`, lequel couvre tout binaire installé par `cargo install` (la variable appartient à `ggsql-cli`, un autre crate du même lot, et ne concerne pas `pdf-inspector`). Aucun module dédié, aucune entrée de configuration. C'est le seul point de la note où la réponse est "déjà couvert, on ferme".

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

Les PDF chiffrés restent hors règle, décision du 2026-09-23. Sur les 450 PDF de `~/Documents` et `~/Zotero/storage`, 56 sont chiffrés, tous par un mot de passe propriétaire seul (restrictions de copie), et les trois outils les lisent normalement. Un PDF verrouillé par un mot de passe utilisateur, fabriqué avec `qpdf`, fait échouer les trois en exit 1 avec un message explicite (`PDF is encrypted`, `Incorrect password`). `pdf2md --password` le lit, mais `detect-pdf` n'a aucune option de mot de passe, si bien que la règle 1 ne s'y applique pas. Aucun des 450 fichiers n'est dans ce cas, et l'échec est bruyant : une ligne de règle ne changerait rien à la conduite.

## 2026-09-23 : tableaux des articles scientifiques

La section « Tableaux » d'août reposait sur une inspection à la main, sans document pdfTeX, et concluait que « sur les documents linéaires produits par Word ou par un moteur de composition, les tableaux sortis sont corrects ». Cette section la mesure sur des articles de la bibliothèque Zotero, avec pdf-inspector 1.24.0, et la contredit. Corpus, sorties et comptage cellule par cellule : `~/dotfiles/.claude/pdf-tables-eval/` (`README.md`, `COMPARAISON.md`, `detail-lot-*.md`), non versionné.

### Protocole

- Sélection indépendante de l'outil testé : parmi les 295 PDF de `~/Zotero/storage`, les 188 qui portent une légende « Table N » ou « Tableau N » dans `pdftotext`, stratifiés par producteur (`pdfinfo`), puis 16 articles et 38 tableaux choisis pour varier la langue, la mise en page et la forme. `detect-pdf` n'a été relevé qu'après coup.
- Producteurs : pdfTeX (3 articles), Acrobat Distiller (5), Word (2), Adobe PDF Library (2), PDFlib PLOP, PDFsharp, Antenna House et un PDF retouché par iText (1 chacun). Anglais et français, une et deux colonnes, pages pivotées et en paysage.
- Référence : l'image de la page (pdftoppm puis `Read`), contrôlée par `pdftotext -layout`. L'image l'emporte en cas de divergence.
- Métrique : grille de cellules comptée à la main, proche de GriTS_Con en correspondance exacte, avec appariement un à un des tableaux. TEDS et GriTS supposent des portées de cellules qu'un tableau Markdown ne peut pas exprimer : elles pénaliseraient le format, pas l'outil. Une cellule fusionnée est donc juste si son texte tombe dans l'une des positions qu'elle couvre.
- Fabrication : 4 pages témoins sans tableau, plus un relevé sur toutes les pages des 16 sorties, chaque bloc Markdown étant rattaché à sa page physique par son contenu, puis vérifié sur l'image.
- Comparaison répartie entre 4 agents, un lot de producteurs chacun, avec contrôles par sondage dans le fil principal.

### Résultats

| Mesure | `pdf2md` | `pdftotext -layout` |
|---|---|---|
| Tableaux fidèles / altérés / non détectés | 5 / 25 / 8 sur 38 | sans objet |
| Cellules fausses ou non récupérables | 1 853 / 3 923 (47 %) | 337 / 3 923 (9 %) |
| Même mesure, hors les deux tableaux de Silberzahn | 1 206 / 3 245 (37 %) | 52 / 3 245 (1,6 %) |
| Médiane par tableau | 28 % | 0 % |

- **Aucun producteur n'est sûr.** pdfTeX 44 % de cellules fausses, Distiller 43 %, Word 22 %, Adobe PDF Library 66 %. PLOP (5,5 %) et iText (4 %) restent les plus bas, sur un article chacun.
- **Les tableaux fidèles sont les grilles simples** : une ligne d'en-tête, pas de texte long, pas de prose contiguë. Dès qu'un en-tête s'étage sur deux niveaux, qu'une cellule porte plusieurs lignes, ou qu'une ligne de groupe n'a pas de valeur, les lignes fusionnent (19 tableaux) et les colonnes glissent (14).
- **Les valeurs sont altérées sans bruit.** Les exposants sortent des cellules (`2.3 · 10` dans la cellule, `<sup>19</sup>` sur une ligne après le tableau) ; les valeurs d'une colonne glissent dans la voisine quand une cellule est vide ; la prose et les légendes se collent aux cellules.
- **8 tableaux non détectés**, sortis en prose sans appariement récupérable. Dont les deux pages pivotées de Burlacu et le Tableau 3 de Vaswani.
- **Tableaux fabriqués dans les articles.** Sur 21 pages sans tableau, dans 11 des 16 documents, `pdf2md` émet un tableau Markdown fait de prose à deux colonnes, de pages de titre, d'étiquettes de figure ou de listings de code. Le défaut d'août sur les diaporamas s'étend aux articles, pdfTeX compris.
- **`detect-pdf` ne localise pas les tableaux.** `pages_with_tables` manque au moins une page de 6 tableaux sur 38, liste des pages de texte ou de figures (schmidt p2, p3, p4, p7, p8), et diverge de `pdf2md`, dont il ne rejoue qu'une partie des détecteurs (source, fonction `compute_layout_complexity_with_chart_regions`).
- **Les balises `<!-- Page N -->` de `--pages` ne sont pas fiables** : pages sans balise, et jusqu'à douze pages rangées sous une seule balise.
- **La césure n'est toujours pas recollée en 1.24.0.** Même métrique qu'en août (`\p{Ll}-( |\n)\p{Ll}`), sur les 16 articles : 298 mots coupés dans `pdf2md --raw`, 12 dans `pdftotext` nu. Le chiffre d'août (242 contre 11) portait sur la 1.15.0 et un autre corpus.
- **L'ordre de lecture tient sur un article pdfTeX à deux colonnes**, le cas type de la règle 3, absent du corpus d'août. Sur `touvronLLaMAOpenEfficient2023.pdf` (pdfTeX-1.40.21, colonnes sur les pages 1 à 15, 18 et 22), `pdf2md --raw` sort les titres de section dans l'ordre (1, 2, 2.1 à 2.4, 3, 3.1 à 3.7, 4 à 8) et recoud la phrase « We use 2,000 warmup / steps, and vary the learning rate » coupée par la légende pleine largeur de la figure 1. `pdftotext -layout` sort 2.4 avant 2.3 et mêle la figure à la prose. Un seul document : la règle 3 reste sans réserve, faute de contre-exemple.
- **La ponctuation des fontes mathématiques TeX est altérée dans la prose.** Sur les 16 sorties, 22 occurrences de ponctuation entourée d'emphase (`\*[;:,.]\*`) dans 8 documents. Dans 7, la ponctuation reste juste et seule l'emphase s'ajoute (`28*.*4` chez Vaswani, qui se rend 28.4). Dans `touvronLLaMAOpenEfficient2023.pdf` (pdfTeX), le caractère lui-même change : `0.9` sort `0*:* 9`, `0.1` et `1.0` sortent `0*:* 1` et `1*:* 0`, `2,000` sort `2*;*000`, là où `pdftotext` donne `0.9`, `1.0` et `2, 000`. D'où la consigne de la règle 3 : un nombre ou une citation se recopie depuis `pdftotext`.
- **`pdftotext -layout` reste lisible** : au plus une cellule perdue sur 29 tableaux. Ses échecs sont prévisibles : exposants aplatis (`1019`), glyphes mal codés dans le PDF, page pivotée dense, rangée d'en-tête compressée. Sur ces cas, l'image de la page seule fait foi.

Recherche externe (détail dans `COMPARAISON.md`, section « Métrique ») : le score « Tables (TEDS) 0.814 » du README de pdf-inspector vient d'opendataloader-bench, soit 42 documents à tableaux, mesurés sur la version 0.2.6, et un benchmark qui ne pénalise aucun tableau inventé. Il ne se transpose pas à ce corpus. Upstream, des issues ouvertes décrivent les mêmes défauts : cellules fusionnées (#537), fausses tables sur pages à colonnes (#498, #219) et sur un bloc d'auteurs arXiv (#291), exposants (#297), en-têtes pivotés (#296). Aucune option ne désactive la détection des tableaux (`MarkdownOptions` n'en a pas).

### Décision

**`pdf2md` reste l'outil de lecture suivie des articles (règle 3), pour l'ordre de lecture de la prose, mais aucun tableau Markdown qu'il émet ne sert de source.** Toute valeur tirée d'un tableau se lit dans `pdftotext -layout` sur la page du tableau, trouvée par sa légende, et sur l'image de la page quand le tableau porte des exposants, des glyphes spéciaux, un en-tête sur plusieurs niveaux, ou quand la page est pivotée. Un tableau Markdown dans une sortie `pdf2md` ne prouve pas qu'un tableau existe. Ni `pages_with_tables` ni les balises `--pages` ne servent à localiser un tableau.

Rien à construire. Un filtre qui supprimerait les tableaux de la sortie `pdf2md` jetterait aussi les tableaux justes, sans rien apporter que la règle ne couvre déjà : la valeur se relit de toute façon dans `-layout`. Appliqué le 2026-09-23 dans `~/.claude/rules/pdf.md` : une phrase ajoutée à la règle 3, une règle 6 (tableaux) avec la commande de localisation par légende, et la section des défauts mesurés étendue aux articles. L'entrée `pdf2md` de `rules/environment.md` suit.

À réévaluer si les correctifs upstream des exposants (#297), des en-têtes pivotés (#296) et des tableaux scindés (#270) sont publiés, ou si une version annonce un correctif de la césure : le corpus et `COMPARAISON.md` permettent de refaire la mesure à l'identique. Cette note est la source de chaque chiffre que cite la section « Measured defects of pdf2md » de `rules/pdf.md` : une re-mesure s'écrit ici d'abord, puis le chiffre de tête s'y reporte.
