---
name: reference_git_html_id_filter
description: The `html-id` git clean filter that renumbers gt and reactable random ids and the reactable `dataKey` in committed HTML outputs: its driver lives in dotfiles so `stow git` is the whole setup, the per-repo half says which files are deliverables, a global attributes file was rejected, and a commit after a render fails in prek's unstaged-changes stash until the outputs are re-staged with `git add --renormalize`
metadata:
  type: reference
---

A rendered HTML output carries ids that change on every render: `gt` draws a random one per table, `reactable` one per widget. Committing such a file makes every render look like a change. The `html-id` clean filter renumbers them, `gt1` in order of appearance and `htmlwidget-wdg1` likewise, so a new render diffs only on content.

**A third rule renumbers the reactable `dataKey` (`dk1`, `dk2` per file) since 2026-10-03.** It is `digest::digest(list(data, cols))`, a hash of the widget's inputs including closures and hidden `colDef` state, so it moves on a re-render while the visible HTML stays byte-identical. The regex is anchored on `"dataKey":"` plus 32 hex plus `"`: the reactable JS library also contains the bare word `dataKey`. Adding the rule meant a one-time `git add --renormalize` of every widget blob already in `HEAD`. `prek-metadata-only` never covered HTML (its `files` is docx, pptx, xlsx, png), so `--restore` could not help.

**The setup is split in two halves on purpose.** The driver (`filter.html-id.clean`) lives in `~/dotfiles/git/.gitconfig` since 2026-09-12, so `stow git` is the whole installation and a fresh clone needs nothing more. The half that stays versioned per repository is its `.gitattributes`, because that is the half that says which files are deliverables: `output/**/*.html` in `eds-prise`, and the same driver serves `md-nesrine`. `~/dotfiles/_meta/profiles/gitattributes` carries the line a third project would declare.

**A global attributes file was rejected**, and the reason still holds: it would apply to every repository on the machine, third-party clones included, where renumbering ids is not wanted.

The same per-repo file routes `*.docx`, `*.pptx`, `*.xlsx` and `*.png` to a `diff=out-textconv` driver since 2026-09-13.

**What tells you the filter is armed, and what does not.** `git check-attr filter -- <file>` and `git config --get filter.html-id.clean` say the filter is wired and which one it is; neither says whether the content differs. For that, and for the trap where `git status` reports the gt outputs modified after a render while the filtered content is identical, see the project's own `CLAUDE.md`, section « Le filtre des identifiants HTML », which carries the oracle and the count.

**A render leaves the tree in a state prek cannot commit from** (measured 2026-10-03, eds-prise, prek with a `prose-lint` hook).
After a render, the filtered HTML outputs sit as unstaged changes, and prek stashes unstaged changes into a patch before running its hooks.
Restoring that patch fails on the lines the filter renumbers (`patch failed: output/...html:1246`), and prek reports the first hook as "files were modified by this hook" although that hook only reads.
The commit fails identically with `git commit -- <paths>` and with a plain `git commit`, whether `git diff-files --quiet` is clean or not.
What works: `git add --renormalize <output dir>` first, so no unstaged change is left to stash, and the commit then takes the refreshed outputs along; the other way out is `git checkout -- <output dir>`, which drops the render.
A hook name in that failure message is not evidence against the hook: run it alone on the commit's files before reading it as the culprit.

Related: [[reference_pandoc_312_data_uri]] for the other reason a committed widget's HTML can change under you.
