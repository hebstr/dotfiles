---
name: reference_git_html_id_filter
description: The `html-id` git clean filter that renumbers gt and reactable random ids in committed HTML outputs: its driver lives in dotfiles so `stow git` is the whole setup, the per-repo half says which files are deliverables, and a global attributes file was rejected
metadata:
  type: reference
---

A rendered HTML output carries ids that change on every render: `gt` draws a random one per table, `reactable` one per widget. Committing such a file makes every render look like a change. The `html-id` clean filter renumbers them, `gt1` in order of appearance and `htmlwidget-wdg1` likewise, so a new render diffs only on content.

**The setup is split in two halves on purpose.** The driver (`filter.html-id.clean`) lives in `~/dotfiles/git/.gitconfig` since 2026-09-12, so `stow git` is the whole installation and a fresh clone needs nothing more. The half that stays versioned per repository is its `.gitattributes`, because that is the half that says which files are deliverables: `output/**/*.html` in `eds-prise`, and the same driver serves `md-nesrine`. `~/dotfiles/_meta/profiles/gitattributes` carries the line a third project would declare.

**A global attributes file was rejected**, and the reason still holds: it would apply to every repository on the machine, third-party clones included, where renumbering ids is not wanted.

The same per-repo file routes `*.docx`, `*.pptx`, `*.xlsx` and `*.png` to a `diff=out-textconv` driver since 2026-09-13.

**What tells you the filter is armed, and what does not.** `git check-attr filter -- <file>` and `git config --get filter.html-id.clean` say the filter is wired and which one it is; neither says whether the content differs. For that, and for the trap where `git status` reports the gt outputs modified after a render while the filtered content is identical, see the project's own `CLAUDE.md`, section « Le filtre des identifiants HTML », which carries the oracle and the count.

Related: [[reference_pandoc_312_data_uri]] for the other reason a committed widget's HTML can change under you.
