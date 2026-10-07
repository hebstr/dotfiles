---
name: sparse-checkout and submodule update left outside the git write guard
description: git sparse-checkout set and git submodule update stay ungated by git-write-guard.sh, measured 2026-10-07 on git 2.55.0; neither bare form loses uncommitted work, do not re-propose them
metadata:
  type: project
---

`git sparse-checkout set` and `git submodule update` are not in the gated verbs of `git-write-guard.sh`, and the decision on 2026-10-07 is to leave them there. Both names suggest a working-tree rewrite on the level of the two forms the guard does deny ("git read-tree -u, which overwrites working tree files", "git checkout-index -f, which overwrites working tree files"), and that analogy is what the measurements refute.

Measured on git 2.55.0, 2026-10-07, in throwaway repositories:

- `git sparse-checkout set keep`, with a modified tracked file and an untracked file under the excluded directory, warned `The following paths are not up to date and were left despite sparse patterns` and left both in place with their content. Only files identical to HEAD leave the working tree, `disable` restores them all, and the INTERNALS section of the installed manual has the skip-worktree bit hide an unpopulated file's absence, so nothing surfaces as a deletion in `git status` for a later `git add` to stage.
- `git submodule update` on a submodule already at its pinned commit was a no-op and left the dirty file; it runs a non-forced checkout otherwise. Only `--force` discarded the local modification, while leaving the untracked file.
- `fdfind -H -t f '^\.gitmodules$' /home/julien --max-depth 4` returns nothing: no submodule exists here.

Revisit trigger: a project gaining a submodule, which would make `git submodule update --force` the one candidate worth a deny rule.

**Why:** the guard's threshold is losing working-tree content the tracking verification sealed, which neither bare form crosses, and a reviewer reading the verb list sees two obvious holes and re-proposes closing them from the names alone. The refutation costs two scratch repositories to rebuild.
**How to apply:** do not propose gating either verb in `git-write-guard.sh` or in the `deny` list of `settings.json` without a fact these measurements do not cover. The permission layer behind them is already recorded: `permissions.allow` carries a bare `"Bash"`, so every command absent from `deny` and `ask` runs with no dialog ([[reference_claude_code_best_practices]]), which is the posture, not an oversight to patch verb by verb. The guard's own suite pins its fail-closed branches, so a new gated verb needs a case there ([[project_claude_dir_local_only_repo]]).
