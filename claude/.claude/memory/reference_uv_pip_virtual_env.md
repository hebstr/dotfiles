---
name: uv pip targets $VIRTUAL_ENV, not the project you cd into
description: `uv pip install` in project B installs into project A's venv when VIRTUAL_ENV still points at A (use `env -u VIRTUAL_ENV`); plus the two neighbouring traps of a cross-project editable install, `uv run` not purging it and a missing `-e` silently freezing a copy
metadata:
  type: reference
---

`uv pip install` resolves its target environment from `$VIRTUAL_ENV` before the current directory. Working in project A, then running `cd B && uv pip install -e ...` installs into **A's** venv and reports success. `uv pip list --directory B` misreports the same way. `uv run` is immune: it ignores the mismatch with a warning and uses the project env, which is why tests can fail on a module the install claimed to place.

Remedy: `env -u VIRTUAL_ENV uv pip install ...`, or pass `--python .venv/bin/python3` explicitly.

The failure is silent at install time and surfaces later as `ModuleNotFoundError` in the project that was supposed to receive the package, so it reads as a broken install rather than a misdirected one.

Observed 2026-07-28 on the `py-edscrib` / `eds-avc` pair, where `uv pip install -e ../../../packages/py-edscrib` is prescribed after every `uv sync` of the consumer, so the crossing happens often. Applies to any two uv projects touched in one session.

**Two neighbouring facts, both measured 2026-07-29 on that pair.**

`uv run` does not purge an editable install placed beside the lock, despite syncing before each invocation: three bare calls (`python -c`, `pytest`, `streamlit`) left it in place, still editable and still resolving to the source tree. Only `uv sync` removes it. A `--no-sync` prescribed on that belief is harmless but buys nothing, and asserting it in a project's own docs sends every later reader down a precaution that is not one.

`uv pip install <path>` without `-e` is the silent failure mode of the same workflow. It succeeds, the import resolves, every test passes, and the consumer is exercising a **frozen copy** taken at install time rather than the working tree. Nothing in the import surfaces it; `dist-info/direct_url.json` is the tell, `{"dir_info":{}}` for a copy against `{"dir_info":{"editable":true}}` for the real thing. Compare `pkg.__file__` too: it lands in `site-packages/` for a copy and in the source tree for an editable install. The danger is a green verification of a fix the venv cannot see, which is worse than the loud `ModuleNotFoundError` above.

See [[feedback_verify_after_install]] for the general habit of smoke-testing an install end-to-end rather than trusting its exit code.
