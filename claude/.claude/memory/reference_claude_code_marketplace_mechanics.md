---
name: Claude Code marketplace install mechanics
description: When `claude plugin install` is required vs skippable, when cache is populated, how `extraKnownMarketplaces` relates to `marketplace add`, and why a moved `directory` source breaks `marketplace update`. Verified 2026-08-21 against the on-disk cache and settings state.
metadata:
  type: reference
  originSessionId: e3cb33c3-05ad-4318-aa10-31d456904d95
---
Four non-obvious mechanics about the marketplace + plugin lifecycle, verified by inspection of `~/.claude/plugins/cache/` against `~/.claude/settings.json` (2026-08-21).

**1. `extraKnownMarketplaces` (settings.json) ≡ `claude plugin marketplace add`**
- Declaring a marketplace under `extraKnownMarketplaces` registers it at Claude Code startup, equivalent to having run the CLI `add` command. No separate `claude plugin marketplace add <name>` needed.
- This is what `ouroboros`, `r-skills`, `posit-dev-skills`, `claude-plugins-official`, `hebstr`, `litrev`, `astral-sh` all rely on.

**2. Cache is populated by `plugin install`, regardless of source type**
- Running `claude plugin install <plugin>@<marketplace>` copies the plugin content into `~/.claude/plugins/cache/<marketplace>/<plugin>/<version-or-sha>/`: a full snapshot of the marketplace tree at that revision.
- This happens even for `source: directory` marketplaces. Empirical evidence (2026-08-21): `litrev` is the only `directory` source declared, and `~/.claude/plugins/cache/litrev/litrev/0.1.0/` holds a full marketplace snapshot. `github` sources cache under a commit-sha subdir instead (`~/.claude/plugins/cache/hebstr/{audit,workflow}/e1c9a0bd5281/`).
- Once cache exists, **the cache becomes the source of truth at runtime**: edits to the live source dir are NOT picked up until `claude plugin update <plugin>@<marketplace>` refreshes the cache. Verified by editing a skill file in the source tree and finding the cache copy unchanged.

**3. `plugin install` is skippable for `directory` source, with a behavioral consequence**
- For `directory` source: if no install has been run (no cache entry), Claude Code falls back to reading live from the path declared in `marketplace.json`. Restart alone is enough to load the plugin. Which mode a given plugin sits in is decided per-plugin by the cache check below, never assumed.
- For `github`/`git` source: install is required. Without cache, there's no on-disk content to load.
- **Trap**: the litrev memory `project_litrev_separate_from_hebstr.md` and the operational behavior of "directory source = lecture live" only holds when no install has been run. As soon as someone runs `plugin install <plugin>@<directory-marketplace>`, the cache is populated and live edits become invisible until `plugin update` is run. Treat directory source as "live until first install, then cached like github."

**Operational decision tree for `directory`-source marketplaces:**
- Want live edits to take effect on restart with no extra commands? Don't run `plugin install`. Just declare the marketplace + enabled plugin and restart.
- Want versioned snapshots and predictable rollback? Run `plugin install` to populate cache, then use `marketplace update` + `plugin update` to refresh after each source change (same workflow as github source).

**Verification**: to know which mode a `directory`-source plugin is currently in, check whether `~/.claude/plugins/cache/<marketplace>/<plugin>/` contains versioned subdirs. Empty / missing → live mode. Has subdirs → cached mode.

**4. A `directory` source records its path twice, and a moved source dir fails the refresh**
- The path lives in `extraKnownMarketplaces` (`~/.claude/settings.json`, stow-managed) AND in `~/.claude/plugins/known_marketplaces.json` (`source.path` plus `installLocation`, CLI-managed, not stow-managed). Both must be corrected when the source repo moves.
- A path pointing at a missing directory makes `claude plugin marketplace update` exit 1 with `1 marketplace could not be refreshed (see --debug): <name>`, while every other marketplace still refreshes. The `--debug` it points at is not accepted on the subcommand (`unknown option '--debug'`), and `claude --debug plugin ...` starts an interactive session instead of running the command, so diagnose by reading the declared path and checking it exists. Under `set -e` that single failure is enough to abort a wrapper script (see `claude-plugins-update` in `~/dotfiles/bin/.local/bin/`, which tolerates it and defers the non-zero exit to the end).
