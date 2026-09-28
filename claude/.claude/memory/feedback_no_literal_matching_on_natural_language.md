---
name: feedback_no_literal_matching_on_natural_language
description: Minimise literal matching in favour of behavioural instructions; regex belongs on formal input, never on natural language, and no new regex-heavy scripts to maintain
metadata:
  type: feedback
---

Stated by the user on 2026-09-28: as little literal matching as possible, in favour of behavioural instructions, even at the cost of determinism, and above all no multiplying of scripts full of rigid regexes to maintain.

The dividing line, drawn the same day from the hook inventory of `~/dotfiles/claude/.claude/hooks/`:

- **Literal matching is legitimate on a formal language**: a shell command (`.tool_input.command`), a path, a `/name` token, a JSON field. These have a grammar to anchor on.
- **It is not legitimate on natural language**: the user's prompt (`.prompt`) or the model's own prose (`.last_assistant_message`). There is no grammar, so a list of phrasings is a debt that never pays off.
- **Exception in the other direction**: a hook that *refuses* an action stays deterministic, because a probabilistic refusal protects nothing. `git-write-guard.sh` (which parses the `shfmt` tree rather than matching regexes) and `commit-gate.sh` keep their literal matching for that reason.

**Why:** measured on 2026-09-28, `reco-relance.sh`'s regex over French prompts had about 73 % recall (63 fires, ~23 genuine misses over 1,054 prompts). Two causes of comparable weight, both failures of the literal: 11 misspellings (the user typos constantly) and 18 rows correctly spelled but missed by the `que|tu` anchor the pattern required. Widening the list moves the boundary without removing it.

**How to apply:** before proposing a hook or script that recognises intent in prose, prefer a behavioural instruction in the always-loaded set, or a trigger on *state* rather than on wording (a marker another hook already computes). A design conforms only if it leaves **fewer** patterns to maintain than before, not more; deliberate non-coverage is an acceptable answer when a standing instruction is the net. Never answer a recall problem with a looser regex or a fuzzy-match helper script.

Related: [[feedback_load_matching_skill]], [[feedback_check_before_hand_rolling]], [[feedback_probe_must_test_the_deciding_form]].
