---
name: edscrib, the annotation socle, dormant since 2026-10-19
description: "edscrib (~/Documents/packages/py-edscrib) is asleep: eds-avc stopped consuming it and rebuilt its annotation on a local annot/core/, taking the package's own hardened bodies; where the tracker went and what constraint still binds"
metadata:
  type: project
---

The Streamlit annotation apps of `eds-avc` were factored into one config-driven engine and moved to the Python package `edscrib`, so that several EDS projects could share one socle. Package and remote are `hebstr/edscrib`; the local directory carries a language prefix, `~/Documents/packages/py-edscrib`, as `R-edstr` does for `hebstr/edstr`.

**Decision of 2026-10-19, user: the package is dormant and will be reworked from scratch later.** `eds-avc` stopped consuming it the same day. Its two apps, five-line shims onto `edscrib.app.run_app` that only ran behind an editable overlay `uv sync` purges, became one entrypoint over a local `annot/core/`, and `rg -i edscrib` outside the project's `.claude/` returns nothing.

**The shape question was settled by local precedent, not by the sibling project.** `pred/lib/` in the same repository already runs a script owning its paths and reads over plain modules, so `eds-prise/annot/` supplied the practice (the receives-data rule, the root `.streamlit/`, `smoke_startup.py` as the gate) while the **bodies came from the package**, whose versions are the later hardened ones on every module taken: the empty-password guard, one `SecretsError` over four failures, NFC per RFC 8265, and the five export refusals of the 2026-07-31 reviews. Rebuilding from the `eds-prise` side was weighed and refused as a measured regression on those four fronts. The local package is `core/` and not `lib/`, `pred/lib/` already holding that top-level name and two packages named `lib` not coexisting in one interpreter, which pytest's collection makes them do.

**Tracker: `~/Documents/packages/py-edscrib/.claude/ANNOT-PKG.md`**, moved there on 2026-10-19 beside that directory's `CLAUDE.md` and `DEFERRED.md`, its opening pointer rewritten to say step 6 died with the suspension. The unarbitrated `EMPTY` sentinel entry went with it, as a row and a note of that repository's own `DEFERRED.md`. Step 6 of the old plan (tag `v0.1.0`, `__all__`, Git dependency) is abandoned. Review calibration: [[feedback_review_severity_edscrib]].

**The one constraint that outlives the package:** an internal package never enters a project's `pyproject.toml` as a path or editable dependency. The CHU server checks `eds-avc` out at `~/data/eds-avc`, where a relative `[tool.uv.sources]` path resolves outside `$HOME` and breaks `uv sync` at the first pull; such an entry also does not survive wheel construction (uv#7167). If an internal package is consumed again here, it is as a Git tag over HTTPS. Why an editable install needs `env -u VIRTUAL_ENV`: [[reference_uv_pip_virtual_env]].
