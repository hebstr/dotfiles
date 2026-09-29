---
name: Zotero's stow-managed user.js reverts every preference pane change
description: Why a Zotero or Better BibTeX preference set in the settings pane reverts at the next restart, which file to read first, and the citation key facts measured alongside it
metadata:
  type: reference
---

The Zotero profile `~/.zotero/zotero/pucr7b5d.default/` is stow-managed and resolves into `~/dotfiles/zotero/`. It holds both `prefs.js`, which Zotero writes, and `user.js`, which Zotero **reads and re-applies at every startup**. A preference the settings pane changes lands in `prefs.js` and works for that run; if `user.js` declares the same key, the next start overwrites it, with no warning anywhere in the UI.

Established 2026-09-29 on the Better BibTeX citation key formula: `prefs.js` carried `auth.lower + "_" + year` while `user.js` carried `auth.lower + shorttitle(3,3) + year`, and items added on 2026-09-22 had keys in the `user.js` format, so a pane change had been silently undone at an earlier restart. Watched live the same day: `prefs.js` was rewritten back to the `user.js` value at a 14:57 restart.

This supersedes the 2026-09-23 resolution in `~/dotfiles/_meta/notes/zotero-agent-access-reco.md`, which saw the same symptom (keys not following `citekeyFormat`) and stopped at "l'utilisateur avait changé la formule à la main". The manual change was real; what that note missed is why it did not survive, which is this file precedence.

**Read `user.js` first, never `prefs.js`.** A key in both means `user.js` wins and `prefs.js` is a decoy. A key in `prefs.js` only means the pane is authoritative. The cheapest proof that a pane change never took is the artifact, not either file: here, the citation keys of recently added items. Set the value in `user.js` at its resolved dotfiles path, and restart Zotero for it to apply.

**eds-prise settled its own formula on 2026-09-29** in that repository's `.claude/DESIGN-BIB.md`: `user.js` takes `auth + "_" + year`, the repo's convention, so a new record is born with the right key. Existing keys do not move, Zotero 8+ keeping every key pinned in a native field. The formula serves the articles only: the five HAS suffixes (`_reco`, `_argu`, `_fiche`, `_snds`, `_eds`) stay hand-set on the eight HAS records, since `auth + "_" + year` cannot separate them and BBT would only add a meaningless disambiguation letter. An earlier section of that same note, "L'état constaté avant bascule", records the pre-decision state and argues against the change: it is superseded, and reading it as current is how this session wrongly reverted the formula once.

Citation key facts measured on the same library (315 top-level items, 211 with an author), true whatever the formula:

- `auth` gives the first author's last name as stored; `.lower` alone lowercases it.
- Diacritics fold to ASCII in keys with no filter (`Munafò` gave `munafo…`, `Vergnenègre` gave `vergnenegre…`), so `.transliterate` is redundant for that purpose.
- A single-field institutional creator (`"name": "Haute Autorité de santé"`) enters `auth` whole: no formula yields `HAS`.
- Changing the formula never regenerates existing keys (BBT docs: "existing keys are not automatically regenerated when you change the pattern"); only a per-selection right-click "Refresh" does.
- Key clashes take an automatic `a`/`b`/`c` postfix that cannot be disabled, which is what `shorttitle` in the default formula exists to avoid. Real clashes in this library: Bewick ×3 in 2004, Vergnenègre ×2 in 2004, plus Curran-Everett, Ioannidis, Marill, Pham, Whitley.

Related: [[reference_better_bibtex_export_control]] for what a BBT export honours and the `preferencesOverride` route, [[project_zotero_agent_access]] for the read-only rule that forbids fixing any of this through the JSON-RPC.
