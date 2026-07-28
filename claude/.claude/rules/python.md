---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/*.ipynb"
  - "**/pyproject.toml"
  - "**/pyrefly.toml"
  - "**/ruff.toml"
---

# Python toolchain

## Code style conventions

- Prefer polars over pandas unless the project already uses pandas
- Before recommending `from pkg import fn` or `pkg.fn`, verify the symbol exists and is importable: `python -c "from pkg import fn"` (exits non-zero if the name is absent or the import path is wrong). Inside a project, run it through the project env: `uv run python -c "from pkg import fn"`. This is the Python analog of the R `getNamespaceExports` export check in `rules/r.md`

## Preserving analysis code

This code exists for a data science/biostatistics purpose. When editing it for infrastructure, code-quality, or refactoring reasons, do not alter its analysis semantics:

- Joins: always use explicit keys; check for NA on join keys after every join
- Domain-specific regex or business rules: do not "fix" or tighten without explicit domain validation
- LLM inference parameters (temperature, top_p, seed): do not change without documented justification (breaks reproducibility of existing results)
- Calculated approximations (e.g. age from date diff / 365.25): flag but do not auto-correct, often intentional for consistency with institutional conventions

## CLI tools

| Tool | Role |
|---|---|
| `ruff format` | Formatter |
| `ruff check` | Linter (static analysis + auto-fix) |
| `pyrefly check` | Type checker |

Prefer `uv run ruff` in a project that pins `ruff` as a dev-dependency, so the gate runs the pinned version rather than the PATH one. Config discovery is not a reason to prefer it: ruff walks up from the target file to find `pyproject.toml` or `ruff.toml` whichever binary runs. With no pin, the global `ruff` is correct, which is what the pipeline below and the `format-on-edit` hook both use.

`pyrefly` (Meta) is the type checker of record: it is the one Positron installs by default (`meta.pyrefly` sits in Positron's `bootstrapExtensions`), and it is the checker whose diagnostics the editor shows. The extension ships its own binary under `~/.positron/extensions/meta.pyrefly-*/bin/pyrefly` and ignores the PATH, so terminal and editor would run two binaries updated by two independent channels (`sys-update uv-tools` for the CLI, `sys-update positron` for the extension). Positron's `pyrefly.lspPath` is set to the uv-installed CLI to collapse them into one binary; if a Positron upgrade ever ships an extension needing a newer LSP protocol than the CLI, clearing that setting is the way back.

Preset parity matters as much as version parity. Positron's `python.pyrefly.typeCheckingMode` is the editor-side equivalent of the CLI's `-p`: both apply only to files no `pyrefly.toml` covers, and both are set to `default`, so the editor and the gate flag the same code.

Do not add a second type checker beside it. `pyright` duplicates its diagnostics while Positron disables half its features (`pyright.disableLanguageServices` is forced on), and `ty` (Astral) is still `0.0.x` with an explicit no-stable-API policy: "breaking changes, including changes to diagnostics, may occur between any two versions". A gate needs one authority. `uvx ty check` as an occasional second opinion is fine as long as pyrefly stays the one that decides.

## Mandatory pipeline after every create/edit

```sh
ruff check --fix script.py
ruff format script.py
ruff check script.py
pyrefly check script.py
```

If that `pyrefly check` prints `` using preset `basic` ``, no config governs the file: re-run it as `pyrefly check -p default script.py` and take that as the result. See below.

Order matters: `ruff check --fix` first (auto-fix may leave whitespace), then `ruff format` cleans it, then a final `ruff check` confirms no residual violations. Per ruff docs. Do not chain them with `&&`: `ruff check --fix` exits non-zero when unfixable violations remain, which is expected churn rather than a hard failure, and `&&` would skip the formatter and the confirming pass. Type checking comes after, since formatting never changes types and a type error costs more to read than a lint violation. Tests come last. If the project has Python tests (a `tests/` directory holding `test_*.py`, or a `[tool.pytest.ini_options]` table in `pyproject.toml`), run `uv run pytest <test-file>` for the module just edited; when no test file maps to it, run `uv run pytest` from the project root.

When the edit changes a function signature, or renames or removes a symbol other files import, widen the last step to the whole project: `pyrefly check` with no path argument, or `pyrefly check -p default` in the no-config branch. Single-file mode reports `0 errors` on the edited file while a broken caller sits in another one. The three `ruff` commands stay file-scoped, since each analyses its target independently.

`pyrefly check` exits non-zero on any error, so it gates like `ruff check`.

## Without a config, pyrefly checks almost nothing

**`pyrefly check` is close to a no-op when no pyrefly config governs the file.** With no `pyrefly.toml` and no `[tool.pyrefly]` table anywhere above it, pyrefly falls back to the `basic` preset, which reports `0 errors` and exits 0 even on a blatant `bad-return`. The fallback applies in both single-file mode and project mode (`pyrefly check` with no argument, which prints `Checking current directory with auto configuration`). A `pyproject.toml` alone does not lift it; the `[tool.pyrefly]` table is what switches full checking on, and an **empty** table suffices, as does an empty `pyrefly.toml`.

The tell is the notice itself, followed by an install-docs pointer. Quoted byte-exactly below, backticks included, because a grep that drops them matches nothing:

```
No `pyrefly.toml` found — using preset `basic`.
```

Never report a file as type-checked on the strength of a `0 errors` line carrying that notice.

That notice is also the branch selector, and the only reliable one: pyrefly walks up the filesystem to find a config, so testing the current directory for `pyrefly.toml` or `[tool.pyrefly]` misses one declared higher in the tree. Run bare first, then react to what it printed:

```sh
pyrefly check <path> 2>&1               # notice and error count both go to stderr, so a capture must merge
pyrefly check -p default <path> 2>&1    # only if the run above emitted the fallback notice
```

- **No notice**: a config governs the file. The bare run is the result; its own preset and rule severities decide.
- **Notice present**: nothing governs the file, so the first run proved nothing. Re-run with `-p default` and take that as the result. `-p` supplies a base configuration without any file. `default` is the baseline preset. Omitting `-p` gives the same thing only when a config governs the check; with no config it falls back to `basic`, which is why this branch passes `-p default` explicitly. `basic` being that weakened fallback, it is never the right explicit choice here.

**Never pass `-p` when a config exists.** The flag overrides the config's preset in both directions: `-p basic` silences a project that declared `strict`, and `-p default` overrides one that declared `off`. A project that pinned its own preset did so deliberately.

Standalone scripts outside any project are covered by the `-p default` branch, not exempt from the type check. Only report the step as not run when `pyrefly` itself is missing.

## Useful flags

**ruff format**

| Flag | Effect |
|---|---|
| `--check` | Dry-run, exits non-zero if file would change |
| `--diff` | Show diff without writing |

**ruff check**

| Flag | Effect |
|---|---|
| `--fix` | Auto-fix safe violations |
| `--unsafe-fixes` | Include fixes that may alter intent |
| `--select RULE` | Run specific rules only (e.g. `--select E,F`) |
| `--show-fixes` | List all applied fixes |

**pyrefly check**

| Flag | Effect |
|---|---|
| `-p, --preset NAME` | Base configuration when no config file governs the file: `off`, `basic`, `legacy`, `default`, `strict`, `all`. Overrides a config's preset when one exists, so pass it only in the no-config branch |
| `-c, --config FILE` | Use an explicit config instead of discovery |
| `--project-excludes GLOB` | Exclude paths from the check |
| `--output-format FORMAT` | `min-text`, `full-text`, `json`, `github`, `junit-xml`, `omit-errors` |
| `--watch` | Re-check on file change (flagged highly experimental upstream) |

Other pyrefly subcommands worth knowing: `init` (create a config, or migrate one from mypy/pyright), `suppress` (add or prune ignore comments), `infer` (add annotations), `snippet` (check a code string).

## Syntax check without executing

```sh
python -m py_compile script.py
```

Scope: `.py` and `.pyi` only. On a `.ipynb` this compiles the JSON envelope rather than the cell source, so it exits 0 even when a cell holds broken Python. Use `ruff check <notebook>.ipynb` there, which parses cells individually and reports the real position.

## Streamlit

Streamlit apps follow the same `ruff` gate as any Python file; there is no Streamlit-specific linter, and the gate does not run the app. For a manual smoke check, `streamlit run app.py` launches the dev server, but it stays in the foreground serving until interrupted, so it is not exit-code-testable: run it optionally while iterating, never as part of the automated gate.

`streamlit.testing.v1.AppTest` is the exit-code-testable substitute, and the only way to prove an app still starts after a dependency bump: `AppTest.from_file(path).run()` executes the script headlessly, and `at.exception` collects what it raised. Two traps:

- **`AppTest` does not add the script's directory to `sys.path`**, unlike `streamlit run`. An app importing a sibling package (`from lib.foo import bar`) raises `ModuleNotFoundError` under `AppTest` until that directory is inserted by hand. Installed packages are immune, which is one more reason to package shared app code rather than import it by adjacency.
- It does not re-execute interaction code inside `st.dialog` after a rerun (streamlit#9786), and is incompatible with `st.fragment` (streamlit#9242), both open upstream. Keep the logic those wrap in plain functions, tested separately, and let the decorated shell hold display only.

## Standalone scripts: PEP 723 inline metadata

For single-file Python tools under `~/dotfiles/bin/.local/bin/` or any reusable standalone script, declare deps inline and run via `uv run --script`:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["polars", "rich"]
# ///
```

Self-contained, no venv to manage, deps versioned in the file. Make the file executable (`chmod +x`) and uv resolves/installs deps on first run.

Scope: standalone scripts only. Package code stays in `pyproject.toml`; project analysis notebooks use the project's `uv` env.

## Pre-commit hook (prek)

The `_meta/profiles/prek.toml` scaffold carries two Python families. From `astral-sh/ruff-pre-commit`, `ruff-check` with `--fix` then `ruff-format`, in that order: the linter's fixes can leave whitespace the formatter then cleans, which is why upstream's own README puts them this way and why the local gate does too. The hook id is `ruff-check`; plain `ruff` still resolves but the upstream manifest labels it "ruff (legacy alias)".

From `facebook/pyrefly-pre-commit`, `pyrefly-check`. Two properties to keep in mind. It declares `pass_filenames: false`, so it type-checks the whole project rather than the staged files, which makes it slower than the ruff pair and makes its result independent of what is being committed. And it inherits the config caveat above: on a project with no `[tool.pyrefly]` table and no `pyrefly.toml` it exits 0 without checking anything, so adopting the hook means adding that table. Do not give it `-p`: the scaffold is generic, and the flag would override the preset of any project that pinned its own.

Adopting the hook takes two config keys the plain CLI does not need, both learned the hard way and both to add when wiring it into a project:

- **`python-interpreter-path`.** prek runs the hook in its own isolated environment, so pyrefly queries prek's interpreter and resolves site-packages to `~/.cache/prek/hooks/python-*/`. Every third-party import then reads as `missing-import`, while the same check from the terminal passes because it auto-detects `.venv`. Pin it: `python-interpreter-path = ".venv/bin/python3"`.
- **`project-excludes`.** Whole-project mode reaches directories a hand-scoped `pyrefly check <dir>` never sees, including vendored Python inside other ecosystems' package libraries (an R project's `rv/library/**` holds one, openxlsx2 ships a fontTools script). The value is appended to pyrefly's defaults, not substituted, unless `disable-project-excludes-heuristics` is set.

Both symptoms look like project bugs and are neither. A hook that passes locally under `pyrefly check <dir>` but fails under `prek run pyrefly-check --all-files` is almost always one of these two.

Keep the hook `rev` aligned with the installed CLI and the Positron extension, all three on the same pyrefly version, for the same reason the CLI and the extension are collapsed onto one binary.

The `ruff-pre-commit` rev takes the same alignment against the installed `ruff`, for a different reason: a stale pin runs a different rule set than the local gate, so the commit hook and `ruff check` disagree about the same file. That surfaces as diff churn rather than pyrefly's silent no-op.

Do not copy the scaffold's `rev` values into a project config: they drift, and the scaffold is the source of truth.

The dotfiles repo's own root `prek.toml` carries no Python hooks, and should not: the repo holds no `.py` file. Same precedent as its missing R, typstyle and StyLua hooks.

## References

- ruff: https://docs.astral.sh/ruff
- ruff pre-commit: https://github.com/astral-sh/ruff-pre-commit
- uv: https://docs.astral.sh/uv
- pyrefly: https://pyrefly.org/
- pyrefly pre-commit: https://github.com/facebook/pyrefly-pre-commit
- PEP 723: https://peps.python.org/pep-0723/
