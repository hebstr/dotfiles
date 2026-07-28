---
name: audit:walkthrough specific feedback
description: audit:walkthrough triage table format, severity calibration for personal scripts, the calibration loader contract (redirect-follow + scoped-filename glob, and its cwd-vs-target failure mode), and the measured blindspot bucket accuracy on Claude-instruction targets (agreed reliable, external-only least reliable, inverting the skill's own framing)
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

Caveat observed 2026-07-28: on a walkthrough launched from an unrelated project directory (cwd `eds-avc`, target `~/dotfiles`), the harness memory dir did not exist at all, so the redirect-stub path found nothing. Calibration had to be read straight from the canonical store. Walkthrough-only mode derives the project root from the cwd, which also misfiles `DEFERRED.md` when the findings concern another repo; write it to the repo the findings are about, not the cwd's.

---

**Blindspot bucket accuracy is the inverse of what the skill assumes.** `audit:blindspot` frames `external-only` findings as Claude's blindspots, to review "with particular care", and routes mandatory L2 at `claude-only`. Measured on `rules/*.md` and `CLAUDE.md` targets, the ranking runs the other way: findings both models flagged are near-perfect, and the external model's solo findings are the least reliable.

**Why:** two independent runs now. The 2026-06-03 blindspot on `CLAUDE.md` (Gemini external) had ~71% of 28 findings rejected, the Gemini pass producing mostly pattern-7 false positives. The 2026-07-28 blindspot on `rules/python.md` (Gemini external) walked 24 findings with rejection rates of **0%** on the 6 `agreed`, **36%** on the 11 `claude-only`, and **71%** on the 7 `external-only`. One external-only finding was outright backwards (proposing `hasattr` over `from pkg import fn`, when the from-import form is the more robust of the two). The plausible cause is that an external model reading a Claude-instruction file cannot see the house conventions, the always-loaded `CLAUDE.md`, or the machine's actual toolchain, so it flags calibrated choices as gaps.

**How to apply:** on Claude-instruction targets (`CLAUDE.md`, `rules/*.md`, `SKILL.md`), treat `agreed` as high-confidence and worth fixing, and treat `external-only` as the bucket needing the most verification before acceptance, not the least. Verify every external-only claim against the file, the siblings and the live tool before accepting it. This does not generalize to application code, where the external model has no such handicap; it is specific to artifacts whose correctness depends on local convention. See [[feedback_review_severity_claude_rules]] and [[feedback_review_severity_claude_md_content]].
