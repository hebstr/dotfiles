# Acquérir SAS sur ju-TP (Ubuntu 24.04)

2026-10-06. Question posée : comment obtenir le logiciel SAS sur la machine.
Recherche faite, décision reportée par l'utilisateur. Ne pas refaire l'enquête : les trois voies ci-dessous sont exhaustives au 2026-10-06.

## Les trois faits qui cadrent tout

1. Il n'existe plus de SAS local gratuit. SAS University Edition (VM VirtualBox) n'était plus téléchargeable après le 30 avril 2021 et a été arrêté le 2 août 2021, remplacé par l'offre cloud.
2. SAS 9.4 Foundation ne supporte pas Ubuntu. Les distributions supportées sont RHEL, Oracle Enterprise Linux et SUSE Linux Enterprise Server (9.4M9 : RHEL/OEL 8.10 et plus, SLES 15 SP3 et plus).
3. La seule voie locale actuelle est un conteneur payant, SAS Analytics Pro, dont la licence est un JWT délivré avec une commande logicielle.

## État de la machine au 2026-10-06

Ubuntu 24.04.5, x86_64, 12 cœurs, 15 Go de RAM, 348 Go libres sur `/`.
Aucun runtime de conteneur installé : ni `docker`, ni `podman`, ni `apptainer`. Pas de VirtualBox.

## Voie A : SAS OnDemand for Academics

SAS Studio servi depuis le cloud SAS, gratuit, sans adresse `.edu` requise, 5 Go de stockage par utilisateur (plus 3 Go de données de cours pour un enseignant).
Usage restreint à l'apprentissage, l'enseignement et la recherche académique non lucrative. Un compte inutilisé pendant un an peut expirer.

Inscription : SAS Profile puis enregistrement sur `https://welcome.oda.sas.com`, la région choisie à l'inscription n'est plus modifiable ensuite.
Les données se téléversent dans *Server Files and Folders* et se lisent par un `libname` sur `/home/<id>/`.

Limite bloquante : les données quittent la machine pour une infrastructure SAS. Exclut tout usage SNDS ou donnée de santé, indépendamment de la clause non commerciale.

## Voie B : SAS Analytics Pro en conteneur (local, payant)

Image basée sur Red Hat UBI 8, SAS Studio sur le port 8080, utilisateur `sasdemo` par défaut.
Contenu : Base SAS, SAS/STAT, SAS/GRAPH et plusieurs SAS/ACCESS. La variante *Advanced Programming* ajoute SAS/ETS, SAS/IML, SAS/QC, SAS/OR.
Python 3.9.13 est embarqué dans l'image.

Prérequis hôte selon le guide de déploiement 2025.09-2025.11 : Docker Desktop sur RHEL 8.10 ou 9.x, ou Podman 4.9.4-rhel ou plus récent sur ces mêmes RHEL avec `podman-docker` installé.
12 à 15 Go de disque. Sortie autorisée vers `cr.sas.com` sur le port 443.
Ubuntu n'est pas dans la matrice de support.

Licence : devis auprès de SAS France, SAS ne publie aucun tarif public. Des agrégateurs tiers citent environ 1 850 $/an pour un poste, chiffre non confirmé par SAS et à ne pas traiter comme référence.
La commande ouvre l'accès à `my.sas.com`.

Procédure, une fois la licence obtenue :

```bash
mkdir -p ~/sas/deploy/{sasdemo,sasinside}
cd ~/sas/deploy
# my.sas.com > My Orders > la commande > Downloads
#   cocher License et Certificates -> ZIP contenant un .jwt et un ZIP de certificats
#   My Orders > Deployment Tools > SAS Container Manager > Linux
tar xvf containermgr-linux.tgz
./container-manager install --cadence-name "stable" --cadence-version "<version>" \
  --deployment-data SAS-certificates-<...>.zip sas-analytics-pro
./container-manager start --cadence-name "stable" --cadence-version "<version>" \
  sas-analytics-pro --license-path SAS-license-<...>.jwt --data-dir sasdemo
```

SAS Studio répond alors sur `http://localhost:8080`. Le ZIP de certificats se passe tel quel, sans le décompresser.

Point à trancher : l'image étant UBI 8, elle tournerait probablement sous Docker Engine installé depuis le dépôt Docker officiel sur Ubuntu, mais c'est une hypothèse non vérifiée et une configuration hors support (SAS Technical Support refusera les incidents).
Les deux options propres : une VM Rocky Linux 9 ou AlmaLinux 9 avec Podman dedans, au prix d'environ 4 Go de RAM sur les 15 ; ou assumer le hors-support sur Ubuntu.

## Voie C : exécuter du code SAS sans SAS

Altair SLC, ex-WPS Analytics de World Programming, compile et exécute le langage SAS sans produit SAS Institute, sur Linux x86-64.
Le produit a changé de main deux fois : World Programming vers Altair en 2021, puis vers Siemens, `altair.com/altair-slc` redirigeant aujourd'hui (307) vers `siemens.com/en-us/products/rapidminer/slc/`.
Une Community Edition gratuite a existé sous Altair. Son maintien sous l'enseigne Siemens n'a pas pu être confirmé le 2026-10-06, à vérifier auprès de l'éditeur.
La couverture porte sur data step, macro, ODS et les PROC statistiques, pas sur l'intégralité du catalogue SAS : tester sur du code réel avant tout engagement.

Cas trivial, si le besoin est seulement de lire des `.sas7bdat` : `haven::read_sas()` en R, `pyreadstat` en Python, aucun SAS requis.

## Recommandation en attente de décision

Commencer par la voie A pour vérifier sur du code réel que SAS est bien nécessaire : inscription en dix minutes, coût nul.
Si le besoin se confirme sur des données non téléversables, demander un devis Analytics Pro et déployer le conteneur dans une VM Rocky 9, ce qui maintient le support technique acheté pour 4 Go de RAM.

## Références

- SAS OnDemand for Academics : https://www.sas.com/en_us/software/on-demand-for-academics.html
- Support et inscription : https://support.sas.com/en/software/ondemand-for-academics-support.html et https://welcome.oda.sas.com
- System Requirements for SAS 9.4 Foundation for Linux x64 : https://support.sas.com/documentation/installcenter/en/ikfdtnlaxsr/66396/PDF/default/sreq.pdf
- SAS Analytics Pro, Deployment Guide 2025.09-2025.11 : https://documentation.sas.com/api/collections/anprocdc/v_052/docsets/dplyviya0ctr/content/dplyviya0ctr.pdf?locale=en
- Altair SLC, redirigé vers Siemens : https://www.siemens.com/en-us/products/rapidminer/slc/
