---
name: Migration Ubuntu 24.04 vers 26.04 différée
description: Décision 2026-09-09 de rester sur 24.04 jusqu'à décembre 2026 au plus tôt, conditionnée au flag Supported du meta-release Canonical ; recherche complète déjà faite, ne pas la refaire
metadata:
  type: project
---

Le 2026-09-09, recherche `/workflow:reco` complète sur le passage de la machine (Ubuntu 24.04.5, noble) à 26.04 LTS « Resolute Raccoon ».
Décision : ne pas migrer avant décembre 2026, fenêtre visée décembre 2026 à février 2027.
Toute la recherche, les vérifications de dépôts et la checklist du jour J sont dans `~/dotfiles/_meta/notes/ubuntu-26-04-migration-reco.md`.

**Why:** la stack data science est prête depuis mai 2026 (PPM, CRAN, r2u, rig, Positron, Docker, QGIS et les 4 PPAs servent tous `resolute`), le risque est passé au cœur de l'OS : rust-coreutils par défaut avec casse documentée et silencieuse sur `sort` et `dd`, `sudo-rs`, Wayland seul, cgroup v1 retiré. 24.04 est maintenue jusqu'en mai 2029, donc attendre coûte zéro.

**How to apply:** si le sujet revient, lire la note plutôt que relancer la recherche. Une routine cloud quotidienne surveille déjà le déclencheur (`trig_019wLpTCwdTRi8kKNBwaQLnw`, créée le 2026-09-09, silencieuse tant que le flag vaut 0) : ne pas en créer une seconde. Le déclencheur est aussi vérifiable à la main en une commande : `curl -s https://changelogs.ubuntu.com/meta-release-lts | grep -A4 '^Dist: resolute'` doit renvoyer `Supported: 1` (valait `Supported: 0` au 2026-09-09, chemin automatique fermé), puis deux à trois mois de tampon. Le jour de la migration, deux fichiers passent de `noble` à `resolute` : `~/dotfiles/_meta/profiles/Rprofile.site` et `~/dotfiles/claude/.claude/rules/environment.md`.
