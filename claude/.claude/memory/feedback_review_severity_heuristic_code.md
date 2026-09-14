---
name: Review severity for heuristic code
description: "Stop rule for adversarial reviews of heuristic code (free-text parsers, discovery scans, classifiers of descriptions): accept only findings reproduced on the real corpus, contradicting official docs, or crashing; hypothetical edge cases are NOTED"
metadata:
  type: feedback
---

When reviewing heuristic code, meaning code that interprets free text or loosely specified inputs rather than computing a determinate result (sentence splitters, frontmatter readers, skill or plugin discovery scans, keyword classifiers), a finding is ACCEPTED only if at least one holds:

- it reproduces on the real corpus the code runs against (e.g. the installed `SKILL.md` descriptions for `audit/walkthrough/scripts/scan-reviewers.py`), measured, not assumed;
- it contradicts the official documentation of the format being read (fetched and cited by line);
- it crashes the code or aborts its output on an input shape the source can actually produce.

A mechanically real edge case with zero occurrences in the corpus is NOTED, not fixed, even when the fix is short.

**Why:** three adversarial rounds on `scan-reviewers.py` in two days (2026-09-14 and 2026-09-15) returned 15, 14 and 13 findings with 15, 11 and 11 accepted: no convergence. In the third round, 4 of the 11 accepted fixes (unbalanced quotes, curly quotes, lowercase gluing, YAML indentation indicators) triggered their failure mode on none of the 336 `SKILL.md` descriptions under `~/.claude/plugins/cache/` and `~/.claude/skills/` (measured), the cross-model L1 said so, and each fix added surface for the next round, including one fix that only moved a crash (`UnicodeDecodeError`) and one regex that was wrong on first write. A heuristic parser always has one more edge case, so a reviewer asked to find defects never runs dry; the loop only ends on a criterion like this one. The user called the stop on 2026-09-15.

**How to apply:** before accepting a finding on heuristic code, run the claimed input against the real corpus and state the count. Zero occurrences and no doc contradiction and no crash means NOTED. Reopen the code only on a real incident (a missing or spurious result in actual use). This does not relax the excluded categories of the walkthrough (security, data integrity, privacy), which stay out of calibration whatever the corpus says. See [[feedback_audit_walkthrough]].
