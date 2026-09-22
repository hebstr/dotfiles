---
name: edscrib, the annotation socle extracted out of eds-avc
description: "eds-avc's Streamlit annotation socle lives in the Python package edscrib (~/Documents/packages/py-edscrib): where the tracker lives, the constraints not to re-litigate, and what step 6 still owes"
metadata:
  type: project
---

The Streamlit annotation apps of `eds-avc` were factored into one config-driven engine and moved to the Python package `edscrib`, so that several EDS projects share one socle. Package and remote are `hebstr/edscrib`; the local directory carries a language prefix, `~/Documents/packages/py-edscrib`, as `R-edstr` does for `hebstr/edstr`.

**Tracker: `eds-avc/.claude/ANNOT-PKG.md`**, gitignored, on this machine only; it holds the design, the per-pass record and the step order. `py-edscrib/.claude/CLAUDE.md` points back to it and carries the frontier rule, structural constraints and Streamlit traps; it is deliberately the package's only Claude file. Review calibration: [[feedback_review_severity_edscrib]].

**State, re-derived 2026-09-22:** `main` is at `e327599`, 30 commits, pushed and level with `origin/main`. Step 6 (`ANNOT-PKG.md`, "Publier le dépôt, taguer `v0.1.0`, basculer `eds-avc` sur la dépendance Git") still owes the `v0.1.0` tag, the contents of `__all__` (empty), and the switch of `eds-avc` to the Git dependency. The `EMPTY` sentinel entry of `eds-avc/.claude/DEFERRED.md` is unarbitrated, with the tag as its hard deadline. Counts (guards, tests) move on every pass: re-derive them from the code, never carry them.

**Constraints, decided and not to re-litigate:**

- `edscrib` never enters `eds-avc/pyproject.toml` as a path or editable dependency: the CHU server checks the project out at `~/data/eds-avc`, where a relative `[tool.uv.sources]` path breaks `uv sync`. The dependency appears only at release, as a Git tag over HTTPS.
- Development install: `uv run --with-editable ../../../packages/py-edscrib <cmd>` while nothing imports the package; once the apps import it, `env -u VIRTUAL_ENV uv pip install -e ../../../packages/py-edscrib` (the `pyrefly` hook is pinned to `.venv/bin/python3`). `uv sync` purges it, so a `ModuleNotFoundError: edscrib` after a sync is the purge, not a regression. See [[reference_uv_pip_virtual_env]].
- PyPI dependencies only, never another internal package as a Git dependency: `[tool.uv.sources]` does not survive wheel construction (uv#7167).
- Nothing AVC-specific descends: column names, labels, classification levels, `.streamlit/secrets.toml`, `data/`, `tuto.webm` and the R scripts stay in `eds-avc`.
- Characterization tests against a frozen baseline of the real `2023-01` split stay in `eds-avc/tests/pytest/`; the package tests pure logic on synthetic fixtures.
