# Deploy llama-update on ju-TP2

*2026-09-21T09:13:14Z by Showboat 0.6.1*
<!-- showboat-id: f1b2bb96-085e-46e7-950c-afadb77bfaeb -->

Step 6 of `.claude/DESIGN-GPU-REMOTE.md`, run 2026-09-21 from `ju-TP` over `ssh ju-TP2`. The first run of `llama-update` migrates the plain `~/.local/opt/llama.cpp` directory installed by `_meta/notes/llama-cuda-install-ju-tp2.md` into `~/.local/opt/llama.cpp-b11065` behind a symlink, with no download since `b11065` is already the installed build.

Syncthing was stopped on `ju-TP` at the time (`syncthing.service` disabled, last failure 2026-09-19 on a held lock), so the script had not reached the `ju-TP2` copy of the dotfiles and `stow` there had nothing to link. The script is self-contained, so it was sent over `bash -s` for this first run, and linking it with `stow` came after the sync.

Every step that changes state, and the state before it, sits in a tilde fence with its observed output, so `verify` never replays it: the state before stops being true the moment the migration runs. The replayable checks at the end read only what characterises the deployment (link targets, a CUDA device listed, the installed builds), never free VRAM, timestamps or whether a session happens to be running.

State before, observed:

~~~bash
ssh ju-TP2 'ls -ld .local/opt/llama.cpp*; readlink .local/bin/llama-server; .local/opt/llama.cpp/llama-server --version 2>&1 | grep "^version"'
~~~

~~~text
drwxr-xr-x 2 julien julien 4096 Sep 21 00:28 .local/opt/llama.cpp
/home/julien/.local/opt/llama.cpp/llama-server
version: 0.4.1-dev (build 11065, commit ce8caa6e6)
~~~

The migration, no `llama-server` running at the time:

~~~bash
ssh ju-TP2 'bash -s -- b11065' < bin/.local/bin/llama-update
~~~

~~~text
Moving the existing install to /home/julien/.local/opt/llama.cpp-b11065
Already on b11065: nothing to do.
~~~

Once Syncthing ran again on `ju-TP` and both scripts had reached `ju-TP2` byte for byte, the package was linked there. The dry run (`stow -n -v --no-folding bin`) announced exactly these two links and no conflict:

~~~bash
ssh ju-TP2 'cd dotfiles && stow -v --no-folding bin'
~~~

~~~text
LINK: .local/bin/llama-update => ../../dotfiles/bin/.local/bin/llama-update
LINK: .local/bin/llama-session => ../../dotfiles/bin/.local/bin/llama-session
~~~

The staging directory `~/.cache/llama-install` left by the manual install, 1.8 GiB, was then removed by the user, the `b11065` tree no longer needing it.

Checks, replayable while the WSL instance on `ju-TP2` is up. The active link and the path `llama-session` launches, which resolves through it:

```bash
ssh ju-TP2 'readlink .local/opt/llama.cpp; readlink -e .local/bin/llama-server; test -x .local/opt/llama.cpp/llama-server && echo "llama-session path resolves"' </dev/null 2>&1 | tr -d "\r"
```

```output
llama.cpp-b11065
/home/julien/.local/opt/llama.cpp-b11065/llama-server
llama-session path resolves
```

The build reached through the link still lists the GPU, free memory stripped:

```bash
ssh ju-TP2 '.local/opt/llama.cpp/llama-cli --list-devices 2>&1 | grep -o "CUDA0: [^(]*" | sed "s/ *$//"' </dev/null 2>&1 | tr -d "\r"
```

```output
CUDA0: NVIDIA RTX A3000 12GB Laptop GPU
```

Both scripts are linked from the package, and `llama-update` answers by its own path, which is how it is called from `ju-TP` since that SSH PATH carries no `~/.local/bin`:

```bash
ssh ju-TP2 'readlink .local/bin/llama-update .local/bin/llama-session; .local/bin/llama-update --list' </dev/null 2>&1 | tr -d "\r"
```

```output
../../dotfiles/bin/.local/bin/llama-update
../../dotfiles/bin/.local/bin/llama-session
  b10969
* b11065
```

The staging directory is gone:

```bash
ssh ju-TP2 'test -e .cache/llama-install && echo present || echo absent' </dev/null 2>&1 | tr -d "\r"
```

```output
absent
```

## First fresh install and rollback, 2026-09-21

The deployment above only migrated a build already on disk, so the download path was exercised next, with no tag. A first run failed safely on a 404: `b10964`, the stable build, ships no Ubuntu CUDA archive, and upstream skips that build on about a quarter of tags. The script then gained the CUDA fallback and the archive preflight recorded in `.claude/DESIGN-GPU-REMOTE.md`, section "What the first live install showed", and was run again, detached so a cut of the SSH session could not stop it. Tilde fences: each run changes the active build.

~~~bash
ssh ju-TP2 'setsid nohup .local/bin/llama-update >/tmp/llama-update.log 2>&1 </dev/null &'
~~~

~~~text
Latest stable build: b10964
b10964 ships no CUDA 12.8 x64 archives, taking b10969
Downloading llama-b10969-bin-ubuntu-cuda-12.8-x64.tar.gz
Downloading cudart-llama-b10969-bin-ubuntu-cuda-12.8-x64.tar.gz
Active build: b10969 (previous b11065 kept for rollback)
~~~

`b10969` served the smoke-test model on the GPU at 63 tok/s but ignored `--reasoning-budget 0` (177 tokens and 631 characters of reasoning to answer "ok", against 4 tokens and none on `b11065`), so the machine was rolled back, with no download:

~~~bash
ssh ju-TP2 .local/bin/llama-update b11065
~~~

~~~text
Build b11065 is already on disk: switching to it without downloading.
Active build: b11065 (previous b10969 kept for rollback)
~~~

The checks above replay against that final state: `b11065` active, `b10969` kept, the staging directory cleared by the successful install.

The script then gained its last rule: without a tag it never goes below the active build, so the stable-anchored default cannot silently repeat that downgrade. Run the same day on `ju-TP2`, `b11065` active. It changes nothing, and it sits in a tilde fence anyway because its output moves with every upstream `v*` release:

~~~bash
ssh ju-TP2 .local/bin/llama-update
~~~

~~~text
Latest stable build: b10964
b10964 ships no CUDA 12.8 x64 archives, taking b10969
The active b11065 is newer than the default b10969: nothing to do (pass a tag to downgrade).
~~~
