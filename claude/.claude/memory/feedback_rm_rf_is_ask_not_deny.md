---
name: feedback_rm_rf_is_ask_not_deny
description: The three `rm -rf` permission rules sit in `ask`, not `deny`, since 2026-10-06: run the deletion and let the prompt decide, never hand the command to the user
metadata:
  type: feedback
---

`Bash(rm -rf*)`, `Bash(rm -fr*)` and `Bash(rm -r -f*)` are in `permissions.ask` of `~/dotfiles/claude/.claude/settings.json`, moved out of `deny` by the user on 2026-10-06.
So a cleanup that needs a recursive delete is **run**, with the prompt as the gate. Do not hand the command over as "à exécuter par toi", and do not propose moving the rules back to `deny`.

**Why:** under `deny` the only outcome was a command pasted into the conversation for the user to run by hand, which they refused as a discipline. Two incidents named it: the `.claude/screenshots/` pruning of 2026-10-06 (62 files the session had classified and could not delete), and the Chromium probe artefacts of `dotfiles/.claude/PLAN-ORPHANS.md`, step 9, "the removal having been declined as a bundled `rm -rf`". A prompt the user answers costs one keystroke and keeps the same veto.

**How to apply:** build the delete list explicitly, by name rather than by glob wherever the set is enumerable, state what is kept and why before the call, then run it. The prompt shows the whole command, so it is the review. A target with no git net (`.claude/screenshots/`, an ignored directory, an `_archive/` tree) is named as such in the same breath, since nothing recovers it afterwards.

Related: [[feedback_verify_native_gc_semantics]], [[feedback_git_clean_tree_hides_ignored]], [[reference_claude_code_best_practices]].
