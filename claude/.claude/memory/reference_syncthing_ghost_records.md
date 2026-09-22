---
name: "Syncthing \"Syncing 99 %\" that never ends: diagnosing ghost records"
description: How to find which device holds a stale valid record of an ignored path (syncthing debug database-file, not availability), and how the phones' hand-copied .stignore cause it
metadata:
  type: reference
---

Symptom: `ju-TP`'s GUI holds a device at "Syncing (99 %)" for good, and `/rest/db/remoteneed` lists paths that are ignored on `ju-TP` itself (`.git`, `node_modules`, `rv/library`, `.quarto`, session dirs). Some other device still announces those paths as valid, so its record stands as global and every device that ignores them "needs" them without ever pulling them.

**Find the source with `syncthing debug database-file <folder> <path>`** on `ju-TP` (works while Syncthing runs). It prints one row per device with flags: `G` global holder, `v` device announcing invalid, `i` local ignore. The culprit is the remote row carrying `G` without `v`. **Never use `/rest/db/file`'s `availability`** for this: on 2026-09-21 it named `ju-DG` and `ju-TP2` while `database-file` showed both `v` and `ju-GO` as `G`, which led to six unnecessary folder resets on `ju-TP2`.

**Cause on this fleet:** `ju-TP` and `ju-TP2` stow each `~/<folder>/.stignore` as a link into `~/dotfiles/syncthing/`, so they follow the repo. `ju-DG` (an Android phone) and `ju-GO` hold hand copies inside each folder, which syncing `dotfiles` never refreshes. After any change to a `.stignore` in the repo, each of them must get the new content pasted into that folder's ignore patterns in its Syncthing app.

**Fix:** paste the current patterns in the app and save; the device re-announces newly ignored paths as invalid within a minute or two (measured on `ju-DG` and `ju-GO` 2026-09-21). Removing and re-adding the folder also works but is unnecessary. On a receive-only folder, a file deleted by hand on the device (e.g. a `.stignore` moved rather than copied out of `dotfiles`) shows as `del` + `v` and is fixed by "Revert Local Changes" there.

Related, not a ghost: a pull error "directory has been deleted on a remote device but contains ignored files" means a leftover ignored item (often an empty `.git`) blocks a delete or a directory-to-symlink change; remove it by hand. If `POST /rest/system/reset?folder=` is ever needed, the folder must be paused first, and each call restarts Syncthing, so space them out or systemd's start limit stops the service (`systemctl --user reset-failed syncthing` then `start`).

See [[project_ju_tp2_receiveonly]].
