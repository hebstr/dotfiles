---
name: audit:walkthrough specific feedback
description: Triage table format and review severity calibration for personal scripts in audit:walkthrough
type: feedback
---

**Triage table format:** In Step 1b.2 (batch triage), present manual findings in a table — same format as auto-fix findings — with columns: #, Finding, File, Reason for manual review.

**Why:** User requested table format during live walkthrough; bullet list was too hard to scan.

**How to apply:** Both auto-fix and manual buckets get tables in the triage summary.

---

**Review severity for personal scripts:** For scripts in `~/.local/bin/` or `~/scripts/`, downgrade locale/portability concerns to Noted unless the script is intended for distribution.

**Why:** Reviewer flagged `awk '/désactivé|disabled/'` as fragile. On a personal machine with stable French locale + English fallback, this is pragmatic and correct.

**How to apply:** Personal scripts = lenient on locale patterns. Portability concerns only escalate for shared/distributed scripts.
