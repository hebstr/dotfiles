---
name: reference_collab_comments_highlight_color
description: The collab-comments editor highlight: upstream is installed with a hand patch, the hebstr fork holds the theme keys but its install is deferred; the two rgba values and the blue's source
metadata:
  type: reference
---

**What is installed is upstream, `michaellydeamore.collab-comments` 1.1.0 in the `hebstr-positron` profile only, and its highlight is a hand patch on `dist/extension.js`.** The durable form is built and not installed: `hebstr/collab-comments` at `~/Documents/packages/collab-comments` carries `commentTracker.openCommentBackground` and `commentTracker.resolvedCommentBackground` as `contributes.colors`, consumed as a `ThemeColor` by the two decorations `activate()` builds, which moves the colour into each profile's `workbench.colorCustomizations`; the user deferred the switch on 2026-10-31, the day the fork landed, so no colour key is set in either profile's settings and the machine state is the row of `~/dotfiles/.claude/DEFERRED.md` dated that day. The fork's own `.claude/PLAN.md` holds its state, and the decision is in `quarto-hebstr-doc`'s `.claude/DESIGN-COLLAB-COMMENTS.md`, section « The editor half is to be forked too, as a VSIX that no gallery carries ».

The two values, measured on upstream 1.1.0: the open comment paints `rgba(234, 179, 8, 0.18)` as shipped and `rgba(0, 183, 228, 0.22)` as patched, the resolved one `rgba(128, 128, 128, 0.12)`, all created at activation from literals, with `contributes.colors` empty and the only settings `commentTracker.defaultAuthor` and `commentTracker.scrollSyncPanel`, so no `workbench.colorCustomizations` reaches them. The blue asked for by name is Error Lens's info colour `#00b7e4`, the amber being confusable with an LSP diagnostic: measured in `usernamehw.errorlens` 3.30.0, it is the only blue that extension carries (error `#e45454`, warning `#ff942f`, hint `#2faf64`), its own backgrounds being that hue at alpha `20` hex. The alpha is raised to `0.22` (`38` hex, which is the `#00b7e438` the fork's keys take) because a blue reads dimmer than the amber on the `#1e0e26` background of `material-night-purple`.

The patch survives more than the 2026-10-24 reading assumed, measured 2026-10-31 on the round trip of that day: uninstalled and reinstalled from the gallery at the same version, the folder on disk is reused and the blue is still there, so what restores the amber is a new upstream version rather than any reinstall. A window reload is needed either way, the decorations being built in `activate`.

The two extensions must never be installed in one editor at once, sharing the thirteen `comment-tracker.*` command ids upstream registers, twelve of them declared in its manifest, a view container and their settings keys, and a duplicate command id fails the second one's activation. Switching is therefore two uninstalls then `install.sh`, in that order.

See [[reference_positron_extension_registries]], [[project_collab_comments_evaluation]].
