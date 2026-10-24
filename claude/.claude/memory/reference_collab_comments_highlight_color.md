---
name: reference_collab_comments_highlight_color
description: The collab-comments editor highlight colour is hardcoded in its bundle; patched to blue, and any extension update wipes it
metadata:
  type: reference
---

The Positron extension `michaellydeamore.collab-comments` (MikeLydeamore/collab-comments, distinct from the `collab-comments.lua` filter forked into hebstr-doc) paints its editor highlights from two literals in `dist/extension.js`, created at activation: `rgba(234, 179, 8, 0.18)` for an open comment and `rgba(128, 128, 128, 0.12)` for a resolved one. Measured at v1.1.0: `contributes.colors` is empty, no `ThemeColor`, no `overviewRulerColor`, and the only settings are `commentTracker.defaultAuthor` and `commentTracker.scrollSyncPanel`. So neither `workbench.colorCustomizations` nor any setting reaches that colour, and the panel CSS (`media/review.css`) carries none of it.

Patched 2026-10-24 on ju-TP: the open-comment literal reads `rgba(0, 183, 228, 0.22)`, the amber being confusable with LSP diagnostics. That blue is Error Lens's info colour `#00b7e4`, asked for by name: measured in `usernamehw.errorlens` 3.30.0, it is the only blue the extension carries (error `#e45454`, warning `#ff942f`, hint `#2faf64`), its own backgrounds being that hue at alpha `20` hex, and no profile setting or theme key overrides it here. The alpha is raised from 0.18 because a blue reads dimmer on the `#1e0e26` background of `material-night-purple`. The folder holds no `.vsixsignature`, so a modified bundle loads; a window reload is needed, the decorations being built in `activate`.

Any update or reinstall of the extension restores the amber without warning. The durable fix is upstream (a setting or a `contributes.colors` key); the repo ships an `AGENTS.md`.

See [[reference_positron_extension_registries]], [[project_collab_comments_evaluation]].
