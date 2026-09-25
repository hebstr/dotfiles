# opencode et un llama-server partagé sur cpd000001

Procédure à appliquer à la main sur `cpd000001`, écrite le 2026-09-24.
Elle installe une build récente de llama.cpp dans `/opt/llama`, à côté de la b9286 qui reste en place pour `eds-avc`.
Un `llama-server` unique de cette build, lancé par systemd sous un utilisateur système `llama`, sert `unsloth/Qwen3.8-27B-GGUF` à tous les utilisateurs de la machine et décharge le modèle des GPU après 30 minutes sans requête.
Elle installe opencode dans `/usr/local/bin` avec un provider déclaré pour tous dans `/etc/opencode/opencode.json`, puis le harness du profil (règles, mémoire, skills de `~/.claude/skills`, hooks) pour le seul compte `edjulien`.
Claude Code n'est pas installé sur cpd : les skills de plugins restent absentes.

La décision, ses raisons et les voies écartées sont dans `.claude/DESIGN-CPD.md`, que git ne transporte pas (`.claude/` est ignoré) et qui manque donc sur cpd.
En résumé : un seul script de `bin` est lancé à la main sur cpd, `llama-update`, en root avec ses chemins redirigés vers `/opt/llama` ; `prose-lint` y sert au seul plugin de hooks.
`llama-session`, `sys-update` et `opencode-skills-sync` arrivent sur le `PATH` avec le paquet `bin` et ne doivent pas y être lancés.
`llama-session` en particulier vise ju-TP2 par SSH avec ses réglages par défaut ; pointé sur cpd par `LLAMA_REMOTE`, il cible `llama-server` par nom de processus, sans filtre d'utilisateur ni de port, et réutiliserait ou tuerait le serveur d'un autre utilisateur, un run `eds-avc` compris.

Les commandes utilisent `grep` plutôt que `rg`, dont la présence sur cpd n'est pas établie.

Prérequis : `main` est poussé sur GitHub, commit qui ajoute cette procédure compris, puisque cpd récupère les scripts et la configuration par le dépôt public.

## Faits de départ

Relevés le 2026-09-24 sur les captures `lscpu` et `nvitop` de la machine, dans les logs `llama-server` du projet `eds-avc`, sur le Hub et dans les sources de llama.cpp.

- 2 sockets Xeon Silver 4110, 32 threads, AVX2 et AVX512, environ 92 GiB de RAM.
- 3 Quadro RTX 6000 de 24 GiB (Turing, sm_75), pilote 595.84, CUDA 13.2.
- `llama-server` b9286 (2026-05-22), déjà installé et appelé par son nom par `eds-avc`.
- Cache des modèles de `llama-server --hf-repo` : `/data2/llama.cpp`, au format Hugging Face.
- Compte de l'utilisateur : `edjulien`.

Le modèle : architecture GGUF `qwen35`, celle de Qwen3.5 et Qwen3.6 27B.
64 couches dont 16 en attention complète, 4 têtes KV de dimension 256, soit 64 KiB de cache KV par token en f16 (6 GiB à 98304 tokens).
`Qwen3.8-27B-UD-Q4_K_M.gguf` pèse 15,3 GiB et `UD-Q4_K_XL` 16,4 GiB ; le dépôt ne publie pas de `Q4_K_M` sans préfixe `UD-`.
Poids et cache tiennent donc largement sur les 72 GiB des trois cartes.

Pourquoi une nouvelle build : le GGUF date du 2026-08-13, près de trois mois après b9286.
Le setup publié par l'auteur de `boxabirds/awesome-local-ai` pour ce modèle exige un llama.cpp de cette date au moins, et tourne sur b10452.
La build retenue ici est b11065 (2026-09-20), celle qui tourne sur ju-TP2, dont l'archive CUDA 12.8 contient `llama-cli` et `llama-server`.
Cette archive précompilée couvre Turing en PTX (`75-virtual` dans la liste par défaut de `ggml/src/ggml-cuda/CMakeLists.txt`) : au premier lancement, le pilote compile ces noyaux pour la carte, ce qui peut prendre plusieurs minutes, puis les garde dans son cache JIT.

## 0. Variables de la session

Toutes les étapes suivantes supposent ces variables définies dans le terminal courant, sous le compte `edjulien`.

```bash
PORT=8080
MODEL_REPO=unsloth/Qwen3.8-27B-GGUF
MODEL_QUANT=UD-Q4_K_M
CACHE=/data2/llama.cpp
LLAMA_TAG=b11065
OPT=/opt/llama
BIN=${OPT}/llama.cpp/llama-server
SAMPLING="--temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5"
```

`MODEL_QUANT` se confirme à l'étape 1.
`SAMPLING` est le réglage que la fiche du modèle donne pour le mode sans réflexion, repris par l'auteur cité plus haut : garder celui du mode réflexion quand elle est coupée fait tourner le modèle en boucle.

## 1. Reconnaissance, en lecture seule

```bash
id; sudo -v && echo "sudo ok"
llama-server --version 2>&1 | grep -i version
ls -l "$CACHE"/models--unsloth--Qwen3.8-27B-GGUF/snapshots/*/
stat -c '%U:%G %a %n' /data2 "$CACHE"
ls -l /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm
nvidia-smi --query-gpu=index,memory.used --format=csv,noheader
ss -ltn | grep ":${PORT} " || echo "port ${PORT} libre"
test -e "$OPT" && echo "$OPT existe déjà" || echo "$OPT libre"
test -d ~/dotfiles && git -C ~/dotfiles remote get-url origin && git -C ~/dotfiles status -sb | head -1 || echo "pas de clone"
for c in git stow jq python3 curl tar setfacl; do command -v "$c" >/dev/null || echo "manque : $c"; done
curl -sI https://github.com | head -1
curl -sI https://registry.npmjs.org | head -1
```

Résultats attendus, et que faire sinon :

- `version: 9286` : la build actuelle, que cette procédure ne touche pas.
- Le snapshot contient `Qwen3.8-27B-UD-Q4_K_M.gguf`. Si c'est une autre quantification, reporter son suffixe dans `MODEL_QUANT` (`UD-Q4_K_XL`, `Q4_0`, ...).
- Les périphériques `/dev/nvidia*` en `crw-rw-rw-`. Sinon, l'utilisateur `llama` devra rejoindre leur groupe à l'étape 4.
- La VRAM occupée par carte avant tout chargement : la relever, elle sert de référence pour la veille de l'étape 5. Un run `eds-avc` en cours la fausse.
- `port 8080 libre`. Sinon, choisir un autre `PORT` et le reporter partout où `8080` est écrit en dur (étapes 6 et 7).
- `/opt/llama libre`. Sinon, examiner son contenu avant d'aller plus loin.
- Pour `~/dotfiles` : un clone existe déjà sur cpd, puisque la sauvegarde de la machine en copie des fichiers (`_meta/notes/backup-cpd000001-setup.md`). La réponse attendue est l'URL `https://github.com/hebstr/dotfiles.git`, puis une ligne `## main...origin/main` sans `[ahead` ; des modifications locales ou un autre remote sont à examiner avant l'étape 2.
- Aucun `manque :`. Pour un outil manquant : `sudo apt install -y git stow jq python3 curl tar acl`.
- `HTTP/2 200` pour GitHub, nécessaire aux étapes 2, 3 et 7. Le registre npm ne sert qu'au plugin de hooks de l'étape 8 ; s'il est injoignable, opencode fonctionne sans ce plugin.

## 2. Le clone des dotfiles

Le dépôt est public : cpd le récupère sans passer par ju-TP.
Il doit se trouver dans `~/dotfiles`, chemin que le plugin de hooks et `AGENTS.md` supposent.
Il sert dès l'étape suivante, pour `llama-update` ; ses paquets ne sont liés qu'à l'étape 8.
Le clone existant est mis à jour, sinon il est créé :

```bash
if [ -d ~/dotfiles ]; then git -C ~/dotfiles pull --ff-only; else git clone https://github.com/hebstr/dotfiles.git ~/dotfiles; fi
git -C ~/dotfiles log -1 --format='%h %ad %s' --date=short
~/dotfiles/bin/.local/bin/llama-update --help | head -1
```

Résultats attendus : le dernier commit poussé depuis ju-TP, puis `Usage: llama-update [<tag>] [--list] [-h | --help]`.
Un `pull --ff-only` refusé signale des modifications locales sur cpd : les examiner, sans rien écraser.

## 3. La build b11065 dans `/opt/llama`

`llama-update` installe chaque build dans son propre répertoire derrière un lien stable, ne bascule le lien qu'une fois la build capable de lister un GPU CUDA, et garde la build précédente pour revenir en arrière en une commande.
Il vise par défaut `~/.local/opt` ; ses variables `LLAMA_OPT_ROOT`, `LLAMA_BIN_DIR` et `LLAMA_STAGE` le redirigent vers `/opt/llama`, lisible par l'utilisateur du service.
`LLAMA_BIN_DIR` pointe hors du `PATH`, pour que `llama-server` continue de désigner la b9286 d'`eds-avc`.
Le tag est explicite : sans lui, le script a besoin de `gh`.
`sudo env` transmet les variables au script lancé en root.

```bash
sudo env LLAMA_OPT_ROOT="$OPT" LLAMA_BIN_DIR="${OPT}/bin" LLAMA_STAGE=/var/cache/llama-install \
  ~/dotfiles/bin/.local/bin/llama-update "$LLAMA_TAG"
sudo env LLAMA_OPT_ROOT="$OPT" ~/dotfiles/bin/.local/bin/llama-update --list
"$BIN" --version 2>&1 | grep -i version
"${OPT}/llama.cpp/llama-cli" --list-devices 2>&1 | grep CUDA
command -v llama-server
```

Résultats attendus :

- Le téléchargement des deux archives (environ 160 et 566 MiB), puis `Active build: b11065`. Le message sur un `llama-server` déjà lancé concerne un run `eds-avc`, qui garde sa b9286.
- `* b11065`.
- `version: 11065`.
- Trois lignes `CUDA0`, `CUDA1`, `CUDA2` en `Quadro RTX 6000`.
- Le chemin de la b9286, inchangé.

Si le script répond `publishes no ...`, cette build ne publie pas d'archive CUDA 12.8 : choisir un autre tag parmi les releases `b*` de `ggml-org/llama.cpp` et relancer.

## 4. L'utilisateur système `llama` et ses accès

```bash
sudo useradd --system --home-dir /var/lib/llama --create-home --shell /usr/sbin/nologin llama
sudo -u llama "$BIN" --version 2>&1 | grep -i version
sudo -u llama ls "$CACHE"/models--unsloth--Qwen3.8-27B-GGUF/snapshots/
```

Résultat attendu : `version: 11065`, puis le hash du snapshot.
Le binaire, sous `/opt`, est lisible par tous.

Si l'accès au cache est refusé, on donne à `llama` la lecture du cache, avec une ACL par défaut pour que les modèles téléchargés plus tard restent lisibles :

```bash
sudo setfacl -m u:llama:x /data2
sudo setfacl -R -m u:llama:rX "$CACHE"
sudo setfacl -R -d -m u:llama:rX "$CACHE"
sudo -u llama ls "$CACHE"/models--unsloth--Qwen3.8-27B-GGUF/snapshots/
```

Si `setfacl` échoue avec `Operation not supported`, le système de fichiers de `/data2` n'accepte pas les ACL : passer par un groupe commun (`sudo usermod -aG "$(stat -c %G "$CACHE")" llama`, avec la lecture de groupe sur le cache).

## 5. Essai au premier plan

Avant d'écrire le service, la commande exacte tourne une fois au premier plan sous `llama`, avec un délai de veille ramené à 60 s pour vérifier la mise en veille sans attendre 30 minutes.
`HOME` est fixé pour que le cache JIT CUDA construit ici (`/var/lib/llama/.nv/ComputeCache`) soit celui que le service réutilisera, et `CUDA_CACHE_MAXSIZE` le porte à son maximum de 4 GiB, contre 1 GiB par défaut.
`--reasoning off` coupe la réflexion dans le template, et `$SAMPLING` n'est volontairement pas quoté pour se découper en options.

Terminal 1 :

```bash
sudo -u llama env HOME=/var/lib/llama LLAMA_CACHE="$CACHE" CUDA_CACHE_MAXSIZE=4294967296 "$BIN" \
  --hf-repo "${MODEL_REPO}:${MODEL_QUANT}" --offline --no-mmproj \
  --alias qwen3.8-27b --host 127.0.0.1 --port "$PORT" \
  -ngl 99 --ctx-size 98304 --parallel 1 \
  --jinja --reasoning off $SAMPLING --sleep-idle-seconds 60
```

Résultat attendu : `server is listening on http://127.0.0.1:8080`.
Le premier lancement compile les noyaux CUDA pour Turing et peut prendre plusieurs minutes ; les suivants chargent en une minute environ.
Si la résolution du modèle échoue sous `--offline`, remplacer `--hf-repo ... --offline` par `--model` suivi du chemin absolu du `.gguf` relevé à l'étape 1, ici et dans le service.
Si le chargement échoue sur le template de chat, relever le message : c'est précisément ce que la nouvelle build doit éviter.

Terminal 2, avec les variables de l'étape 0 redéfinies :

```bash
curl -s "http://127.0.0.1:${PORT}/health"; echo
nvidia-smi --query-gpu=index,memory.used --format=csv,noheader
curl -s "http://127.0.0.1:${PORT}/v1/chat/completions" -H 'Content-Type: application/json' -d '{
  "messages": [{"role": "user", "content": "Quel temps fait-il à Lille ?"}],
  "tools": [{"type": "function", "function": {"name": "get_weather", "description": "Météo d une ville",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]
}' | jq -c '.choices[0] | {finish_reason, call: .message.tool_calls[0].function}'
curl -s "http://127.0.0.1:${PORT}/v1/chat/completions" -H 'Content-Type: application/json' -d '{
  "messages": [{"role": "user", "content": "Reply with exactly: ok"}]
}' | jq -c '{content: .choices[0].message.content, reasoning: (.choices[0].message.reasoning_content // "" | length), tokens: .usage.completion_tokens}'
```

Résultats attendus :

- `{"status":"ok"}`.
- Environ 22 GiB de plus que la référence de l'étape 1, répartis sur les trois cartes.
- `finish_reason` à `tool_calls` et un appel `get_weather` avec `{"city":"Lille"}`.
- `content` à `ok`, `reasoning` à 0 et quelques tokens seulement : la réflexion est bien coupée. Un `content` vide avec un `reasoning` non nul signifie que le template ignore `--reasoning off` : le relever.

Puis attendre 70 s sans requête et vérifier la veille :

```bash
curl -s "http://127.0.0.1:${PORT}/props" | jq .is_sleeping
nvidia-smi --query-gpu=index,memory.used --format=csv,noheader
curl -s "http://127.0.0.1:${PORT}/v1/chat/completions" -H 'Content-Type: application/json' -d '{"messages": [{"role": "user", "content": "Reply with exactly: ok"}]}' | jq -r '.choices[0].message.content'
```

Résultats attendus : `true`, une VRAM revenue près de la référence de l'étape 1, à quelques centaines de MiB près par carte, puis `ok` après un rechargement.
Le déchargement en veille est l'hypothèse la plus faible de la décision : si la VRAM reste occupée pendant la veille, le service reste utilisable, mais il faudra l'arrêter à la main (`sudo systemctl stop llama-server`) pour rendre les GPU.

Arrêter l'essai par Ctrl-C dans le terminal 1.

## 6. Le service systemd

Le délimiteur du heredoc n'est pas quoté, donc le shell y remplace `$BIN`, `$CACHE`, `$MODEL_REPO`, `$MODEL_QUANT`, `$PORT` et `$SAMPLING` par leurs valeurs : relire le fichier écrit.
`ExecStart` passe par le lien `/opt/llama/llama.cpp` : après un `llama-update`, un redémarrage du service suffit à changer de build.

```bash
sudo tee /etc/systemd/system/llama-server.service >/dev/null <<EOF
[Unit]
Description=llama-server shared by cpd users (Qwen3.8 27B)
After=network.target

[Service]
Type=simple
User=llama
Group=llama
Environment=LLAMA_CACHE=${CACHE}
Environment=CUDA_CACHE_MAXSIZE=4294967296
ExecStart=${BIN} --hf-repo ${MODEL_REPO}:${MODEL_QUANT} --offline --no-mmproj --alias qwen3.8-27b --host 127.0.0.1 --port ${PORT} -ngl 99 --ctx-size 98304 --parallel 1 --jinja --reasoning off ${SAMPLING} --sleep-idle-seconds 1800
Restart=on-failure
RestartSec=10
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
cat /etc/systemd/system/llama-server.service
sudo systemd-analyze verify /etc/systemd/system/llama-server.service
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server
journalctl -u llama-server -f
```

Résultat attendu : `systemd-analyze verify` ne dit rien, puis le journal affiche `server is listening`.
Quitter le journal par Ctrl-C (le service continue), puis `curl -s "http://127.0.0.1:${PORT}/health"` répond `{"status":"ok"}`.

Au démarrage de la machine, le service charge le modèle, puis le décharge après 30 minutes sans requête.

## 7. opencode pour tous les utilisateurs

Le binaire officiel ne demande ni Node ni npm aux autres utilisateurs.
L'archive ne contient que l'exécutable `opencode` (vérifié sur la 1.18.32 le 2026-09-24).

```bash
VER=1.18.32
cd "$(mktemp -d)"
curl -fsSLO "https://github.com/anomalyco/opencode/releases/download/v${VER}/opencode-linux-x64.tar.gz"
tar -xzf opencode-linux-x64.tar.gz
sudo install -m 0755 opencode /usr/local/bin/opencode
cd ~
command -v opencode; opencode --version
```

Résultat attendu : `/usr/local/bin/opencode`, puis `1.18.32`.

Le provider va dans la configuration gérée de `/etc/opencode`, qu'opencode lit pour tous les utilisateurs et fait passer avant leurs propres fichiers, clé par clé.
Elle ne contient que le provider et le modèle, pour ne rien imposer d'autre.
opencode n'envoie pas de température propre pour un modèle Qwen : l'échantillonnage du service s'applique.
Le heredoc est quoté : `8080` y est écrit en dur, à changer si `PORT` diffère.

```bash
sudo install -d -m 0755 /etc/opencode
sudo tee /etc/opencode/opencode.json >/dev/null <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "cpd/qwen3.8-27b",
  "provider": {
    "cpd": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama.cpp on cpd000001",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "qwen3.8-27b": {
          "name": "Qwen3.8 27B",
          "limit": {
            "context": 98304,
            "output": 32768
          }
        }
      }
    }
  }
}
EOF
sudo chmod 0644 /etc/opencode/opencode.json
jq -c . /etc/opencode/opencode.json >/dev/null && echo "json ok"
opencode debug config | jq -c '{model, providers: (.provider | keys)}'
```

Résultats attendus : `json ok`, puis `{"model":"cpd/qwen3.8-27b","providers":["cpd"]}`, tant que le harness n'est pas installé.

Premier essai, dans un dépôt jetable :

```bash
cd "$(mktemp -d)" && git init -q && opencode run "Réponds exactement : ok"; cd ~
```

Résultat attendu : `ok`.
Les autres utilisateurs ont désormais opencode avec ce modèle et ses permissions par défaut, qui autorisent le shell sans demander confirmation.

## 8. Le harness pour `edjulien`

Seuls trois paquets sont liés : `bin` (pour `prose-lint`), `opencode` et `claude` (règles, mémoire, skills, scripts de hooks).
`bash` n'en fait pas partie, pour ne pas remplacer le `.bashrc` de cpd.

```bash
mkdir -p ~/.claude/skills ~/.local/share/opencode-claude-skills
cd ~/dotfiles
stow -n -v -R --no-folding --ignore='\.ruff_cache' -t ~ bin opencode
stow -n -v -R --ignore='\.ruff_cache' -t ~ claude
```

Ces deux commandes sont des essais à blanc (`-n`) : elles annoncent les liens sans rien créer.
Si l'une signale un conflit avec un fichier existant, examiner ce fichier et le déplacer avant d'aller plus loin.
Sinon, relancer les mêmes commandes sans `-n` :

```bash
stow -v -R --no-folding --ignore='\.ruff_cache' -t ~ bin opencode
stow -v -R --ignore='\.ruff_cache' -t ~ claude
cd ~
```

`~/.claude/skills` est créé en vrai répertoire avant le `stow claude`, pour que chaque skill y soit un lien vers son répertoire, comme le README l'exige.
`~/.local/share/opencode-claude-skills` reste vide : c'est le répertoire des skills de plugins, que rien ne remplit sans Claude Code.

Vérifications, depuis un nouveau shell de connexion pour que `~/.local/bin` soit sur le `PATH` :

```bash
for f in opencode.json AGENTS.md plugins/claude-hooks.ts; do readlink -e ~/.config/opencode/$f; done
readlink -e ~/.claude/rules ~/.claude/hooks; command -v prose-lint
opencode debug config | jq -c '{model, instructions, providers: (.provider | keys)}'
(cd /tmp && opencode debug agent build 2>/dev/null) | jq -c '[.permission[] | select(.permission == "bash")] | [first.pattern, first.action, last.pattern, last.action]'
f=$(mktemp); (cd /tmp && opencode debug skill >"$f" 2>/dev/null); jq -r '[.[] | select(.name == "design" or .name == "zotero") | .name] | sort | join(" ")' "$f"; rm -f "$f"
ls -d ~/.config/opencode/node_modules/@opencode-ai/plugin
```

Résultats attendus :

- Cinq chemins sous `/home/edjulien/dotfiles/`, puis `/home/edjulien/.local/bin/prose-lint`.
- `{"model":"cpd/qwen3.8-27b","instructions":[".claude/CLAUDE.md",".claude/memory/MEMORY.md"],"providers":["cpd","ju-tp2"]}` : le modèle de `/etc/opencode` l'emporte sur celui du `opencode.json` suivi, et le provider `ju-tp2` reste déclaré sans rien joindre.
- `["*","ask","*git commit*","ask"]` : le shell demande confirmation hors de la liste de lecture et du gate, et la dernière règle garde `git commit` sur confirmation (depuis le 2026-09-25, `.claude/DESIGN-OPENCODE-HARNESS.md`, « Git writes: `add` and `commit` ask, the other verbs are denied, 2026-09-25 »).
- `design zotero` : les skills de `~/.claude/skills` sont trouvées. La sortie de `debug skill` passe par un fichier, car elle est tronquée dans un pipe.
- Le chemin de `@opencode-ai/plugin` : opencode a installé au premier lancement la dépendance du plugin de hooks, depuis le registre npm. Si ce répertoire manque, le plugin n'est pas chargé : le relever.

Essai du harness dans un dépôt jetable :

```bash
cd "$(mktemp -d)" && git init -q
printf 'def add(a, b):\n    return a - b\n' > calc.py
printf 'Titre\n' > notes.md
opencode run "Corrige le bug de calc.py"
cat calc.py
opencode run "Ajoute à la fin de notes.md exactement cette ligne : Un tiret — ici"
cat notes.md; cd ~
```

Résultats attendus : `calc.py` contient `return a + b`, et la réponse vient en français sans tiret de ponctuation.
La seconde demande est refusée par `prose-lint` et `notes.md` reste inchangé : le plugin de hooks est actif.
Sous `opencode run`, une commande shell qui demanderait confirmation est refusée d'office ; en TUI, elle s'affiche pour approbation.

## 9. Exploitation

- État et journal : `systemctl status llama-server`, `journalctl -u llama-server -n 50`, et `curl -s http://127.0.0.1:8080/props | jq .is_sleeping`.
- Arrêt et reprise : `sudo systemctl stop llama-server`, `sudo systemctl start llama-server`.
- Un run `eds-avc` et ce service tiennent ensemble dans les 72 GiB tant que le modèle de `eds-avc` reste de la taille des 24 à 35B déjà testés ; ils ne partagent pas de port (`eds-avc` lit le sien dans son `.env`). Si la VRAM manque, arrêter le service le temps du run.
- `eds-avc` reste sur la b9286 du `PATH`. Le faire passer sur la build de `/opt/llama` changerait le moteur d'inférence en cours d'étude : c'est une décision d'analyse, hors de cette procédure.
- Mise à jour de llama.cpp : la commande `sudo env ... llama-update <tag>` de l'étape 3 avec le nouveau tag, puis `sudo systemctl restart llama-server` et une requête de l'étape 5 avant de s'y fier. Retour à la build précédente : la même commande avec l'ancien tag, sans téléchargement. Une build peut abandonner un réglage sans que le contrôle GPU du script le voie : sur ju-TP2, b10969 ignorait `--reasoning-budget 0`.
- Deux utilisateurs simultanés : passer à `--parallel 2 --ctx-size 196608` dans `ExecStart`, qui donne 98304 tokens à chaque slot pour 12 GiB de cache KV, puis `sudo systemctl daemon-reload && sudo systemctl restart llama-server`. La limite de `/etc/opencode/opencode.json` reste à 98304, par slot.
- Réflexion : la fiche du modèle et l'auteur cité plus haut la gardent active à effort `low`, le template utilisant `xhigh` quand rien n'est précisé. L'essai se fait après validation de la chaîne, en remplaçant `--reasoning off ${SAMPLING}` par `--reasoning on --reasoning-effort low --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0` ; le template n'accepte que `low`, `medium` et `xhigh` et rejette toute autre valeur.
- Mise à jour d'opencode : refaire le premier bloc de l'étape 7 avec la nouvelle `VER`.
- Mise à jour du harness : `git -C ~/dotfiles pull`, puis les deux `stow` de l'étape 8 pour lier les fichiers ajoutés. cpd ne fait que lire le dépôt : aucun commit n'y est fait.
- Désinstallation : `sudo systemctl disable --now llama-server`, puis `sudo rm /etc/systemd/system/llama-server.service /usr/local/bin/opencode`, `sudo rm -r /etc/opencode /opt/llama` et `sudo userdel -r llama`.
