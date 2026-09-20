# Install the CUDA build of llama-server on ju-TP2

*2026-09-20T22:29:32Z by Showboat 0.6.1*
<!-- showboat-id: f065aa68-ae7d-4f7b-944c-39840cdd45a2 -->

Step 1 of `.claude/DESIGN-GPU-REMOTE.md`, run 2026-09-21. The install happened on `ju-TP2` (Ubuntu under WSL2) and is reported from `ju-TP`, which drove it over `ssh ju-TP2 'bash -s'`; the install itself is a tilde fence so `verify` on `ju-TP` never replays it here, while the checks below are read-only over the same link and do replay.

Goal: serve inference from the RTX A3000 12GB of `ju-TP2` to an agent running on `ju-TP`, which has no usable GPU. Only `llama-server` crosses; the agent and the working tree stay on `ju-TP`.

Two departures from `_meta/notes/llama-server-install.md`, which fixed this layout for the CPU build. The release ships the binaries and the CUDA runtime as two archives, merged here into one directory so the `$ORIGIN` RPATH resolves `libcudart` without a CUDA toolkit installed. And the artifact is the `cuda-12.8` one rather than `cuda-13.3`, the driver announcing CUDA 13.2: minor-version compatibility inside CUDA 13 would probably carry the newer build, and the 12.8 one runs on that driver with no argument at all.

The script refuses to run when `~/.local/opt/llama.cpp` already exists, rather than overwriting, and stages the archives in `~/.cache/llama-install` with `curl -C -`. Both matter on this link: a first attempt was cut mid-download on 2026-09-21 when the WSL instance idled out, and a retry then resumes instead of pulling 728 MiB again. That staging directory is kept on purpose, the connection being metered.

The script as run, sent from `ju-TP` with `ssh ju-TP2 'bash -s' < install-llama-cuda.sh`. Tilde fence: it installs, so `verify` must never replay it.

~~~bash
#!/usr/bin/env bash
# Install the CUDA build of llama.cpp on ju-TP2, same layout as the CPU build
# that _meta/notes/llama-server-install.md fixed for ju-TP.
set -euo pipefail

VER=b11065
CUDA=12.8
DEST="${HOME}/.local/opt/llama.cpp"
BASE="https://github.com/ggml-org/llama.cpp/releases/download/${VER}"
MAIN="llama-${VER}-bin-ubuntu-cuda-${CUDA}-x64.tar.gz"
RT="cudart-llama-${VER}-bin-ubuntu-cuda-${CUDA}-x64.tar.gz"
STAGE="${HOME}/.cache/llama-install"

if [ -e "${DEST}" ]; then
  echo "refusing: ${DEST} already exists" >&2
  exit 1
fi

mkdir -p "${STAGE}"

echo "[1/6] Download ${MAIN}"
curl -fL -C - --retry 5 --retry-all-errors -o "${STAGE}/${MAIN}" "${BASE}/${MAIN}"
echo "[2/6] Download ${RT}"
curl -fL -C - --retry 5 --retry-all-errors -o "${STAGE}/${RT}" "${BASE}/${RT}"

echo "[3/6] Extract"
rm -r -- "${STAGE}/main" "${STAGE}/rt" 2>/dev/null || true
mkdir -p "${STAGE}/main" "${STAGE}/rt"
tar -xzf "${STAGE}/${MAIN}" -C "${STAGE}/main"
tar -xzf "${STAGE}/${RT}" -C "${STAGE}/rt"

SRC=$(dirname "$(find "${STAGE}/main" -type f -name llama-server -print -quit)")
echo "      binaries in ${SRC#"${STAGE}"/}"

echo "[4/6] Install to ${DEST}"
mkdir -p "${DEST}"
cp -a "${SRC}/." "${DEST}/"
find "${STAGE}/rt" -type f -exec cp -a {} "${DEST}/" \;

echo "[5/6] Symlink ~/.local/bin/llama-server"
mkdir -p "${HOME}/.local/bin"
ln -sfn "${DEST}/llama-server" "${HOME}/.local/bin/llama-server"

echo "[6/6] Verify"
"${DEST}/llama-server" --version 2>&1 | head -8
echo "--- CUDA libs beside the binaries ---"
find "${DEST}" -maxdepth 1 -name 'libcuda*' -o -maxdepth 1 -name 'libggml-cuda*' | sort
echo "--- tree size ---"
du -sh "${DEST}"
~~~

It reported `binaries in main/llama-b11065`, then the install, the symlink, and a tree of 1.1 GiB.

Verification, replayable from `ju-TP` while the WSL instance on `ju-TP2` is up. Read-only: it starts nothing and writes nothing.

```bash
ssh ju-TP2 'D=~/.local/opt/llama.cpp; "$D/llama-server" --version 2>&1 | rg "^version|^built"; ldd "$D/libggml-cuda.so" | rg -o "lib(cuda|cudart)[^ ]* => [^ ]*"; "$D/llama-cli" --list-devices 2>&1 | tail -2' </dev/null 2>&1 | tr -d "\r"
```

```output
version: 0.4.1-dev (build 11065, commit ce8caa6e6)
built with GNU 13.3.0 for Linux x86_64
libcudart.so.12 => /home/julien/.local/opt/llama.cpp/libcudart.so.12
libcuda.so.1 => /usr/lib/wsl/lib/libcuda.so.1
Available devices:
  CUDA0: NVIDIA RTX A3000 12GB Laptop GPU (11519 MiB, 10470 MiB free)
```

What this does not establish. Device enumeration proves the backend loads and sees the GPU; it says nothing about a model actually running on it. The criterion `.claude/DESIGN-GPU-REMOTE.md` sets for this step is a non-zero VRAM allocation under `nvidia-smi` while a model is loaded, which belongs to step 2 and its smoke-test GGUF. Free VRAM also moves with the Windows desktop: 11262 MiB measured on 2026-09-20 against 10470 MiB here, with a Positron remote session open.

Standing constraint this install inherits: WSL on `ju-TP2` idles out and nothing holds it up, the `WSL-KeepAlive` scheduled task having run once on 2026-09-19 and ended on exit code 1 (`.claude/DESIGN-SSH.md`, "Keeping WSL alive", reopened 2026-09-21). Every long transfer over this link needs a terminal or a Positron connection open on `ju-TP2` for the duration.
