---
name: Claude Code marketplace install mechanics
description: When `claude plugin install` is required vs skippable, when cache is populated, and how `extraKnownMarketplaces` relates to `marketplace add`. Verified 2026-04-26 against the actual hebstr/claude-code-litrev cache state.
metadata:
  type: reference
  originSessionId: e3cb33c3-05ad-4318-aa10-31d456904d95
---
Three non-obvious mechanics about the marketplace + plugin lifecycle, verified by inspection of `~/.claude/plugins/cache/` against `~/.claude/settings.json` (2026-04-26).

**1. `extraKnownMarketplaces` (settings.json) ≡ `claude plugin marketplace add`**
- Declaring a marketplace under `extraKnownMarketplaces` registers it at Claude Code startup, equivalent to having run the CLI `add` command. No separate `claude plugin marketplace add <name>` needed.
- This is what `r-skills`, `ouroboros`, `waza`, `hebstr`, `litrev` all rely on.

**2. Cache is populated by `plugin install`, regardless of source type**
- Running `claude plugin install <plugin>@<marketplace>` copies the plugin content into `~/.claude/plugins/cache/<marketplace>/<plugin>/<version-or-sha>/` — a full snapshot of the marketplace tree at that revision.
- This happens even for `source: directory` marketplaces. Empirical evidence (2026-04-26): `hebstr` is in `directory` source mode, but `~/.claude/plugins/cache/hebstr/{review,workflow}/` contains both `0.1.0/` and a sha-named subdir, each with a full marketplace snapshot.
- Once cache exists, **the cache becomes the source of truth at runtime** — edits to the live source dir are NOT picked up until `claude plugin update <plugin>@<marketplace>` refreshes the cache. Verified: a fresh edit to `review/skill-adversary/doc/context.md` was absent from the cache copy.

**3. `plugin install` is skippable for `directory` source — but with a behavioral consequence**
- For `directory` source: if no install has been run (no cache entry), Claude Code falls back to reading live from the path declared in `marketplace.json`. Restart alone is enough to load the plugin. Empirical evidence: `litrev` post-rollback has no cache entry but is fully discoverable.
- For `github`/`git` source: install is required. Without cache, there's no on-disk content to load.
- **Trap**: the litrev memory `project_litrev_separate_from_hebstr.md` and the operational behavior of "directory source = lecture live" only holds when no install has been run. As soon as someone runs `plugin install <plugin>@<directory-marketplace>`, the cache is populated and live edits become invisible until `plugin update` is run. Treat directory source as "live until first install, then cached like github."

**Operational decision tree for `directory`-source marketplaces:**
- Want live edits to take effect on restart with no extra commands? Don't run `plugin install`. Just declare the marketplace + enabled plugin and restart.
- Want versioned snapshots and predictable rollback? Run `plugin install` to populate cache, then use `marketplace update` + `plugin update` to refresh after each source change (same workflow as github source).

**Verification**: to know which mode a `directory`-source plugin is currently in, check whether `~/.claude/plugins/cache/<marketplace>/<plugin>/` contains versioned subdirs. Empty / missing → live mode. Has subdirs → cached mode.
