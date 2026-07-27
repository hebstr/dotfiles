# Ajout de pyrefly à la porte Python globale

*2026-07-27T20:23:44Z by Showboat 0.6.1*
<!-- showboat-id: 756bec19-bf41-4253-a4aa-55fc5b42a9d1 -->

pyrefly (Meta) est le vérificateur de types que Positron installe par défaut : il figure dans les `bootstrapExtensions` de `product.json`, contrairement à pyright.
Il est en 1.x Production/Stable, là où ty (Astral) reste en 0.0.x beta sans API stable.
Il devient le gardien de types de la porte Python globale, mais n'existait jusqu'ici que comme extension Positron, sans CLI sur le PATH.

Installation en outil uv, pour que le module `uv-tools` de `sys-update` le maintienne à jour au même titre que showboat, ouroboros-ai et yt-dlp.
Routine distincte de celle de ruff, air et jarl, qui sont des binaires cargo-dist dans `/usr/local/bin` entretenus par `devtools-update`.

```sh
uv tool install pyrefly
```

```output
Resolved 1 package in 275ms
Installed 1 package in 5ms
 + pyrefly==1.1.1
Installed 1 executable: pyrefly
```

Vérification : le binaire est sur le PATH et la version colle à celle de l'extension Positron (meta.pyrefly-1.1.1).
La parité de version ne suffit pas à garantir des diagnostics identiques entre l'éditeur et la ligne de commande : l'extension ignore le PATH et le preset se règle des deux côtés.
Les deux sont épinglés depuis (`pyrefly.lspPath`, `python.pyrefly.typeCheckingMode`), voir `rules/python.md`.

```sh
command -v pyrefly && pyrefly --version
```

```output
/home/julien/.local/bin/pyrefly
pyrefly 1.1.1
```

Piège découvert à la vérification : sans table `[tool.pyrefly]` ni `pyrefly.toml`, pyrefly retombe sur le preset `basic`, renvoie 0 erreur et sort en 0 même sur un `bad-return` évident.
Une table vide suffit à activer la vérification complète, et `-p default` couvre le cas où aucune config ne gouverne le fichier.
`rules/python.md` porte la commande conditionnelle qui en découle : run nu d'abord, puis `-p default` uniquement si la notice de repli est sortie.
Le décompte ci-dessous ne vaut donc que parce qu'`eds-avc` déclare sa config ; sans notice de repli, il n'y aurait rien à conclure d'un `0 errors`.

```sh
cd ~/Documents/des/eds/eds-avc && pyrefly check annot/ 2>&1 | tail -1
```

```output
 INFO 0 errors (2 warnings not shown)
```
