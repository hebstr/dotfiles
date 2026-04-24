---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/.bashrc"
  - "**/.bash_profile"
  - "**/.bash_aliases"
---

# Shell scripting toolchain

## CLI tools

| Outil | Rôle | Installation |
|---|---|---|
| `shellcheck` | Linter (analyse statique, warnings `SC*`) | `sudo apt install shellcheck` |
| `shellharden` | Auto-fix du quoting des variables | `cargo install shellharden` (pas dispo via apt sur Ubuntu 24.04) |
| `shfmt` | Formateur (indentation, espacement) | `sudo apt install shfmt` |

Rôles orthogonaux :
- **shellcheck** signale — ne corrige pas
- **shellharden** corrige automatiquement le quoting (basé sur les règles de shellcheck)
- **shfmt** formate (cosmétique uniquement, pas de correction sémantique)

## Pipeline type

Ordre important — shellharden modifie la structure, shfmt met en forme, shellcheck valide :

```sh
shellharden --replace script.sh   # auto-fix quoting
shfmt -w script.sh                # formatage in place
shellcheck script.sh              # audit final
```

## Flags shfmt utiles

| Flag | Effet |
|---|---|
| `-w` | write in place |
| `-i 2` | indentation 2 espaces |
| `-ci` | indenter les branches de `case` |
| `-sr` | espace après redirections (`> file`) |
| `-bn` | `&&` / `\|` en début de ligne |

Exemple combiné :
```sh
shfmt -w -i 2 -ci -sr script.sh
```

## Extensions VS Code / Positron

**À installer :**
1. **Bash IDE** (`mads-hartmann.bash-ide-vscode`) — LSP complet (completion, hover, go-to-def) + intègre shellcheck et shfmt automatiquement. Sert de formatter pour `shellscript`.
2. **shell-format** (`foxundermoon.shell-format`) — utilisé uniquement pour les **autres** formats : Dockerfile, dotenv, .gitignore/.dockerignore, /etc/hosts, .properties, jvmoptions, bats. Ne pas l'utiliser pour shellscript : elle tente de télécharger son propre shfmt et échoue parfois silencieusement (message Positron : "cannot format Shell Script-files").

**Nice-to-have :**
- **Better Shellscript Syntax** (`jeff-hykin.better-shellscript-syntax`) — highlighting plus précis
- **Bash Debug** (`rogalmic.bash-debug`) — debugger pas-à-pas (scripts > 100 lignes)

Pas d'extension pour shellharden — lancer à la main ou via pre-commit.

## Config `settings.json`

Les flags shfmt ne sont pas passés en ligne de commande : Bash IDE expose chaque option individuellement (`caseIndent` = `-ci`, `spaceRedirects` = `-sr`, etc.). L'indentation `-i N` passe par `editor.tabSize` du bloc `[shellscript]`.

```json
{
  "bashIde.shellcheckPath": "shellcheck",
  "bashIde.shfmt.path": "/usr/bin/shfmt",
  "bashIde.enableSourceErrorDiagnostics": true,
  "bashIde.shfmt.caseIndent": true,
  "bashIde.shfmt.spaceRedirects": true,
  "[shellscript]": {
    "editor.tabSize": 2,
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "mads-hartmann.bash-ide-vscode"
  }
}
```

`enableSourceErrorDiagnostics` active les diagnostics croisés via `source`/`.` (résolution des fichiers sourcés pour propager les erreurs).

Autres flags exposés par Bash IDE : `binaryNextLine` (`-bn`), `simplifyCode` (`-s`), `funcNextLine`, `languageDialect` (bash/posix/mksh/bats).

### Autres formats (Dockerfile, dotenv, ignore, etc.)

`foxundermoon.shell-format` est enregistré par défaut comme formatter pour Dockerfile/dotenv/.gitignore/hosts/.properties/jvmoptions/bats mais `Format Document` ne se déclenche pas auto sans bloc `[langage]`. N'ajouter un bloc que si besoin :

- **format-on-save souhaité** → `formatOnSave: true` + `defaultFormatter` (ex. Dockerfile où la mise en forme est bénéfique)
- **juste figer le choix du formatter** (utile si plusieurs extensions candidates, ex. Dockerfile avec `ms-azuretools.vscode-docker`) → seulement `defaultFormatter`
- **rien** → `Format Document With...` reste dispo ponctuellement

Formats où le format auto est à éviter : dotenv (ordre parfois significatif), .gitignore, /etc/hosts (édition rare, commentaires structurants).

Exemple pour Dockerfile :

```json
"[dockerfile]": {
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "foxundermoon.shell-format"
}
```

## Pre-commit hook

`.pre-commit-config.yaml` :

```yaml
repos:
  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.13.1
    hooks:
      - id: shfmt
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
```

## Vérifier un script sans l'exécuter

```sh
sh -n script.sh          # check syntaxe POSIX
bash -n script.sh        # check syntaxe bash
shellcheck script.sh     # lint complet
```

## Références

- ShellCheck : https://github.com/koalaman/shellcheck — codes `SC*` documentés sur https://www.shellcheck.net
- shellharden : https://github.com/anordal/shellharden
- shfmt (projet `mvdan/sh`) : https://github.com/mvdan/sh
- bash-language-server : https://github.com/bash-lsp/bash-language-server
