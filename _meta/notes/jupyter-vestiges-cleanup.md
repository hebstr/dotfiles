# Removal of vestigial Jupyter launchers and kernelspecs

*2026-09-12T08:49:54Z by Showboat 0.6.1*
<!-- showboat-id: fb9e1bad-8c8c-47bd-9ae7-be841e74f1c4 -->

Three Jupyter kernelspecs were registered on this machine and only one resolved. Two independent residues sat behind that state, and they are worth separating because each breaks a different thing.

The `jupyter` on the PATH was a set of launcher scripts left behind by a `pip install --user` whose packages no longer exist, so `jupyter kernelspec` failed on a missing `jupyter_client`. That is what made `ggsql-jupyter --install` fail. The apt package `python3-jupyter-core` ships the library and no script, so those scripts were the only `jupyter` command on the system.

Separately, the dead `python3` kernelspec made Quarto believe a Python kernel existed, so `quarto check` attempted an engine render and crashed on a missing `nbclient`. Quarto's `Jupyter: 5.3.2` line does not come from the launcher scripts at all: it reads `jupyter_core` importable by the interpreter it selects, which is apt's copy under `/usr/lib/python3/dist-packages`. Removing the scripts therefore does not change that line, and the verification at the end of this document shows it unchanged.

Real consumption measured first: 6 of 460 `.qmd` carry `{python}` chunks, all under `~/Documents/sandbox/`, and the machine holds no `.ipynb`. Nothing was rebuilt for that reason; the per-project `uv` route covers the day a document needs Python.

```bash
ls -1 ~/.local/bin/jupyter* 2>/dev/null
echo "--- kernelspecs:"
ls -1 ~/.local/share/jupyter/kernels/
echo "--- targets each kernelspec resolves to:"
for k in py13 python3; do
  printf "%s -> " "$k"
  jq -r ".argv[0]" ~/.local/share/jupyter/kernels/$k/kernel.json
done
echo "--- apt package provides no launcher:"
dpkg -L python3-jupyter-core | grep -c "bin/" || true
```

```output
/home/julien/.local/bin/jupyter
/home/julien/.local/bin/jupyter-kernel
/home/julien/.local/bin/jupyter-kernelspec
/home/julien/.local/bin/jupyter-migrate
/home/julien/.local/bin/jupyter-run
/home/julien/.local/bin/jupyter-troubleshoot
--- kernelspecs:
ggsql
py13
python3
--- targets each kernelspec resolves to:
py13 -> /home/julien/envs/py13/bin/python
python3 -> python
--- apt package provides no launcher:
0
```

Neither target exists: `~/envs` is gone and there is no bare `python` on the PATH, which is normal under uv. The `ggsql` kernelspec calls `ggsql-jupyter` by bare name and resolves since `uv tool install ggsql-jupyter` put it in `~/.local/bin`, so it is kept. The `ark` R kernel Quarto also lists is supplied by Positron and lives outside this directory.

Step 1, remove the six orphaned launchers. The apt packages stay: `python3-jupyter-core` is required by `python3-nbformat`, itself required by the installed `python3-plotly`.

```bash
rm -f ~/.local/bin/jupyter ~/.local/bin/jupyter-kernel ~/.local/bin/jupyter-kernelspec \
       ~/.local/bin/jupyter-migrate ~/.local/bin/jupyter-run ~/.local/bin/jupyter-troubleshoot
rm -rf ~/.local/share/jupyter/kernels/py13 ~/.local/share/jupyter/kernels/python3
echo "remaining jupyter launchers:"
ls -1 ~/.local/bin/jupyter* 2>/dev/null || echo "  none"
echo "remaining kernelspecs:"
ls -1 ~/.local/share/jupyter/kernels/
echo "apt packages untouched:"
dpkg -l python3-jupyter-core python3-nbformat python3-plotly 2>/dev/null | awk "/^ii/ {print \"  \" \$2, \$3}"
```

```output
remaining jupyter launchers:
  none
remaining kernelspecs:
ggsql
apt packages untouched:
  python3-jupyter-core 5.3.2-1ubuntu1
  python3-nbformat 5.9.1-1
  python3-plotly 5.15.0+dfsg1-1
```

Verification. `Jupyter: 5.3.2` stays, for the reason given above. What changes is the kernel list and what Quarto does with it: with no Python kernel left to mislead it, the engine render is not attempted and the report ends on `NOTE: No Jupyter kernel for Python found`, which is the honest state. The full output carries that NOTE; the filter below keeps the identification lines.

```bash
quarto check jupyter 2>&1 | sed "s/\x1b\[[0-9;]*[A-Za-z]//g; s/\r/\n/g" | grep -E "Version:|Path:|Jupyter:|Kernels:|Jupyter engine|No module|Unable" | sed "s/^ *//" | sort -u
```

```output
Jupyter: 5.3.2
Kernels: ark, ggsql
Path: /usr/bin/python3
Version: 3.12.3
```

The day a document needs the Jupyter engine, the dependency set verified on 2026-09-12 is `ipykernel` plus `nbclient` plus `pyyaml`: `uv add --dev ipykernel nbclient pyyaml` in the project, or `uv run --with ipykernel --with nbclient --with pyyaml quarto render doc.qmd` for an isolated file. `pyyaml` is load-bearing because `/opt/quarto/share/jupyter/notebook.py` imports `yaml` directly; the first attempt without it failed on `No module named 'yaml'` after clearing `nbclient`. The two others pull `jupyter_client` 8.10.0 and `nbformat` 5.11.1.

A scan of every Python-shebang script in the directory, testing whether each entry module still imports, found three more orphans from the same batch: `debugpy`, `ipython` and `ipython3`, all dated 12 January 2025 with the same `/bin/python3` shebang. Nothing consumes them. The dotfiles hold no reference, and Positron's Jupyter extension carries its own `install_debugpy.py` rather than looking for a `debugpy` on the PATH. `~/.local/lib/` is left in place: empty, inert, and recreated by any `pip install --user` anyway.

```bash
rm -f ~/.local/bin/debugpy ~/.local/bin/ipython ~/.local/bin/ipython3
echo "scripts left carrying the dead literal shebang:"
grep -Il "^#!/bin/python3$" ~/.local/bin/* 2>/dev/null || echo "  none"
echo "a uv tool shim, for contrast:"
head -1 ~/.local/bin/yt-dlp
echo "kernelspecs:"
ls -1 ~/.local/share/jupyter/kernels/
```

```output
scripts left carrying the dead literal shebang:
  none
a uv tool shim, for contrast:
#!/home/julien/.local/share/uv/tools/yt-dlp/bin/python3
kernelspecs:
ggsql
```

The check is written against the literal `#!/bin/python3` on purpose. A looser `bin/python3` pattern also matches every uv tool shim, whose shebang points into its own managed venv, and so reports seven healthy scripts as suspects.
