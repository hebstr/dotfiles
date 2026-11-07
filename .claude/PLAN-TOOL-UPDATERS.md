# PLAN-TOOL-UPDATERS.md

Design note and implementation plan for `lua-toolchain-update` (StyLua + lua-language-server), wired into `sys-update` as a module, follow-on to `PLAN-LUA.md` (the Lua gate itself, complete).
A second script, `pandoc-update`, was written here and deleted on 2026-09-29 with the apt pandoc it kept current: **everything this plan says about it is record, not current state**, and the motive and the measurements are in the closing section of `_meta/notes/pandoc-upgrade.md`.
A third, `zotero-update`, was added 2026-09-23 under its own section "Design: `zotero-update`": implemented, and the snap-to-deb migration done the same day.

**Only the adversarial reviews remain (step 7), user-run in a fresh conversation.**
The step numbering is load-bearing: one live passage of `PLAN-SESSION-DISCIPLINE.md` cites "step 7" by ordinal, down from two at its prune pass of 2026-10-15, and the cloudflared row of `DEFERRED.md` cites step 8 for the fixture miss below, so the executed steps keep their positions.

A post-change grep recorded as "N/A vacuously" for test fixtures was wrong: `_meta/tests/sys-update.bats` hardcodes two module-enumeration lists and a sudo-flag test, so adding a `sys-update` module always touches that suite.

Design learning (step 1): a per-function `trap '... $tmp' RETURN` is wrong here.
RETURN traps are global without `functrace`, so the trap re-fires when `main` returns, where `$tmp` is unset, aborting under `set -u`.
Fixed with a single script-level `TMPDIRS=()` array cleaned by one `trap cleanup EXIT`.

## Why not `devtools-update`

`devtools-update` is not a catch-all updater: it aggregates one distribution shape, a piped cargo-dist `installer.sh` with an env-var prefix, system `/usr/local/bin`, one binary named exactly as the tool, version-checked against GitHub `releases/latest`, and its eligibility test is mechanical (`reference_tool_update_routines`).

None of the three new tools fit that contract:

```
| Tool                | Distribution                              | Target scope                             | Existing analogue                            |
| ---                 | ---                                       | ---                                      | ---                                          |
| stylua              | `.zip` holding a single binary            | `~/.local/bin` (user)                    | `duckdb-update` (single binary, user-local)  |
| lua-language-server | `.tar.gz` runtime tree + launcher symlink | `~/.local/share` + `~/.local/bin` (user) | `quarto-update` (tarball tree, staged swap)  |
| pandoc              | `.deb` via `dpkg`                         | system (dpkg-managed)                    | `quarto-update` (dedicated big-tool updater) |
```

Extending `devtools-update` to absorb them means adding a per-entry install-method dispatch (zip / tarball-tree + symlink / deb) and mixing three install scopes (user `~/.local`, system `/usr/local`, dpkg) into a script that today has exactly one clean shape and one `--prefix` model.
The repo already rejected this: duckdb and quarto are GitHub-release tools with version checks, yet each got its own `<tool>-update` script rather than being folded into `devtools-update`.
The precedent is one script per distribution shape, not one script per source host.

## The shared skeleton (from `duckdb-update` / `quarto-update`)

Every non-cargo-dist updater in `bin/.local/bin/` follows the same shape, and the scripts of this plan inherited it:

1. Preflight: `command -v` on the required tools, fail early if missing; `jq` belongs to that list only where the binary is actually invoked, `gh api --jq` using gh's embedded engine.
2. Resolve latest version via `gh api repos/<owner>/<repo>/releases/latest --jq '.tag_name'`, normalize (strip leading `v` where the tag carries one).
3. Read installed version from the binary's `--version`, extract with a version regex, compare; exit early "already on X" if equal.
4. Download to a `mktemp -d`, verify, execute the staged artifact once to confirm it runs before touching the live path.
   Verification reads a published checksum file where the project ships one (`gh-update`), else the `assets[].digest` GitHub itself computes, which `duckdb-update` uses since DuckDB publishes no checksums of its own (verified 2026-10-22 on `v2.0.0`).
   The digest travels over the same TLS channel as the artifact, so it catches a truncated or corrupted download rather than a compromised release.
   `rig-update` and `lua-toolchain-update` are the two that verify nothing: measured 2026-10-23, `r-lib/rig`, `JohnnyMorganz/StyLua` and `LuaLS/lua-language-server` each expose a sha256 `assets[].digest` and none publishes a checksum file, so the check those two skip is available rather than absent.
   Their comments now say that instead of citing `duckdb-update` as the same shape, which it stopped being at `f14f001`; taking the check is open and unscheduled.
5. Atomic-ish swap: back up the current install, move the new one into place, roll back on failure (`trap ... EXIT`).
6. Report installed version and the backup path.

## Design: `lua-toolchain-update`

One script, two tools (approved granularity: they back a single gate in `rules/lua.md` and version as one capability), as two internal update functions sharing the skeleton, run in sequence, each independently version-checked and skippable.
`lua-toolchain-update` always tracks latest, like duckdb/quarto: the versions pinned in `_meta/notes/lua-toolchain.md` were for reproducing that one trace, not a policy.
Tag forms, the per-arch asset names and the install targets are in `update_stylua`, `update_luals` and `detect_arch`, with a case per behaviour in `_meta/tests/lua-toolchain-update.bats`; the LuaLS tree swap mirrors `quarto-update`'s, scoped to `~/.local` with no sudo.
The one upstream oddity is in `_meta/notes/lua-toolchain.md`: LuaLS self-reports `3.18.2-dev` for the `3.18.2` release tag, which `installed_semver` has to tolerate.

## Steps

Steps 1 to 6 and 8 were done on 2026-07-20; what they did is in git, and only the decisions that still bind are kept here.

1. ✅ `lua-toolchain-update` written and stowed, keeping exactly one `lua-language-server.bak-*` tree, which `PLAN-ORPHANS.md` records as retained by design.
2. ✅ `pandoc-update` written and stowed, then deleted 2026-09-29 (see the head of this note).
3. ✅ Both wired into `sys-update` as modules.
4. ✅ Post-change greps run; the one they got wrong is recorded at the head of this note.
5. ✅ The updater section of `environment.md`, since deleted with that file: it pointed at `sys-update --list` as the authority rather than enumerating modules that would drift, which `_meta/notes/environment-archive.md` carries unchanged.
6. ✅ Neighbor em-dash cleanup on 13 `bin/` scripts, its `shellharden --replace` half deliberately withheld then reversed by the user on 2026-09-12; `project_shellharden_dotfiles_normalized` holds the standing consequence.
7. Pending (user runs, fresh conversations, per build discipline; tests exist first per step 8, so the walkthrough reviews tested code):
   - shell adversarial review of the remaining script: `/audit:walkthrough bin/.local/bin/lua-toolchain-update --reviewer posit-dev:critical-code-reviewer`.
     Narrowed on 2026-09-30: the command named `bin/.local/bin/pandoc-update` too, and that file is deleted, so it would have failed as written.
   - rules-file adversarial pass on the heir of the `environment.md` change: `/audit:blindspot claude/.claude/rules/install.md`.
     Retargeted by the user on 2026-10-14: `rules/environment.md` was deleted in `daa2729` (2026-09-26) and `rules/install.md` carries the entry-point rule that step 5 wrote there.
8. ✅ `_meta/tests/lua-toolchain-update.bats` written and `sys-update.bats` extended for the new modules. Install wrappers are exempt from the propose-tests trigger, so this coverage was the user's election.
9. Open, unscheduled: verify the `assets[].digest` in `rig-update` and `lua-toolchain-update`, on `duckdb-update`'s shape, which step 4 of the skeleton above measures as available rather than absent. Done when `rg -F 'sha256sum -c'` matches in both scripts. Step 7's pending review of `lua-toolchain-update` reads the same script, so taking the two in one pass costs one reading of it instead of two.

## Design: `zotero-update` moves Zotero off the snap onto zotero-deb (decided 2026-09-23)

Decision: a `zotero-update` module modelled on `syncthing-update`, configuring the zotero-deb apt repository and joining `ALL_MODULES` and `SUDO_MODULES` in `sys-update`, on the stable channel rather than beta.
What the script and `_meta/tests/zotero-update.bats` cannot state themselves, decided with it.
A failed key fetch aborts with exit 1 before writing the source line when no keyring is installed, rather than "keeping the installed key", which on a first install (this script run directly) would leave a `signed-by` pointing at a missing file (walkthrough 2026-09-23).
No apt pin, unlike `syncthing-update`, `apt-cache policy zotero` showing no Ubuntu candidate to outrank.
And the closing version comes from `dpkg-query` rather than from `zotero --version`, a GUI binary.

### The snap cannot keep Zotero current

Zotero was installed as `zotero-snap`, published by `extraymond`, a community package.
`update_snap` in `sys-update` and snapd's own four-hourly timer both refresh it, and `snap refresh --list` reported "All snaps up to date" on 2026-09-23 while the installed build was 9.0.1 and upstream was at 10.0.3 (released 2026-09-17, 10.0 on 2026-08-17).
The last commit of `extraymond/zotero-snap` is "Update Zotero-Snap to 9.0.1", dated 2026-04-26.
The existing mechanism therefore covers the refresh and not the currency: it stays a major version behind for as long as the packager does not publish.

### zotero-deb is the channel Zotero supports, and it tracks upstream

Zotero's installation page names only two Linux channels it supports, "the official tarball and zotero-deb".
The zotero-deb archive (`retorquere/zotero-pkg`, formerly `retorquere/zotero-deb`) listed 10.0.3 as its stable package on 2026-09-23, and the repository was pushed on 2026-09-17, the day of the upstream release.
`syncthing-update` is the precedent for a third-party apt repository in this repo, and the scoped refresh and FAIL-on-failed-refresh behaviour decided in `PLAN-UPDATER-HYGIENE.md` apply unchanged.

### Rejected options

- Doing nothing, keeping the snap: `update_snap` looks like coverage, which is why this option comes back first, but it delivers whatever the packager last published, five months stale here.
- A `zotero-update` installing the official tarball into a versioned `/opt` tree, on the `libreoffice-update` / `positron-update` shape: the most robust, since it depends on upstream alone, but about three times the script (version lookup, launcher, `.desktop`, purge of the superseded tree) and it has to switch off Zotero's built-in updater.
  Kept as the fallback below.
- The tarball in a user-writable directory updated by Zotero's built-in updater: no code, but updates happen only while Zotero runs and outside `sys-update`, against the single-entry-point rule of `rules/install.md`.

### The choice holds while zotero-deb follows upstream within days

zotero-deb has a single maintainer.
If it falls behind or stops, switch to the tarball option, as `rig-update` left its apt repository for the GitHub release `.deb` when the repository lagged.

### Plugins update inside Zotero, not through `sys-update` (decided 2026-09-23)

Decision: no module and no `zotero-update` step for Zotero plugins.
The deb leaves Zotero's add-on updater on: its `defaults/preferences/zotero.js` sets `extensions.update.enabled` and `extensions.update.autoUpdateDefault` to true with `extensions.update.interval` at 86400, while `/usr/lib/zotero/mozilla.cfg` locks only `app.update.enabled` and `app.update.auto`.
Both installed plugins declare an `update_url` on their GitHub releases (Better BibTeX, SciPDF), from which Zotero installs the newest version whose manifest accepts the running Zotero.
A script would have to write into the randomly named profile with Zotero closed and redo that compatibility choice, duplicating the mechanism less well; `rules/install.md` excludes Positron extensions on the same ground.
The accepted limit is that updates land only while Zotero runs, once a day, or at once through "Check for Updates" in Tools > Plugins.

### The snap-to-deb migration is a one-shot manual step, outside the module

The module installs and updates; it never moves data.
No local backup of `zotero.sqlite` is taken before the 9 to 10 schema upgrade: the library syncs to the user's Zotero account, which the user named as the recovery path on 2026-09-23.
That path only covers attachments because file syncing (Zotero Storage or WebDAV) is on for this account, confirmed 2026-09-23: data syncing alone carries library items and no attached file.
Zotero's sync page says nothing about `styles`, `translators`, the `better-bibtex` folder or the profile preferences, so treat them as local and carried by the data directory itself.
Done 2026-09-23, data now at `~/Zotero` and the profile at `~/.zotero`.

### Open points

- SciPDF is still 8.0.4, whose `strict_max_version` of `9.*` has Zotero 10.0.3 disabling it, awaiting Zotero's own add-on update to 8.1.1 (released 2026-09-09, declaring `10.*`).
