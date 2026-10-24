---
name: Positron extension registries (profile vs global)
description: Positron's per-profile extensions.json is the authoritative registry for the active profile; the global one lags. Never delete extension folders judged orphan by the global registry alone, and never expect a hand-dropped extension folder to load under a custom profile. Also how to remove an extension cleanly from Positron or VSCode: two uninstalls, the .obsolete marker each editor handles differently, the settings keys, and the state.vscdb residue down to every workspaceStorage base.
metadata:
  type: reference
---

Positron (and VSCode) keep **two** extension registries, and they can diverge:

- **Global**: `~/.positron/extensions/extensions.json`, which governs the `__default__profile__`.
- **Per-profile**: `~/.config/Positron/User/profiles/<id>/extensions.json`, the **authoritative** source of truth for what the active profile actually loads.

Both list entries with `identifier.id`, `version`, `location.path` (absolute), `relativeLocation` (folder basename), and `metadata.targetPlatform`. The profile registry routinely points to **different folders** than the global one (e.g. global → `posit.air-vscode-0.24.0`, profile → `posit.air-vscode-0.24.0-linux-x64`), and the global registry often lags behind on version (points to older folders the profile no longer uses, or vice-versa).

**Hard rule learned the hard way (2026-06-09):** never decide a folder under `~/.positron/extensions/` is an "orphan" safe to delete based on the global `extensions.json` alone. Cross-check the **profile** registry first. Deleting global-orphan folders that the profile references silently breaks those extensions on next Positron restart (including formatters: `posit.air-vscode` for R, `myriad-dreamin.tinymist` for typst).

**Recovery when folders were wrongly deleted and registries point to nonexistent paths** (Positron MUST be closed; it rewrites the registry on exit):
- `positron --profile <name> --install-extension <id> [--force]` is unreliable here: it reads the stale registry, reports "already installed" while the folder is gone, and its updater throws "Cannot read the extension from <missing folder>".
- Deterministic fix instead: edit the JSON directly with `jq`. Transplant a known-good entry (from whichever registry still points to an existing folder) into the broken one, or drop stale/duplicate entries. Verify every `location.path` resolves: `jq -r '.[].location.path' <reg> | while read -r p; do [ -d "$p" ] || echo "BROKEN $p"; done`, and check for duplicate ids with `jq -r '.[].identifier.id' <reg> | sort | uniq -d`.

**Per-profile extension enablement:** installing via `--install-extension` (no `--profile`) or into the default profile does NOT add the extension to a custom profile. To enable an already-installed extension in a custom profile, use the Extensions view with that profile active (the card shows **Install**, reusing the existing binary) or `--profile <name> --install-extension`. See also panache formatter setup in [[project_qmd_format_hook]]; which extensions are pinned to the managed binary rather than a bundled copy is in `rules/install.md` § "One tool, one binary".

**A folder dropped into `~/.positron/extensions/` is never loaded by a custom profile (2026-08-20).** Only the profile registry decides, and nothing adds a hand-placed folder to it: not a Reload Window, not a restart, not `positron --profile <name> --list-extensions`. The trap is that `positron --list-extensions` **without** `--profile` does register it, in the global registry, and then reports it as installed. That is a false positive for any profile-based session. A symlink into the extensions directory is followed correctly, so the failure is registration, never resolution.

**A VSIX reinstall over a gallery-installed extension breaks it for the custom profile (2026-10-19, `posit.air-vscode` 0.30.0).** The VSIX install removed the gallery folder `posit.air-vscode-0.30.0-linux-x64`, created `posit.air-vscode-0.30.0` and registered it in the **global** registry only; the profile registry kept the platform-suffixed path, and Positron reported `Invalid extensions detected` with `Unable to resolve nonexistent file .../package.json`. The failure mode is therefore not only that the profile never sees a new extension, but that it loses one that worked. Fix: transplant the global entry into the profile registry with Positron closed, then check that every `location.path` of both registries resolves.

**Removing an extension cleanly takes two uninstalls and a sweep outside the registries (measured 2026-10-25, `alefragnani.project-manager` out of Positron and VSCode).**

- `--profile <name> --uninstall-extension <id>` clears the **profile** registry only; the plain `--uninstall-extension <id>` clears the **global** one. After the first call the folder is still on disk and still registered globally, so both calls are required.
- Positron deletes an `.obsolete`-marked folder at its next startup but never prunes the `.obsolete` entry (19 stale entries, 0 surviving folders). **VSCode purges neither**: measured before the removal, all 23 of its `.obsolete` entries still had their folder, 21 of them stacked `anthropic.claude-code-*`. With both registries verified empty, deleting the folder by hand is the deterministic move.
- An extension's data sits at `User/globalStorage/<publisher>.<name>/`, **not** under the profile directory, on both editors.
- `state.vscdb` residue is in **keys and values**, across the global, per-profile **and every** `workspaceStorage/*/state.vscdb` (43 of 44 Positron workspace bases held one). Keys: `<id>`, `extensionKeys/<id>@<version>`, `workbench.view.extension.<view>.state[.hidden]`, `.numberOfVisibleViews`. Values: `workbench.activity.pinnedViewlets2`, `.placeholderViewlets`, `.viewletsWorkspaceState`, `__$__targetStorageMarker`, `extensions.trustedPublishers` (publisher-wide, so drop it only when no sibling extension remains), `workbench.welcomePage.walkthroughMetadata`, `memento/gettingStartedService`, `memento/mainThreadWebviewPanel.origins`, `notifications.perSourceDoNotDisturbMode`.
- Two shapes defeat a naive sweep: `commandPalette.mru.cache` identifies its entries by a `key` field rather than `id`, and `workbench.sidebar.activeviewletid` holds a **bare non-JSON string**; left behind, it makes that workspace open on a viewlet that no longer exists.
- No `sqlite3` CLI on this machine; `python3 -c "import sqlite3"` works (3.45.1). Settings files are JSONC, so `jq` rejects them even when they are valid: strip comments outside strings and trailing commas before parsing.
- A profile export (`.code-profile`) embeds the extension list, its settings and its workbench state, so every snapshot keeps reinstalling the extension until re-exported. Four carried this one.

**Clear both registries before reinstalling over a hand-written entry.** With a manual entry still present, `--install-extension` fails on `Please restart VS Code before reinstalling` (and restarting does not help, since the entry, not the process, is the problem). Delete the entry from the profile registry **and** from the global one, then install: the entry Positron writes itself carries `metadata.source: "vsix"`, which is how a properly installed extension is told apart from a hand-registered one.
