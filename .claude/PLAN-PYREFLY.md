# PLAN-PYREFLY.md

Design note: integrating `pyrefly` (Python type checker, part of the `rules/python.md` gate) into the repository's install/update system.

Applied in full on 2026-07-27, on the verdict that there was nothing to build: pyrefly's distribution form (a uv tool) already had its aggregator in the `uv-tools` module of `sys-update`.
What is left of it no longer lives here but in the files that carry the gate: `rules/python.md` (the single-binary setup and its way back, the `basic` fallback and the conditional `-p default` branch, the preset parity, the prek hook), `rules/install.md` in the section "One tool, one binary" (the table of the three setups and the `command -v` reflex), `_meta/notes/environment-archive.md` (the same coverage audit, with the `uv` duplicate and the `uvx` collateral its removal left behind), `_meta/notes/pyrefly-install.md` (the installation record), `reference_tool_update_routines` (the per-routine decision rule, which names pyrefly) and `feedback_review_severity_shell_installers` (the rejection of the uv installation manifest, 2026-10-12).

## Preset: why `default`, and not `strict`

The setting is written on both sides (`python.pyrefly.typeCheckingMode` in the Positron settings, `-p default` in the gate's config-less branch), and `rules/python.md` carries the parity without carrying the reason for it.
The two other levels stay rejected: `basic` is the weakened fallback the conditional branch exists to avoid, and `strict` is a per-project choice, never a machine default, the project config taking over when it declares one.
What `basic` disables is read in `pyrefly check --help`, which states it preset by preset.

## Adversarial review

Of the three audits the batch had proposed, only one is still open, and it is the last live item of this note:

- `/audit:blindspot claude/.claude/rules/environment.md`: obsolete, the file was deleted in `daa2729` and its content moved to `_meta/notes/environment-archive.md`; retarget or drop is the user's call.
