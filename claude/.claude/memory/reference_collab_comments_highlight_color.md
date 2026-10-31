---
name: reference_collab_comments_highlight_color
description: The collab-comments editor highlight is a theme key of the hebstr fork; the two measured rgba values, the Error Lens provenance, and where the preference now lives
metadata:
  type: reference
---

The editor highlight of the comment extension is held by `hebstr/collab-comments`, the fork of `MikeLydeamore/collab-comments` cloned to `~/Documents/packages/collab-comments` and installed as a local VSIX by its `install.sh` (implemented 2026-10-31, the decision being in `quarto-hebstr-doc`'s `.claude/DESIGN-COLLAB-COMMENTS.md`, section « The editor half is to be forked too, as a VSIX that no gallery carries »). Two `contributes.colors` keys replace the literals: `commentTracker.openCommentBackground` and `commentTracker.resolvedCommentBackground`, consumed as a `ThemeColor` by the two decorations `activate()` builds, so the preference lives in each profile's `workbench.colorCustomizations` and survives every rebuild of the fork. The open-comment value set there on 2026-10-31 is `#00b7e438`, in `hebstr-positron` and in `hebstr-vscode` alike; the resolved one is left at its upstream default.

The two values as record, measured on `michaellydeamore.collab-comments` 1.1.0 before the fork: the open comment painted `rgba(234, 179, 8, 0.18)` and the resolved one `rgba(128, 128, 128, 0.12)`, both created at activation from literals in `dist/extension.js`, with `contributes.colors` empty and the only settings `commentTracker.defaultAuthor` and `commentTracker.scrollSyncPanel`. The blue asked for by name is Error Lens's info colour `#00b7e4`, the amber being confusable with an LSP diagnostic: measured in `usernamehw.errorlens` 3.30.0, it is the only blue that extension carries (error `#e45454`, warning `#ff942f`, hint `#2faf64`), its own backgrounds being that hue at alpha `20` hex. The alpha is raised to `0.22` (`38` hex) because a blue reads dimmer than the amber on the `#1e0e26` background of `material-night-purple`.

The hand patch of 2026-10-24 on the installed bundle is spent: upstream was uninstalled from both editors on 2026-10-31, from the profile registry and then globally, which leaves its folder marked in `.obsolete` for the editor to delete on its next run. The two extensions must never be installed at once, sharing thirteen registered `comment-tracker.*` command ids, twelve of them declared in the manifest, a view container and their settings keys.

See [[reference_positron_extension_registries]], [[project_collab_comments_evaluation]].
