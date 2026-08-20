---
name: Positron extension registries (profile vs global)
description: Positron's per-profile extensions.json is the authoritative registry for the active profile; the global one lags. Never delete extension folders judged orphan by the global registry alone, and never expect a hand-dropped extension folder to load under a custom profile.
metadata:
  type: reference
---

Positron (and VSCode) keep **two** extension registries, and they can diverge:

- **Global**: `~/.positron/extensions/extensions.json` — governs the `__default__profile__`.
- **Per-profile**: `~/.config/Positron/User/profiles/<id>/extensions.json` — the **authoritative** source of truth for what the active profile actually loads.

Both list entries with `identifier.id`, `version`, `location.path` (absolute), `relativeLocation` (folder basename), and `metadata.targetPlatform`. The profile registry routinely points to **different folders** than the global one (e.g. global → `posit.air-vscode-0.24.0`, profile → `posit.air-vscode-0.24.0-linux-x64`), and the global registry often lags behind on version (points to older folders the profile no longer uses, or vice-versa).

**Hard rule learned the hard way (2026-06-09):** never decide a folder under `~/.positron/extensions/` is an "orphan" safe to delete based on the global `extensions.json` alone. Cross-check the **profile** registry first. Deleting global-orphan folders that the profile references silently breaks those extensions on next Positron restart (including formatters: `posit.air-vscode` for R, `myriad-dreamin.tinymist` for typst).

**Recovery when folders were wrongly deleted and registries point to nonexistent paths** (Positron MUST be closed; it rewrites the registry on exit):
- `positron --profile <name> --install-extension <id> [--force]` is unreliable here: it reads the stale registry, reports "already installed" while the folder is gone, and its updater throws "Cannot read the extension from <missing folder>".
- Deterministic fix instead: edit the JSON directly with `jq`. Transplant a known-good entry (from whichever registry still points to an existing folder) into the broken one, or drop stale/duplicate entries. Verify every `location.path` resolves: `jq -r '.[].location.path' <reg> | while read -r p; do [ -d "$p" ] || echo "BROKEN $p"; done`, and check for duplicate ids with `jq -r '.[].identifier.id' <reg> | sort | uniq -d`.

**Per-profile extension enablement:** installing via `--install-extension` (no `--profile`) or into the default profile does NOT add the extension to a custom profile. To enable an already-installed extension in a custom profile, use the Extensions view with that profile active (the card shows **Install**, reusing the existing binary) or `--profile <name> --install-extension`. See also panache formatter setup in [[project_qmd_format_hook]], and [[reference_tool_update_routines]] for how the panache and tinymist extensions resolve their binaries (`jolars.panache` reads the PATH one, `myriad-dreamin.tinymist` uses its bundled server). `meta.pyrefly` (`pyrefly.lspPath`) and `posit.air-vscode` (`air.executableStrategy`) are two more that would otherwise run a bundled copy; `rules/environment.md` ("One tool, one binary") holds all of them.

**A folder dropped into `~/.positron/extensions/` is never loaded by a custom profile (2026-08-20).** Only the profile registry decides, and nothing adds a hand-placed folder to it: not a Reload Window, not a restart, not `positron --profile <name> --list-extensions`. The trap is that `positron --list-extensions` **without** `--profile` does register it, in the global registry, and then reports it as installed. That is a false positive for any profile-based session. A symlink into the extensions directory is followed correctly, so the failure is registration, never resolution.

**Clear both registries before reinstalling over a hand-written entry.** With a manual entry still present, `--install-extension` fails on `Please restart VS Code before reinstalling` (and restarting does not help, since the entry, not the process, is the problem). Delete the entry from the profile registry **and** from the global one, then install: the entry Positron writes itself carries `metadata.source: "vsix"`, which is how a properly installed extension is told apart from a hand-registered one.
