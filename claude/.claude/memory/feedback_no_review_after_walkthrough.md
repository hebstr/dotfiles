---
name: No adversarial review on top of a completed walkthrough
description: Once a change has gone through a blindspot or walkthrough whose fixes were evaluated, do not propose another adversarial review of those fixes or of memory/rule edits they caused; list only the real remaining actions
metadata:
  type: feedback
---

When a change has already been through an adversarial review and its walkthrough (fixes applied, final evaluate run), do not end the report by proposing another `/audit:blindspot` or `/audit:walkthrough` on the result, including on a memory or rule file edited as one of those fixes.

**Why:** on 2026-09-15, after a blindspot and a full walkthrough of `orchestrator.md` (evaluate APPROVED 0.86, commits pushed), Claude proposed yet another blindspot on a one-line scope widening of `feedback_review_severity_skill_audits.md`. The user answered: "tu me propose ENCORE de la revue adverse. on tourne en rond. quels sont les vrais points restants ?" The CLAUDE.md "propose /audit:blindspot after substantive memory changes" trigger does not re-arm for edits produced inside a review cycle; each such proposal restarts the loop that [[feedback_review_severity_heuristic_code]] exists to stop.

**How to apply:** at the end of a review cycle, list only concrete remaining actions (restart, commit, a pending live validation that happens on its own) and state plainly that the review side is closed. Propose a new adversarial pass only on a change made outside that cycle, or when the user asks. See [[feedback_audit_walkthrough]].
