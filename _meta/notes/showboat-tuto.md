# Showboat : tutoriel

Outil CLI pour créer des documents Markdown qui mélangent texte, code exécuté, et sortie capturée.
Conçu pour que les agents IA documentent leur travail, mais utilisable manuellement.

Cas d'usage dans ce repo : construire un bootstrap vérifiable pendant une installation sur une nouvelle machine.

## Installation

```bash
uv tool install showboat
showboat --version
```

## Workflow de base

### Initialiser un document

```bash
showboat init ~/dotfiles/_meta/notes/bootstrap.md "Bootstrap Ubuntu 24.04"
```

### Ajouter du texte explicatif

```bash
showboat note ~/dotfiles/_meta/notes/bootstrap.md "## 1. Dépendances système

Sur une machine vierge Ubuntu 24.04 :

\`\`\`bash
sudo apt install -y stow git curl jq
\`\`\`"
```

Pour les longs blocs, stdin est plus pratique :

```bash
cat <<'EOF' | showboat note ~/dotfiles/_meta/notes/bootstrap.md
## Ma section

Texte ici.
EOF
```

### Exécuter du code et capturer la sortie

```bash
showboat exec ~/dotfiles/_meta/notes/bootstrap.md bash \
  "dpkg -l stow git curl jq | awk 'NR>5 {print \$2, \$3}'"
```

La commande est réellement exécutée.
Le bloc `bash` et le bloc `output` apparaissent dans le `.md`.

### Annuler la dernière entrée

```bash
showboat pop ~/dotfiles/_meta/notes/bootstrap.md
```

Utile quand une commande échoue ou produit une sortie indésirable.

### Vérifier que tout tourne encore

```bash
showboat verify ~/dotfiles/_meta/notes/bootstrap.md
```

Relance tous les blocs `exec` et compare les sorties.
À lancer après chaque mise à jour de l'environnement.

### Voir les commandes qui ont construit le document

```bash
showboat extract ~/dotfiles/_meta/notes/bootstrap.md
```

Affiche la séquence de commandes showboat qui a produit le fichier.

## Raccourci pratique

```bash
export SB=~/dotfiles/_meta/notes/bootstrap.md
showboat note "$SB" "mon texte"
showboat exec "$SB" bash "ma commande"
```

## Ce que showboat ne fait pas

- Pas de documentation rétrospective : `exec` exécute réellement le code, il ne "rejoue" pas un historique.
- Pas adapté aux commandes non idempotentes ou nécessitant un état vierge : utiliser `note` pour les décrire.
- Le bon moment pour l'utiliser : pendant l'installation, pas après.
