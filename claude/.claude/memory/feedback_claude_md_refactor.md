---
name: CLAUDE.md Progressive Disclosure refactor calibration
description: When refactoring CLAUDE.md under HumanLayer's instruction-budget framework (extraction to rules/*.md), do not extract always-on safety-net checklists coupled to inline triggers, and prefer prose pointers over hook automation when operational behavior is identical
metadata:
  type: feedback
---

When refactoring `~/.claude/CLAUDE.md` to reduce its instruction count toward the HumanLayer "uniform decay" budget (~`150–200` for thinking models, see [[reference_claude_code_best_practices]]), do **not** propose any of the following:

1. **Extracting always-on safety-net checklists to on-demand `rules/*.md`** even when the instruction-count gain is real. The post-change greps block (CLAUDE.md "Plan & memory discipline", until 2026-09-22) was the canonical example: 6 numbered sub-items coupled to an inline trigger ("After a structural change, verify consistency..."). The failure mode is silent: Claude doesn't know it forgot to grep until the doc/test rots. Always-on cost ~7 instructions counted is acceptable when (a) the content is short, (b) it's tightly coupled to a behavior gate one bullet above. Both conditions hold for safety-net checklists by definition.

2. **Adding a SessionStart/PostToolUse hook that parses `paths:` frontmatter in `rules/*.md`** to auto-load matching files. The harness already does this natively: a rule file auto-loads when an edited or read file matches its `paths:` glob (observed: touching a `.sh` file pulls `rules/shell.md` into context, via its `paths: **/*.sh`). A custom hook would duplicate native behavior and add: (a) script authoring + testing cost, (b) maintenance of glob-matching logic, (c) a silent-failure mode. The `paths:` frontmatter in `rules/python.md`/`shell.md`/`r.md` is therefore load-bearing, not ornamental: it drives the native auto-load. Do not suppress it, and do not write a hook to replicate it.

**Why:** the 2026-05-16 walkthrough on the CLAUDE.md Progressive Disclosure refactor produced 7 findings; 2 (29%) matched these patterns. Pattern 1 came from undervaluing the silent-failure cost of forgotten checklists. Pattern 2 came from misreading the `paths:` frontmatter as dead (unread by any *custom* hook) when the harness's native rules loader consumes it: it is load-bearing, and the right move is to leave it alone rather than either "fix" it with a hook or suppress it. Both rejections turned on the same principle: instruction count is a budget, not a goal. Gains that come at the cost of compliance safety or maintenance burden are net negative regardless of the arithmetic.

**How to apply:** in any future CLAUDE.md refactor under the instruction-budget framework, before proposing an extraction or automation, ask:
- For extraction: "If Claude never loads this rules file, does the always-on behavior still hold?" If no → keep inline.
- For automation: "Does the same behavior already work via prose pointer or Claude's default reading?" If yes → do not automate.

Since 2026-09-22 the post-change greps live in the commit verifier (`skills/commit/agents/verifier.md`), which the `Stop` hook `commit-gate.sh` makes mandatory before any commit proposal, while `CLAUDE.md` keeps the inline trigger (grep for the old name after a structural change). That move passes the extraction test above: the destination is enforced, not loaded on demand. Rules that apply only while editing one kind of file (`rules/code.md`, `rules/skill.md`) pass it too, since the file they wait for is the one that loads them.

The automation test above targets hand-written hooks, whose costs it names (script, tests, glob logic, silent failure). A native `permissions.deny` entry carries none of them, so the 2026-09-22 `Edit(...)` denies on the plugin caches and on `NOTES.md` / `TODO.md` / `CALENDRIER.md` stand even though the prose was already respected: one line of configuration makes a hard rule deterministic and lets its prose shrink.

Real refactor wins still apply: extracting context-specific content (secrets handling, showboat, env reference) that doesn't gate ongoing behavior, splitting bundled multi-rule bullets into atomic rules **when** there's no consolidation alternative, pruning genuinely dead sections.

Related: [[feedback_review_severity_claude_config]] (review calibration for CLAUDE.md *content* audits), [[feedback_review_severity_claude_rules]] (review calibration for `rules/*.md` files), [[reference_claude_code_best_practices]] (HumanLayer mechanism + budget figures).
