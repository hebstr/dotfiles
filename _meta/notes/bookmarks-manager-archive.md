# bookmarks-manager specification (archived 2026-10-13)

The whole specification a rebuild of the `bookmarks-manager` skill would start from, moved here on 2026-10-13 out of the `.claude/DEFERRED.md` row opened 2026-09-20, which carried it where that file admits actionable backlog only: the row had no trigger and no due date, and a specification is not a deferred finding.
It sits in this repository rather than in `~/dotfiles/.claude/`, whose history has no remote and no backup, so a lost disk would take the only copy with it.
Superseded as a task, live as a record: nothing schedules this rebuild.

## Why no code survives

Vendored into the dotfiles on 2026-09-20 and dropped the same day. It is a packaged Python project carrying its own layout and conventions, and it failed the repository gate on 22 ruff findings (PTH123, PTH118, E501, RUF059) and 9 pyrefly import errors, the latter caused by `pythonpath = ["scripts"]` sitting in a `[tool.pytest]` table that neither pytest nor pyrefly reads.
A rebuild targets the repository's conventions from the start instead of being retrofitted into them.

The dead ends were verified on 2026-10-12 rather than assumed, and they are named so nobody re-hunts them: the dotfiles history holds only a submodule gitlink at `claude/.claude/skills/bookmarks-manager` (mode 160000, `d12a921`, added and deleted 2026-04-15) whose object no repository on disk carries, there is no `.git/modules/` and no `.gitmodules`, no clone exists under `$HOME`, `gh api repos/hebstr/bookmarks-manager` answers 404 (the remote having been deleted 2026-09-20), and the skill's transcript directory holds only an empty `memory/`.

## Concept

Clean a browser bookmarks export (Netscape HTML, identical across Firefox, Chrome, Safari and Edge) through a bundled Python script for every deterministic step, the LLM being used for theme classification alone.

Four stages:

1. Parse, URL-normalize, deduplicate and link-check into `parsed.json`, `dedup_report.json` and `linkcheck.json`.
2. LLM theme classification, reusing a `themes.json` when a previous run left one.
3. Regenerate a reimportable `bookmarks.html`.
4. Summary report.

The frontmatter carried `context: fork`, and the output went to a `bookmarks_output/` beside the input so the original is never overwritten.

## Tracking worth rebuilding

- 42 pytest cases over 5 modules (parse, normalize, dedup, check_url, generate_html).
- An `evals/evals.json` suite over three HTML fixtures (duplicates, deadlinks, mixed) whose prompts are French and assert exact surviving-bookmark counts.
- A `package.sh` zipping a `.skill` archive.
