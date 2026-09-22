---
name: autoresearch skill evaluated and not adopted
description: Decision 2026-09-11 not to install the uditgoenka/autoresearch skill; its metric loop needs a git commit per iteration, which is denied here, and the rest duplicates ouroboros and the audit/workflow plugins; full analysis already done, do not redo it
metadata:
  type: project
---

On 2026-09-11 the Claude Code skill `uditgoenka/autoresearch` (v2.2.2, a generalisation of Karpathy's autoresearch) was evaluated in full and not installed.
Analysis, measurements and reopening conditions: `~/dotfiles/_meta/notes/autoresearch-skill-reco.md`.

**Why:** its only net contribution is the keep/discard metric loop, which commits once per iteration on a clean tree, while `settings.json` denies `git add`, `git commit`, `git reset`, `git checkout`, `git stash` and `git restore`: the loop stops at its first iteration. Its 13 other commands duplicate ouroboros, `/audit:*`, `posit-dev:describe-design`, `security-review` and `/loop`, and the plugin install would add 9 global Node hooks.

**How to apply:** if the subject returns, read the note rather than redo the analysis. Three conditions reopen the decision: a throwaway branch where automatic commits are acceptable (the candidate is `covr` coverage of `R-hebstr` and `R-edstr`), a fast scalar metric appearing on a project of the stack, or a release that decouples the loop from git. If ever adopted, copy the skill and commands by hand (option C of its README), never the plugin, so as not to inherit the hooks. Same shape as [[project_arity_evaluation]].
