---
name: audit:walkthrough specific feedback
description: audit:walkthrough triage table format, severity calibration for personal scripts, and the calibration loader contract (redirect-follow + scoped-filename glob)
metadata:
  type: feedback
---

**Triage table format:** In Step 1b.2 (batch triage), present manual findings in a table (same format as auto-fix findings) with columns: #, Finding, File, Reason for manual review.

**Why:** User requested table format during live walkthrough; bullet list was too hard to scan.

**How to apply:** Both auto-fix and manual buckets get tables in the triage summary.

---

**Review severity for personal scripts:** For scripts in `~/.local/bin/` or `~/scripts/`, downgrade locale/portability concerns to Noted unless the script is intended for distribution.

**Why:** Reviewer flagged `awk '/désactivé|disabled/'` as fragile. On a personal machine with stable French locale + English fallback, this is pragmatic and correct.

**How to apply:** Personal scripts = lenient on locale patterns. Portability concerns only escalate for shared/distributed scripts.

---

**Calibration loader contract (path + filename):** Both `audit:walkthrough` (orchestrator + walkthrough-only) and `audit:sweep` (Phase 0) load prior calibration from the harness per-project memory dir `~/.claude/projects/<encoded-path>/memory/`. Two facts break this for the memory-override setup unless the loader compensates, now handled in `audit/walkthrough/agents/orchestrator.md` "Load target project memories" and `audit/sweep/SKILL.md` §"Calibration memory": (1) memory lives in the canonical store `~/.claude/memory/`, not the harness path, so the loader follows a `Canonical index: <path>` line in the harness `MEMORY.md` redirect stub; (2) severity files are scope-suffixed (`feedback_review_severity_<scope>.md`), so the loader globs `feedback_review_severity*.md`, not the bare name. Walkthrough-only mode runs the shared loader once before the Step 2 loop, gated on an identifiable project root.

**Why:** Without these, prior calibration was silently inert for this user (wrong dir + exact-name miss), so validated findings got re-litigated. Discovered empirically while attacking the DEFERRED point on walkthrough-only calibration; the same bug existed in `audit:sweep` and was fixed in the same pass.

**How to apply:** The redirect-follow depends on the stub keeping the exact `Canonical index:` marker. If the harness `MEMORY.md` stub format ever changes, update both the stub and the loader's marker parse, or calibration loading breaks with no error. See [[feedback_review_workflow]].
