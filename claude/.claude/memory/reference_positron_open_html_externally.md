---
name: Positron open html externally
description: Making an explorer click open a file in Firefox needs a customEditor viewType plus workbench.editorAssociations; workbench.externalBrowser only covers http/https and bypasses the .desktop entry, so a Positron link reads profiles.ini; xdg-open on file:// works here
metadata:
  type: reference
---

**A click in the Positron/VSCode explorer can only be routed to an external app through a custom editor.** `workbench.editorAssociations` maps a glob to a `viewType` registered **inside** the application, never to an executable, and Positron ships no HTML editor (its only `viewType` are markdown, media, `positronPdfServer.previewEditor`, `positron-r.rdataLoader`/`rdsLoader`). The working shape, installed 2026-10-29 for `.html` to Firefox:

- `slaugaus.open-with-system` (Open VSX, mirrored on Positron's gallery `p3m.dev/openvsx`), 7.7 kB, whole source read: it registers `viewType: "open-with-system"` for `*` with `priority: "option"`, and `resolveCustomEditor` spawns `xdg-open <file uri>` detached then disposes the panel, so the tab self-closes. No network, no telemetry, no command; its README is empty.
- `"workbench.editorAssociations": { "*.html": "open-with-system" }` in the profile settings (`profiles/-eb36ac2/settings.json` for `hebstr-positron`, symlinked to dotfiles).
- Install into a custom profile with `positron --profile <name> --install-extension`, per [[reference_positron_extension_registries]]; the global registry stays empty, which is normal. The Claude Code auto-mode classifier refuses that install ("Untrusted Code Integration"): hand the command to the user.
- Cost: a click no longer edits the file; editing goes through right-click, *Open With...*, *Text Editor*.

**Posing the association before the extension exists is safe**: `resolveEditor` in the workbench bundle falls back to `DEFAULT_EDITOR_ASSOCIATION.id` when the named `viewType` resolves to nothing.

**`workbench.externalBrowser` (`"firefox"`, a browser alias or an absolute path) only covers http and https.** `openExternal` in the main bundle tests the scheme and sends everything else to `doOpenShellExternal` (Electron `shell.openExternal`), so a `file://` never sees the setting. It stays the right key for previews, the integrated Browser editor and clicked links; `positron.runApp.previewMode: "external"` and `positron.appLauncher.terminalAppUrlOpenLocation: "browser"` are its app-launcher counterparts, and the Viewer's own "Open in Browser" remembers its choice in **workspace** storage, not in settings.

**`workbench.externalBrowser` spawns the browser binary directly and never goes through the `.desktop` entry**, so a Positron-opened link reads `profiles.ini` where a desktop-launched one does not: the user override `~/.local/share/applications/firefox.desktop` passes `--profile /home/julien/.mozilla/firefox/z24d9fn6.default-release`, which bypasses that file, while Positron runs `/usr/lib/firefox/firefox <url>` bare. Seen 2026-10-31: `profiles.ini` had been rewritten with `StartWithLastProfile=0` and a `[Profile1]` section with no `[Profile0]`, so every Positron link raised the Profile Manager with an empty list, Firefox enumerating `Profile0`, `Profile1`, … and stopping at the first missing index. No apt operation was logged that day, so the rewrite came from Firefox itself and could recur. Fix: `StartWithLastProfile=1` and renumber to `[Profile0]`.

**`xdg-open` on a `file://` path works from a Positron-spawned shell** (measured 2026-10-29: a fresh `firefox ... probe.html` process plus its content processes). The earlier memory claiming it fails silently was taken on 2026-03-30 and no longer reproduces, so it is deleted: serving a local HTML through `python3 -m http.server` is a workaround for a problem this machine no longer has. Firefox here is the deb at `/usr/lib/firefox`, and `xdg-mime query default text/html` answers `firefox.desktop`. See [[feedback_browser_layout_probe]] for when a headless browser is still the right probe.
