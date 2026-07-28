---
name: uv pip targets $VIRTUAL_ENV, not the project you cd into
description: `uv pip install` in project B installs into project A's venv when VIRTUAL_ENV still points at A; use `env -u VIRTUAL_ENV` when working across two uv projects in one session
metadata:
  type: reference
---

`uv pip install` resolves its target environment from `$VIRTUAL_ENV` before the current directory. Working in project A, then running `cd B && uv pip install -e ...` installs into **A's** venv and reports success. `uv pip list --directory B` misreports the same way. `uv run` is immune: it ignores the mismatch with a warning and uses the project env, which is why tests can fail on a module the install claimed to place.

Remedy: `env -u VIRTUAL_ENV uv pip install ...`, or pass `--python .venv/bin/python3` explicitly.

The failure is silent at install time and surfaces later as `ModuleNotFoundError` in the project that was supposed to receive the package, so it reads as a broken install rather than a misdirected one.

Observed 2026-07-28 on the `py-edscrib` / `eds-avc` pair, where `uv pip install -e ../../../packages/py-edscrib` is prescribed after every `uv sync` of the consumer, so the crossing happens often. Applies to any two uv projects touched in one session.

See [[feedback_verify_after_install]] for the general habit of smoke-testing an install end-to-end rather than trusting its exit code.
