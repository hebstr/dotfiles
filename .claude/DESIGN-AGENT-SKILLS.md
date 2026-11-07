# DESIGN-AGENT-SKILLS.md

Design note for where agent skills live, both the third-party ones installed from GitHub and the ones the user writes, first applied to the prek skill, decided 2026-09-18.

## Third-party skills go through the `agents` package and its lock

Decision, implemented 2026-09-18 with the `skills` CLI 1.7.0: the official prek skill (`skills/prek/SKILL.md` in `j178/prek`) is installed at user scope with the same CLI that wrote `agents/.agents/.skill-lock.json`, so it lands in `agents/.agents/skills/prek/` and gets a lock entry whose `skillFolderHash` tracks upstream's tree sha.
The lock holds its own fields, `agent-skills-update` holds the install form in its repair line, and `_meta/notes/dotfiles-bootstrap.md` § "Agent skills" holds the two-package split, the plain-`stow claude` rule a skill's symlinked directory requires and the `agents` folding carve-out.
What none of them holds: `~/.claude/skills/<name>` is a per-machine relative symlink to `../../.agents/skills/<name>`, created by the installer and never tracked in git, and it reaches the WSL machine through Syncthing, whose `syncthing/.claude/.stignore` does not exclude `skills/`, resolving there because `stow agents` provides `~/.agents` (checked on WSL for prek by the user, 2026-09-18).

The convention took its second instance on 2026-10-17, `lucifer1004/claude-skill-typst`, and that one priced a cost prek was too small to expose: a vendored skill can ship data.
Its 9.4 MB of JSON API indexes put nine files over the 500 KB of `check-added-large-files`, the one hook of `prek.toml` that had no `^agents/` exclusion, so the exclusion was added and the guard now sees nothing any installer vendors.
Verdict, measurements and revert path in `~/dotfiles/_meta/notes/typst-skill-reco.md`.

## A single target agent makes the CLI copy instead of symlink

`-a claude-code` alone installs a plain copy into `~/.claude/skills/prek` and nothing under `~/.agents/skills/`, while still writing the lock entry, so the skill silently misses the dotfiles.
The CLI forces copy mode whenever the targets resolve to one directory (`uniqueDirs.size <= 1` in `dist/cli.mjs` of 1.7.0) and `--copy` has no symlink counterpart.
Adding `cline`, whose skills directory is the canonical `~/.agents/skills` itself, makes two directories, so the CLI keeps symlink mode and writes no extra file for Cline.

## Why this skill is worth a slot

prek's config surface (`repo = "builtin"` and `"meta"`, `priority` and `priorities`, `prek util yaml-to-toml`, `prek util identify`) is recent and thin in training data, which is the argument of upstream issue #1920 that produced the skill.

One of its conventions is not adopted: its examples use TOML 1.1 multiline inline tables, while the three `prek.toml` files here that carry hooks keep one per line.

## `gh skill install`, the README's method, was rejected

`gh skill install j178/prek prek` is the only install method prek documents (README, "prek skill for agents").
At its default user scope it writes into `~/.claude/skills/`, a plain directory outside stow, so the skill would be synced by Syncthing but never tracked in git.
With `--dir ~/dotfiles/agents/.agents/skills` it reaches the dotfiles, but puts a second installer in the directory: `gh skill` injects its own metadata into the `SKILL.md` frontmatter and the lock would not know the skill; `gh skill update` scans a fixed list of host directories (whether it reads a custom `--dir` is unverified) and prompts for the source of every skill lacking its metadata.

Doing nothing (reading `prek --help` and `https://prek.j178.dev/llms.txt` on demand) was rejected because it depends on remembering to look, which is the failure the skill exists to prevent.
Vendoring a copy into `claude/.claude/skills/` was rejected: that directory holds the user's own skills, and a copy has no update path.

## Updates run through a dedicated `agent-skills-update` script and module

Decision, implemented 2026-09-18: `bin/.local/bin/agent-skills-update`, wired into `sys-update` as the `agent-skills` module (no sudo), on the model of `claude-plugins-update` and its `update_claude_plugins` wrapper.
Its steps and its exit codes are established by the script and by `_meta/tests/agent-skills-update.bats`, the module's wiring by `_meta/tests/sys-update.bats`, both guards included: it skips when the directory `~/.agents` resolves into is outside a git working tree, and it exits non-zero when a lock entry is not current upstream.
What neither states: the currency check joins the lock fields on the unit separator `\x1f` rather than with `@tsv`, because `read` collapses consecutive tabs as whitespace and an empty hash would otherwise take the `ref` value and be reported stale.

Why `update -g` is safe to drive: in `skills` 1.7.0 it compares each lock entry's `skillFolderHash` with GitHub and reinstalls a changed skill through `add <source> --skill <name> -g -y`, whose targets are the detected agents plus every agent reading `~/.agents/skills` (`ensureUniversalAgents`).
That is always at least two directories, so the copy trap above does not apply to updates.

The CLI version is not pinned: `npx -y skills` runs the latest release, the same move-to-latest behavior `css-toolchain-update` has; the post-update check is what catches a release that changes the layout.

Rejected:

- An extra step inside `claude-plugins-update` (the user's initial suggestion): that script runs on both machines while skills must update on the main one only, it drives another CLI (`claude`, not npm's `skills`, which serves Copilot too), and a skills failure would share the plugins row of the status table.
- An inline one-liner module in `sys-update`, as for `npm`: `rules/install.md` keeps that form for tools with no bespoke shape, and here the git guard and the post-check are one; inline, only the dispatch would be testable.
- Running `npx -y skills update -g` by hand: nothing prompts it and nothing keeps it off the WSL machine.

## The CLI can skip a skill and still report success

The currency check exists because the first real run, 2026-09-18, reported `OK` while updating nothing.
`tw93/Waza` had just duplicated every skill under both `skills/<name>/` and `plugins/waza/skills/<name>/` (identical for some, divergent for `health`, `read` and `write`) and renamed `design` to `ui` ("so it stops shadowing Claude Code's /design").
`skills update -g` skipped the six ambiguous skills ("Multiple current paths match"), left `design` in place ("Skipping deletion in non-interactive mode"), then printed "All global skills are up to date" and exited 0.
Comparing the lock hash against the upstream tree SHA is what makes the check exact without parsing the CLI's wording.

## The Waza skills were removed, not migrated

Decided 2026-09-18: the seven Waza skills went with their lock entries and their `~/.claude/skills/` links, and the lock held prek alone from that date until `typst` joined it on 2026-10-17.
No replacement was installed.
Two migrations were weighed and dropped by the user: the full `waza@waza` Claude Code plugin (it also brings `write`, which would auto-trigger on prose work that `CLAUDE.md` routes to `/workflow:write`, and `ui`, overlapping `frontend-design`), and one `waza-<name>@waza` plugin per skill.
Side effects accepted: GitHub Copilot lost the same skills (it read them from `~/.agents/skills`), and `/read` no longer takes URLs ahead of WebFetch.

## `~/.agents/skills` is not a second home for the skills the user writes

Decided 2026-09-20, after the proposal to consolidate every personal skill into `~/.agents/skills` for harness portability.
The split stands: `agents/.agents/skills/` holds what an installer vendors and the lock tracks, `claude/.claude/skills/` holds what the user writes.

Claude Code does not read `.agents/skills`, settled in the installed 2.1.278 bundle: runtime discovery resolves the six sources its documentation lists (https://code.claude.com/docs/en/skills, "Choose where skills load"), and every occurrence of the string `.agents/skills` sits instead in an importer that reads `~/.agents/skills` and `~/.cursor/skills` to copy into `~/.claude/skills`, a one-way migration bridge rather than a read path.
No setting and no environment variable adds a skills directory, and `--add-dir` is session-scoped and still expects the `.claude/skills/` shape.

The portability the proposal sought is real but points elsewhere: Codex reads `$HOME/.agents/skills` as its primary user path, Gemini CLI treats `~/.agents/skills` as an alias taking precedence over `~/.gemini/skills`, and Cursor and GitHub Copilot read it too.
None of those harnesses is installed on this machine, so `~/.agents/skills` has exactly one reader here, Claude Code, through the per-skill symlinks.

What condemns the move regardless of who reads what: `skills update -g` reinstalls a changed skill by replacing its directory wholesale rather than merging, so a hand-written skill sitting in the installer's canonical directory is one name collision away from being overwritten with no prompt (`vercel-labs/skills` issues #455 and #1906, both open 2026-09-20).
The separation is what lets `agent-skills-update` treat everything under `~/.agents/skills` as replaceable without loss.
The mirror move, folding everything into `claude/.claude/skills/`, was already measured and rejected in "A single target agent makes the CLI copy instead of symlink" above.

This holds as long as Claude Code ignores `.agents/skills`.
If https://github.com/anthropics/claude-code/issues/16345 ships, `claude/.claude/skills/` becomes the redundant half and the split is worth reopening, but not in the direction proposed here: the overwrite argument survives that change untouched.

## Where a skill the user writes goes is decided by its coupling to this machine

Decided 2026-10-08, while designing `poc` (`DESIGN-POC.md`), the two candidate homes being `claude/.claude/skills/` and the `hebstr/claude-code-plugins` marketplace.
The criterion was never written down although both precedents existed, so a session without it argued the placement from scratch.

The criterion: a skill whose load-bearing steps read this machine's stack, harness or corpus stays in `claude/.claude/skills/`; the marketplace takes only what someone else can install and run.

The split is already clean enough to be read off the tree, by one `rg` for markers of this machine (`dotfiles`, `/home/julien`, `Zotero`, `ju-TP`, `_meta/notes`): one file carries them across the published `audit/` and `workflow/` plugins of `~/Documents/packages/claude-code-plugins`, against several under `claude/.claude/skills/`, where `zotero/SKILL.md` hardcodes `~/Zotero` and `design/SKILL.md` names `_meta/notes/`.
The marketplace skills that do need environment facts discover them at runtime instead, which is what the reviewer scan of `audit/walkthrough/scripts/scan-reviewers.py` does for `walkthrough` and `blindspot`: the available reviewers are read off the installed plugins, with no hardcoded list.

What the criterion costs on the user-level side, accepted: nothing lints those skills, nothing tests them, and they exist on one machine.
What it buys is a skill naming the hook surface of `~/.claude/settings.json` directly rather than discovering it, which is the difference between a pass worth starting and one that is not.

The criterion took its second application on 2026-10-17 with `typst-review`, where it overturned the placement the brief had argued for: `DESIGN-TYPST-REVIEW.md` holds that decision, and the premise it refutes, that `scan-reviewers.py` discovers reviewers off the installed plugins alone, when it scans `~/.claude/skills/` first.
The third application, on 2026-10-23 with `review-prose`, took it the other way round: the route is distributable, pandoc plus `rg`, and what keeps the skill user-level is that it cites `rules/docx.md`, defers to `review-comments` and closes by writing into this user's tracking files (`DESIGN-REVIEW-PROSE.md`).

This rules on user level against marketplace only.
Whether a project-level `.claude/skills/` ever holds one of these is open.

## The four skills outside stow are resolved

The `DEFERRED.md` entry of 2026-06-01 listed `bookmarks-manager`, `history-analyze`, `model-extract` and `ref` as living in `~/.claude/skills` outside git.
Settled 2026-09-20:

- `ref` was vendored into `claude/.claude/skills/ref/` and its nested `.git` removed.
  Its remote `github.com/hebstr/ref-skill` was deleted 2026-09-20, so the dotfiles hold the only copy and its one-commit history is gone.
- `bookmarks-manager` was vendored the same day, then deprecated and deleted.
  Its concept, its tracking to rebuild and the dead ends of the search for its code are in `_meta/notes/bookmarks-manager-archive.md`, where they moved on 2026-10-13 out of a `DEFERRED.md` row that had no trigger.
- `history-analyze` and `model-extract` were deleted.
  This reverses the 2026-06-01 reading that they "belong in the hebstr plugin": no migration was performed and none is planned.

`developing-with-streamlit` keeps two byte-identical copies, one tracked under `agents/.agents/skills/` and one untracked in `~/.claude/skills/`, and that is deliberate.
`uv run streamlit skills --global --yes` writes both locations in a single pass, which `_meta/notes/streamlit-agent-skills.md` records, so replacing the second with a symlink would diverge from the installer and be undone on its next run.
Deduplicating it was proposed and dropped on 2026-09-20; the copy costs 24 KB and Claude Code loads only the `~/.claude/skills/` one.

Vendoring these was consistent with the rejection of vendoring recorded for prek above, not a contradiction of it: that rejection turns on a third party's upstream moving underneath a copy, and here the upstream was the user.

What vendoring costs, before the next one: a skill developed under its own conventions enters the repository's commit gate on arrival, `prek.toml` exempting the `agents` package from most hooks and `claude/.claude/skills/` from `panache-format` alone, so `ref` arrived with a `prose-lint` backlog that had to be cleared file by file through `/workflow:write`.
Two constraints shaped that pass and will shape the next one.
The `prose-lint-pretool` hook rejects any write leaving the file with a violation, so a file carrying several is rewritten whole in one call rather than corrected line by line.
And a dash inside a verbatim quotation cannot be edited away without falsifying the quote: the one case, Heiss on generated chunks in `quarto/heiss-snippets.md`, was converted to indirect speech instead.

## Open points

- The post-update check detects a layout change after the files are rewritten; recovery then goes through git.
