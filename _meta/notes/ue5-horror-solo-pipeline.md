# Pipeline UE5 solo : reproduire le process de Darkphobia Games

Note de recherche (2026-08-19).
Aucune installation faite à ce stade : la machine Windows n'est pas encore accessible.

## Dossier du projet

`~/Documents/sandbox/ue5-le-relais/`, hors dépôt git.
Trois documents rédigés le 2026-08-19, tous antérieurs à l'installation du moteur : `script.md` (séquence v1 en huit étapes), `plan.md` (plan de masse en unités Unreal), `assets.md` (liste de courses Fab par terme de recherche).

## Objet

Comprendre comment une équipe de deux personnes sort un jeu d'horreur à rendu quasi photoréaliste tous les huit à douze mois, et déterminer ce qu'il faut pour reproduire ce process.

## Qui est Darkphobia Games

Équipe de deux personnes, identique à **TeaserPlay**, chaîne YouTube connue pour ses concept trailers en Unreal Engine 5 (GTA 6, The Witcher 4, Avatar, Black Panther, Breaking Bad en monde ouvert).
Leur déclaration au moment d'annoncer leur premier jeu : *"This is our first video game in Unreal Engine 5.
After several months of making concept videos of branded games, we decided to focus on our own original ideas."*

Ce sont donc des artistes 3D et réalisateurs de cinématiques devenus développeurs, pas l'inverse.
La qualité graphique est leur métier d'origine transposé dans un produit vendable.

  | Jeu             | Sortie       | Prix   | Avis Steam     |
  | --------------- | ------------ | ------ | -------------- |
  | Graveyard Shift | 2 déc. 2023  | 6,89 € | 75 % sur 723   |
  | Homeless        | 3 août 2024  | 6,89 € | non relevé     |
  | Amenti          | 5 janv. 2025 | 6,89 € | non relevé     |
  | The Lightkeeper | 7 sept. 2025 | 7,79 € | 81 % sur 1 059 |

Revenus cumulés estimés à environ 653 k$ par Video Game Insights (estimation tierce, pas un chiffre officiel).

## Le levier réel : le périmètre, pas la vitesse

Leurs jeux durent de 50 minutes à 2 heures.
Amenti est mesuré à environ une heure par plusieurs testeurs.

- Un seul personnage jouable, à la première personne, jamais visible à l'écran.
  Aucune animation de corps humain, aucun rig, aucune caméra tierce personne.
- Un lieu unique et clos : cimetière, phare, tombeau.
  Pas de monde ouvert, pas de streaming de niveaux.
- Presque aucun système de jeu.
  La page Steam de Graveyard Shift l'annonce : le jeu repose sur l'ambiance, pas sur les énigmes.
  Ni combat, ni inventaire complexe, ni IA d'ennemi, ni équilibrage.
- Aucun multijoueur, aucune progression longue.

Le coût d'un jeu explose avec le nombre d'interactions entre systèmes.
Ils ont supprimé les systèmes.
Il reste un couloir très soigné et une mise en scène, soit le format d'un trailer étiré et rendu jouable.

Indice confirmant le périmètre : configurations recommandées modestes (GTX 1660, 8 à 16 Go de RAM) et empreinte disque de 8 à 15 Go, contre 100 à 150 Go pour un AAA.
Peu de contenu unique, et un marché élargi aux PC modestes.

## Le modèle économique

Prix bas (7 €), durée courte, genre horrifique.
Triangle délibéré : un jeu d'une heure se joue en une seule vidéo YouTube ou Twitch, ce qui produit un marketing gratuit massif.
À 7 € l'achat est impulsif et le joueur pardonne la brièveté.
Un jeu par an entretient une audience Steam (près de 3 850 abonnés) qui se reporte d'un titre au suivant.

## Contrepartie à connaître

- Réutilisation d'assets marketplace jugée trop visible dans les avis Steam.
- Usage d'IA générative.
  Pour The Lightkeeper, des joueurs ont dénoncé voix, textes et visuels générés, avec traductions fautives et doublage monocorde.
  Le studio a ajouté la mention obligatoire de contenu IA sur la page Steam, puis déclaré avoir remplacé les voix retouchées par IA par des performances humaines.
- Fond de gameplay jugé mince : walking simulator, pixel hunting, fins peu justifiées.

Une partie de leur vitesse vient d'arbitrages qui coûtent en réputation, pas seulement d'efficacité.

## Verdict matériel

Spécifications recommandées d'Epic pour l'éditeur sous Windows (UE 5.8) : Windows 11, quad-core 2,5 GHz ou plus, **32 Go de RAM**, GPU DirectX 12 à jour, **8 Go de VRAM ou plus**.
Epic recommande 12 à 16 cœurs pour compiler localement sans build distribué.
Sa station de travail de référence embarque une RTX 4080 avec 16 Go de GDDR6.

**Portable Ubuntu (Iris Xe, 15 Gio de RAM) : insuffisant.**
Le chipset intégré s'écroule précisément sur Lumen et Nanite, les deux technologies qui produisent le rendu recherché.
Intel a livré des correctifs Xe intégrés à UE 5.7, ce qui confirme que la combinaison posait problème.
La machine permet d'apprendre le moteur, pas de produire ce rendu.
Second frottement : sur Linux la distribution passe par une archive (environ 25 Go compressés, 43 Go décompressés) et non par l'Epic Games Launcher, donc pas d'intégration Fab et un packaging Windows compliqué.

**Machine Windows, 16 Go de VRAM : validé.**
Le double du seuil recommandé, au niveau du GPU de la station Epic.
Lumen, Nanite et les Megascans pleine résolution passent sans réserve.
Le GPU était le seul critère éliminatoire.

## À vérifier au premier accès à la machine Windows

La VRAM est validée, restent les deux facteurs limitants suivants.

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object -Expand TotalPhysicalMemory
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
Get-PSDrive C | Select-Object Used, Free
```

GPU exact et VRAM : `Win+R` puis `dxdiag`, onglet Affichage, ou Gestionnaire des tâches, onglet Performance, ligne « Mémoire GPU dédiée ».
`Win32_VideoController` plafonne son champ `AdapterRAM` à 4 Go (champ codé sur 32 bits) et sous-déclare donc toute carte au-delà.

Seuils à confronter aux relevés :

- RAM système : 32 Go recommandés.
  À 16 Go le travail reste possible, avec compilations de shaders lentes et ralentissements dès que l'éditeur, un navigateur et Blender coexistent.
  Ajout d'une barrette pour quelques dizaines d'euros si besoin, ce qui ne bloque pas le premier projet.
- Cœurs CPU : 12 à 16 recommandés.
  Moins critique en Blueprint pur, mais compilation de shaders et construction de l'éclairage précalculé saturent tous les cœurs.
- Disque : prévoir 200 Go libres sur SSD NVMe.
  L'installation du moteur demande 120 à 130 Go de pic (fichiers temporaires) pour 30 à 40 Go finaux, auxquels s'ajoutent projet, assets Fab et caches de shaders.

## Chaîne d'outils

  | Outil               | Rôle                                               | Coût                                                   |
  | ------------------- | -------------------------------------------------- | ------------------------------------------------------ |
  | Epic Games Launcher | Installe et gère les versions du moteur            | Gratuit                                                |
  | Unreal Engine 5.8   | Moteur, éditeur, tout le reste                     | Gratuit jusqu'à 1 M$ de revenus, puis 5 % de royalties |
  | Fab                 | Boutique d'assets 3D, intégrée au launcher         | Assets gratuits et payants                             |
  | Blender             | Retouche de modèles quand un asset ne convient pas | Gratuit                                                |
  | Audacity ou Reaper  | Montage sonore                                     | Gratuit / payant                                       |

Megascans a été gratuit pour tous jusqu'à fin 2024, puis Epic a basculé la majorité du catalogue en payant sur Fab.
Il reste une sélection gratuite tournante, et les Megaplants (végétation, compatibles Nanite) sont gratuits.
Le socle « décor photoréaliste à coût nul » de 2023 s'est donc partiellement refermé.

## Codage : il n'y en a probablement pas

Unreal offre deux voies.
**Blueprint** est un langage visuel à boîtes et fils, compilé en bytecode par le moteur, avec variables, boucles, fonctions et conditions.
**C++** sert aux systèmes lourds ou critiques en performance.

Pour un couloir d'une heure sans combat, sans IA complexe, sans inventaire et sans multijoueur, Blueprint suffit intégralement.
Beaucoup de jeux commerciaux de ce format sont 100 % Blueprint.
Aucun éditeur de code n'est ouvert.

Conséquence sur l'apprentissage : 90 % du temps se passe à placer des objets, régler des lumières, cadrer des plans et itérer sur l'ambiance.
Le goulot d'étranglement est artistique.
C'est ce qui permet à deux vidéastes 3D de devenir développeurs de jeux, alors que l'inverse est plus rare.

### IDE

- **Positron** : aucune utilité.
  Construit pour R et Python, il ne comprend ni les `.uasset` binaires, ni le modèle `.uproject`, ni les Blueprints.
- **VSCode** : utile uniquement en C++ Unreal, et c'est l'option la moins confortable des trois.
- **JetBrains Rider** : outil de référence si passage au C++ (intégration Blueprint, piles d'appel mixtes C++/Blueprint dans le débogueur, support natif du `.uproject`).
  Gratuit pour usage non commercial, licence gratuite excluant explicitement les projets commerciaux, donc payante dès la vente sur Steam.
- **Visual Studio Community** : gratuit, chemin historique supposé par la documentation Epic.

## Déroulé du premier projet

1. Écrire le jeu sur une page : un lieu, un personnage, trois événements, une fin.
2. Créer un projet Unreal à partir du template First Person, en Blueprint.
   Personnage jouable immédiat.
3. Blockout en cubes gris, distances et rythme validés avant tout visuel.
   Viser dix minutes de parcours pour un premier projet, pas une heure.
   Étape que les débutants sautent et qu'il ne faut pas sauter.
4. Habillage avec les assets gratuits de Fab et les Megaplants, puis packs payants ciblés.
5. Éclairage Lumen activé.
   C'est ici que se fabrique 80 % de l'impression de qualité, et l'étape qui consomme le plus de temps.
6. Scripter les événements en Blueprint : déclencheurs, sons, portes, apparitions.
7. Son et mixage.
   Systématiquement sous-estimé : dans l'horreur, le son fait plus peur que l'image.
8. Packager en exécutable Windows, tester sur une autre machine.

Le portable Ubuntu reste utile pour tout ce qui n'est pas le moteur : écriture du script, préparation des sons, dépôt Git.

## Sources

- [Steam Developer: Darkphobia Games](https://store.steampowered.com/developer/Darkphobia)
- [Graveyard Shift on Steam](https://store.steampowered.com/app/2636420/Graveyard_Shift/)
- [The Lightkeeper on Steam](https://store.steampowered.com/app/3612850/The_Lightkeeper/)
- [Graveyard Shift: A Terrifying New Unreal Engine 5 Horror Title (Hitmarker)](https://hitmarker.net/news/graveyard-shift-a-terrifying-new-unreal-engine-5-horror-title-516388)
- [New UE5-Based Horror Combines Outlast With Photoreal Graphics (80.lv)](https://80.lv/articles/new-ue5-based-horror-game-combines-outlast-vibes-with-photoreal-graphics)
- [Amenti review (Adventure Game Hotspot)](https://adventuregamehotspot.com/review/4624/amenti)
- [The Lightkeeper Review PC (Gaming.net)](https://www.gaming.net/reviews/the-lightkeeper-review-pc/)
- [DarkPhobia Games Steam stats (Video Game Insights)](https://app.sensortower.com/vgi/developer/2726041/darkphobia-games)
- [Hardware and Software Specifications for Unreal Engine (Epic, UE 5.8)](https://dev.epicgames.com/documentation/en-us/unreal-engine/hardware-and-software-specifications-for-unreal-engine)
- [Install Unreal Engine (Epic, UE 5.8)](https://dev.epicgames.com/documentation/unreal-engine/install-unreal-engine?lang=en-US)
- [Download Unreal Engine](https://www.unrealengine.com/download)
- [Unreal Engine on Linux (SomethingLikeGames)](https://www.somethinglikegames.de/en/blog/2026/linux_06_ue/)
- [Does Intel's Iris Xe support Nanite? (forums Epic)](https://forums.unrealengine.com/t/does-intels-iris-xe-support-nanite-full-specs-in-text-body/522321)
- [Intel Unreal Engine 5 Optimization Guide, chapitre 2](https://www.intel.com/content/www/us/en/developer/articles/technical/unreal-engine-optimization-chapter-2.html)
- [Epic has made Megascans free to all, but only until the end of 2024 (CG Channel)](https://www.cgchannel.com/2024/10/epic-games-has-made-megascans-free-to-all-but-only-until-the-end-of-2024/)
- [Quixel on Fab: New Megascans and Megaplants](https://quixel.com/news/quixel-on-fab-new-megascans-and-megaplants)
- [Rider for Unreal Engine now free for non-commercial use (80.lv)](https://80.lv/articles/jetbrains-launched-rider-for-unreal-engine-free-version)
- [Rider, the ultimate IDE for Unreal Engine (JetBrains)](https://www.jetbrains.com/lp/rider-unreal/)
