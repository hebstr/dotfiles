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

**Why:** three adversarial rounds on `scan-reviewers.py` over two days returned a near-constant finding count with no convergence. Several accepted fixes of the last round triggered their failure mode on none of the installed `SKILL.md` descriptions, the cross-model L1 said so, and each fix added surface for the next round, including one that only moved a crash (`UnicodeDecodeError`) and one regex that was wrong on first write. A heuristic parser always has one more edge case, so a reviewer asked to find defects never runs dry; the loop only ends on a criterion like this one. The user called the stop on 2026-09-15.

**The two-gate design of `scan-reviewers.py` is load-bearing: never drop the name gate to recover one reviewer.** Relaxing it to let `DESC_PAT` decide alone was measured to quadruple the candidate set and admit a dozen non-reviewers. What resolved the `audit:sweep` miss instead, and what the code now carries, is a widened `CODE_SIGNALS` plus an escape hatch in the `--reviewer` validation that accepts a value absent from the scan when it resolves to a readable `SKILL.md`.

**How to apply:** before accepting a finding on heuristic code, run the claimed input against the real corpus and state the count. Zero occurrences and no doc contradiction and no crash means NOTED. Reopen the code only on a real incident (a missing or spurious result in actual use). This does not relax the excluded categories of the walkthrough (security, data integrity, privacy), which stay out of calibration whatever the corpus says. See [[feedback_audit_walkthrough]].
