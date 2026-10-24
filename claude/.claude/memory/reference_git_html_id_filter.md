---
name: reference_git_html_id_filter
description: The `html-id` git clean filter that renumbers gt and reactable random ids and the reactable `dataKey` in committed HTML outputs: its driver lives in dotfiles so `stow git` is the whole setup, the per-repo half says which files are deliverables, a global attributes file was rejected, and a commit after a render fails in prek's unstaged-changes stash until the outputs are re-staged with `git add --renormalize`, while that same stash quietly reverts an unstaged binary output (docx, png, xlsx) to its committed content, and the same montage carries a sibling filter, `comment-hash`, zeroing the `documentHash` of eds-prise's collab-comments store
metadata:
  type: reference
---

A rendered HTML output carries ids that change on every render: `gt` draws a random one per table, `reactable` one per widget. Committing such a file makes every render look like a change. The `html-id` clean filter renumbers them, `gt1` in order of appearance and `htmlwidget-wdg1` likewise, so a new render diffs only on content.

**A third rule renumbers the reactable `dataKey` since 2026-10-03** (its digest and the regex anchoring are in `_meta/notes/git-html-id-filter.md`): the key moves on a re-render while the visible HTML stays byte-identical. Adding the rule meant a one-time `git add --renormalize` of every widget blob already in `HEAD`. `prek-metadata-only` never covered HTML (its `files` is docx, pptx, xlsx, png), so `--restore` could not help.

**The setup is split in two halves on purpose**, the driver stowed and the `.gitattributes` versioned per repository because that is the half naming which files are deliverables; `_meta/profiles/gitattributes` carries the line a new project declares.
**That montage carries a second filter since 2026-10-24**, `comment-hash`, which zeroes the `documentHash` of eds-prise's `.comments/collab-comments.json`: same two halves, a perl driver in `~/.config/git/` declared in `~/.gitconfig`, and a `.gitattributes` line anchored on that one file. A clone without the drivers stores the raw shapes and nothing breaks, which is the property both filters rely on.

**The path anchoring of that line buys nothing, measured 2026-10-21 in eds-prise**, which declares `*.html filter=html-id` since then while the profile still carries `output/**/*.html`. What keeps the filter off a hand-written file is the driver's own anchoring, its three regexes matching only generated shapes (`<div id="[a-z]{10}" style="padding-left` for gt, `htmlwidget-` plus 16 or more hex, `"dataKey":"` plus 32), so it came back byte-identical on the one tracked HTML outside that project's output trees, a vendored Quarto extension file, same blob sha through `git hash-object -w --path`. The cost of the narrow form is upkeep: it has to be edited every time an output tree moves. The cost of the broad form is that an ignored rendered document enters the pattern, so a deliberate `git add -f` on one stores it renumbered.


The same per-repo file routes `*.docx`, `*.pptx`, `*.xlsx` and `*.png` to a `diff=out-textconv` driver since 2026-09-13.

**What tells you the filter is armed, and what does not.** `git check-attr filter -- <file>` and `git config --get filter.html-id.clean` say the filter is wired and which one it is; neither says whether the content differs. For that, and for the trap where `git status` reports the gt outputs modified after a render while the filtered content is identical, see the project's own `CLAUDE.md`, section « Les filtres `clean` du dépôt », subsection « Les identifiants HTML », which carries the oracle and the count.

**A render leaves the tree in a state prek cannot commit from** (measured 2026-10-03, eds-prise, prek with a `prose-lint` hook).
After a render, the filtered HTML outputs sit as unstaged changes, and prek stashes unstaged changes into a patch before running its hooks.
Restoring that patch fails on the lines the filter renumbers (`patch failed: output/...html:1246`), and prek reports the first hook as "files were modified by this hook" although that hook only reads.
The commit fails identically with `git commit -- <paths>` and with a plain `git commit`, whether `git diff-files --quiet` is clean or not.
What works: `git add --renormalize <output dir>` first, so no unstaged change is left to stash, and the commit then takes the refreshed outputs along; the other way out is `git checkout -- <output dir>`, which drops the render.
A hook name in that failure message is not evidence against the hook: run it alone on the commit's files before reading it as the culprit.

**The same stash reverts an unstaged binary output instead of failing** (measured 2026-10-21, eds-prise). Thirteen `output/**/*.docx` sat dirty from earlier renders, none of them staged; a commit staging one `.R` file printed `Temporarily saving them to …/patches/<ts>.patch` then `Restored unstaged changes`, exited 0, and left those thirteen byte-identical to `HEAD`, carrying the commit's own mtime, verified by `git hash-object <f>` against `git rev-parse HEAD:<f>`.
So the text case fails loudly and the binary case succeeds quietly: a dirty `.docx`, `.png` or `.xlsx` left out of the commit comes back at its committed content, and a render whose only difference is envelope metadata is then indistinguishable from one that changed the artifact. Stage the binaries you mean to keep, and never read a clean `git status` after such a commit as proof the outputs were up to date.

Related: [[reference_pandoc_312_data_uri]] for the other reason a committed widget's HTML can change under you.
