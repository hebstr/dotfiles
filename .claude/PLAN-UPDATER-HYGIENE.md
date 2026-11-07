# PLAN-UPDATER-HYGIENE.md

Design note and implementation plan for three hygiene gaps in the updater and cleanup scripts, surfaced by the 2026-08-19 audit that followed the pnpm removal, which left no trace note of its own.

pnpm was removed because its `sys-update` module reported `OK` on every run while the active binary never changed and 27 downloaded versions piled up in `~/.local/share/pnpm/.tools`.
The audit then asked the other 20 modules the same question, **does any of them report a green status without doing the work**, and none reproduces the pnpm bug itself: every updater writes to the binary the PATH resolves.

**Adversarial review, still owed.**
Not established for `quarto-update`: no invocation inside the 7-day transcript retention, which proves nothing either way.
Nor the code now in `rig-update` and `gh-update`: the walkthrough of 2026-09-18 read a `rig-update` that the release-`.deb` decision replaced the same day, and `gh-update` was written after it.
Covered: `sys-cleanup` with `_meta/tests/sys-cleanup.bats` on 2026-09-25, `sys-update` and `syncthing-update` on 2026-09-18 (`/audit:walkthrough`, reviewer `posit-dev:critical-code-reviewer`).
`duckdb-update` on 2026-10-23, same reviewer, on the download path that `f14f001` (2026-10-22) introduced: no Blocking and no Required finding, two fixes taken in `8d04920`, the install `mv` now restoring the backup it displaced and the cleanup trap keeping the run's own exit status, each pinned by a `@test` of `_meta/tests/duckdb-update.bats`.
`bash/.profile`, step 5 below, was covered on 2026-09-26 by `/audit:walkthrough bash/.profile`, whose fixes are `88968bb`: the `case ":$PATH:"` guard the step adds landed in `698a42f` on 2026-08-19, so the pass read it, and nothing but a same-day header alignment has touched the file since.

## Design decision: prune at creation, not a new `sys-cleanup` module

Pruning at creation is `lua-toolchain-update`'s shape, which `quarto-update` and `duckdb-update` adopt: every sibling backup is deleted after a successful swap, so the invariant "at most one backup" holds continuously.

A `sys-cleanup` module was the other candidate and is rejected:

- it would duplicate three naming conventions (`/opt/quarto.bak-*`, `~/.local/bin/duckdb.bak-*`, `~/.local/share/lua-language-server.bak-*`) in a script that does not own any of them, so a rename in an updater would silently orphan its backups
- the invariant would only hold until the next cleanup run, whereas pruning at creation holds always
- `/opt/quarto.bak-*` is root-owned and would drag `sudo` into a module that has none, while `quarto-update` already holds a sudo keepalive for its own swap
- `lua-toolchain-update` set the precedent and there is no reason for the three to diverge

The one thing a `sys-cleanup` module would buy, reclaiming the backups that already exist, is a one-shot removal, not a recurring mechanism.
It is handled by hand under step 4 rather than by building a permanent module for a transient need.

Retention stays at one backup, matching `lua-toolchain-update`: it exists for a rollback to the version just replaced, and older ones answer no question the release archives cannot.

## Scope

Out of scope:

- the `sys-update` module `npm`, kept deliberately: it is idle rather than broken, costs no disk, and becomes useful the day a global package is installed.
  That is the "already covered, close it" outcome, recorded so the question is not reopened.
  The hypothesis that explained its green status on `ju-TP` held: the user prefix was already set there with nothing installed under it, where `ju-TP2` still had the `/usr` prefix and was fixed on 2026-09-19.
  No guard was added to the module for a machine missing that step, an `EACCES` there being already loud.
  The prefix itself, and why `~/.npmrc` is never stowed, are in `rules/install.md` and in the bootstrap of `_meta/notes/dotfiles-bootstrap.md`.
- caches (`~/.cache/uv`, `~/.cache/prek`, `~/.cache/rv`).
  `sys-cleanup` already owns them through `uv cache prune`, `prek cache gc` and its rv link-count sweep.
  Nothing to build.
  Reversed on 2026-09-13 for uv: `uv cache prune` removes dangling entries only, and 11.1 GiB of `archive-v0` was linked by no venv. Decision and plan in `PLAN-ORPHANS.md`.
- the `/snap/bin` duplicate in PATH, which comes from `/etc/profile.d`, outside the dotfiles.

## Steps

All six are done. The numbering is frozen rather than renumbered: step 4 is cited where the design decision rejects a module for a transient need. `PLAN-SESSION-DISCIPLINE.md` stopped citing step 5 by ordinal at its prune pass of 2026-10-15, and now names this file for the adversarial-review status its leftovers bullet still owes.

1. `claude-versions`: widen both `find` calls and correct the skip message.
   Claude Code stores each version as an executable file rather than the directory the `-type d` enumeration assumed, and whether that layout is stable is deliberately left unanswered.
2. `quarto-update`: prune the sibling backups after the successful swap, under its sudo keepalive.
3. `duckdb-update`: the same prune, on files rather than on trees.
4. Reclaim what had already accumulated, by hand, the `/opt` half needing the user's sudo.
5. `bash/.profile`: the `case ":$PATH:" in` guard of `bash/.bashrc`, applied to the `.local/bin` and `.npm-global/bin` prepends.
6. apt Rust toolchain: report `apt-cache rdepends` for `rustc` and `cargo`, hand the removal command to the user.

## An apt index that fails to refresh reports FAIL, and the upgrade still runs (decided 2026-09-18)

**`apt-get update` exits 0 on `NO_PUBKEY`, emitting only `W:` lines.**
Nothing else in the repository holds that, and it is the whole basis of what follows: the 2026-09-18 `sys-update` run printed `apt OK` while two repositories had stopped refreshing for up to 18 days, their keys rotated upstream, because the `&&` chain in `update_apt` never saw a failure.

Decision for `sys-update`: `--error-on=any` with its exit status kept aside, `full-upgrade` run regardless, and the module recording `FAIL (index refresh)`.
Rejected: `--error-on=any` inside the `&&` chain. One broken third-party repository, or a transient outage on any of about twenty, would then have held back every Ubuntu security update, for the full 13 days in the GitHub CLI case.

A per-updater refresh is scoped to the updater's own repository, reversing the same-day first version that ran `--error-on=any` over every source: that one aborted the install whenever any other repository failed, and reported one outage as two or three module FAILs.
The scoped form passes `--no-list-cleanup`, which is load-bearing: list cleanup is on by default (`man apt-get`, `--list-cleanup`).

`syncthing-update` is the only updater still on that shape, and the precedent for any future third-party apt repository: its key is fetched and compared with `cmp` on every run, installed through `sudo` only when it differs, and its refresh is the scoped one above.
Rejected there: the unscoped form; and checking afterwards that the install candidate comes from `apt.syncthing.net`, which parses `apt-cache policy` output and has no expected version to compare against.

`sys-update` carries `trap 'exit 130' INT` because a module child that traps SIGINT and exits 130 hid the Ctrl-C from bash, which recorded a FAIL and ran the remaining modules.

### rig and gh install the release `.deb` instead (decided 2026-09-18)

This supersedes a first `rig-update` design of the same day, which compared the apt key on every run and refreshed its own repository before upgrading.
What removed that repository's reason to exist: it is published by a manual upstream `workflow_dispatch`, 2 and 8 min behind the last two releases.
Neither `r-rig` nor `gh` carries a maintainer script, so installing the release `.deb` never brings the apt source back.

Rejected: detecting expiry through `gpg --show-keys --with-colons`, which parses gpg output and misses a rotation made before expiry (GitHub CLI created its new key 2026-04-07, five months ahead); refreshing the key on the upgrade path only, which leaves it stale until the next release, the exact state of 2026-09-18 with rig current at 0.8.1.

**Open.** The scoped refresh relies on `Dir::Etc::SourceParts=-` disabling `sources.list.d` and on `--no-list-cleanup` being honoured, both checked on apt 2.8.3; if a later apt breaks either, the other indexes are lost until the next `sys-update` apt run rebuilds them.
