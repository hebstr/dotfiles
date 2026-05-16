# Install llama-server (CPU build) for local smoke tests

*2026-05-11T21:12:59Z by Showboat 0.6.1*
<!-- showboat-id: 3cec3c38-b107-4721-a304-ae152c15b479 -->

## Contexte

Installation d'un binaire `llama-server` (build CPU pur, x86_64) sur la machine perso `ju-TP` (Ubuntu 24.04, iGPU Intel uniquement, pas de CUDA).

But : smoke-tester localement le pipeline LLM du projet `eds-avc` (script `note/auto/avc_note_auto_output_llama-server.py`, lanceur `note/auto/llama-server.sh`). L'inférence de production tourne sur le serveur CHU `cpd000001` avec 3 GPU NVIDIA (pas reproduit ici).

Source : releases pré-compilées du repo `ggml-org/llama.cpp` sur GitHub (asset `llama-bNNNN-bin-ubuntu-x64.tar.gz`).

Version installée : **b9106** (épinglée pour reproductibilité ; pour mettre à jour, remplacer la variable `VER` ci-dessous par la dernière release publiée).

Layout cible :
- `~/.local/opt/llama.cpp/` : extraction de l'archive (binaires + libs co-localisés, RPATH `$ORIGIN`)
- `~/.local/bin/llama-server` : symlink vers le binaire dans `~/.local/opt/llama.cpp/`

```bash

set -euo pipefail
VER=b9106
ARTIFACT="llama-${VER}-bin-ubuntu-x64.tar.gz"
URL="https://github.com/ggml-org/llama.cpp/releases/download/${VER}/${ARTIFACT}"
DEST="${HOME}/.local/opt/llama.cpp"
TMP=$(mktemp -d)
trap "rm -rf ${TMP}" EXIT

echo "[1/4] Download ${ARTIFACT}"
curl -fsSL -o "${TMP}/${ARTIFACT}" "$URL"

echo "[2/4] Extract"
tar -xzf "${TMP}/${ARTIFACT}" -C "${TMP}"
test -x "${TMP}/llama-${VER}/llama-server"

echo "[3/4] Install to ${DEST}"
rm -rf "${DEST}"
mkdir -p "$(dirname "${DEST}")"
mv "${TMP}/llama-${VER}" "${DEST}"

echo "[4/4] Symlink ~/.local/bin/llama-server"
mkdir -p "${HOME}/.local/bin"
ln -sf "${DEST}/llama-server" "${HOME}/.local/bin/llama-server"

ls -la "${HOME}/.local/bin/llama-server"

```

```output
[1/4] Download llama-b9106-bin-ubuntu-x64.tar.gz
[2/4] Extract
[3/4] Install to /home/julien/.local/opt/llama.cpp
[4/4] Symlink ~/.local/bin/llama-server
lrwxrwxrwx 1 julien julien 46 May 11 23:14 /home/julien/.local/bin/llama-server -> /home/julien/.local/opt/llama.cpp/llama-server
```

```bash

set -euo pipefail
hash -r
command -v llama-server
llama-server --version 2>&1 | head -5

```

```output
/home/julien/.local/bin/llama-server
load_backend: loaded RPC backend from /home/julien/.local/opt/llama.cpp/libggml-rpc.so
load_backend: loaded CPU backend from /home/julien/.local/opt/llama.cpp/libggml-cpu-alderlake.so
version: 9106 (dd9280a66)
built with GNU 11.4.0 for Linux x86_64
```

## Configuration projet `eds-avc`

Dans `.env` (à la racine du projet), décommenter et adapter :

```dotenv
LLAMA_BIN=/home/julien/.local/bin/llama-server
LLAMA_PORT=8080
LLAMA_PARALLEL=1
# LLAMA_TENSOR_SPLIT — laisser commenté (multi-GPU only)
```

## Pièges CPU vs config GPU de prod

Le script `note/auto/avc_note_auto_output_llama-server.py` passe inconditionnellement `--flash-attn on` et `--batch-size 4096` à `llama-server`. Ces flags ciblent la config GPU de `cpd000001`. Pour le smoke-test CPU local :

- `--flash-attn on` : le backend CPU n'a pas d'implémentation FA dédiée. À vérifier au démarrage du serveur. Si llama-server refuse ou crashe, retirer le flag.
- `--batch-size 4096` / `--ubatch-size 512` : surdimensionné en CPU, ralentit sans gain. Pas bloquant, mais à abaisser (ex: 512/128) pour un retour interactif.
- Modèle : choisir un GGUF < 1B params (ex: `unsloth/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M`). Tout modèle ≥ 7B sera inutilisable en CPU pour un smoke-test.
- `CUDA_VISIBLE_DEVICES=0,1,2` (hardcodé dans `subprocess.Popen`) : sans impact si pas de GPU NVIDIA détecté, llama-server retombe sur CPU.

Ces ajustements ne sont **pas** appliqués ici, laissés au lanceur ad-hoc côté projet (`note/auto/llama-server.sh` ou commande directe).

## Mise à jour

Pour passer à une release plus récente :

1. Récupérer le tag : `gh api repos/ggml-org/llama.cpp/releases/latest --jq '.tag_name'`
2. Modifier `VER=b9106` dans le bloc exec ci-dessus
3. `showboat verify` ce fichier → re-exécute l'install et compare les sorties

