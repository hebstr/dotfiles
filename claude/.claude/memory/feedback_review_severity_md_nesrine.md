---
name: Review severity for md-nesrine render journal
description: "Calibrate code reviews of the md-nesrine render journal (lib/log_helpers.R, logs/render.jsonl, auto_build() in lib/out_helpers.R): two recurring false-positive shapes from the 2026-09-17 walkthrough"
metadata:
  type: feedback
---

Project `~/Documents/services/md-nesrine`, render journal committed in v5.3.2. Supplements [[feedback_review_severity_personal]] and [[feedback_review_severity_stat_reports_fr]].

**Do not ask for a journal line on a failed render.** The journal is one line per pass of a render that completed. `withCallingHandlers()` in `auto_build()` does not muffle warnings, so they and the terminating error already reach the render output the author redirects to a file; a failure line would record SVG hashes of a half-rewritten `output/` as if coherent, which corrupts the cross-render comparison the `svg` field exists for. `.claude/NOTE-LOGS.md` applies the same stance elsewhere ("un défaut doit faire échouer le rendu, pas produire une ligne de journal").

**Do not ask for a field identifying the commit that holds a render's outputs.** `logs/render.jsonl` is tracked, append-only and committed with the outputs it describes, so `git blame logs/render.jsonl` already maps each line to that commit (verified 2026-09-17: both lines of the validation render point at `fd327f8`, v5.3.2).

**Why:** both were filed as Required/Suggestion on 2026-09-17 and rejected with L1 and L2 concurring on the first; the mechanism each describes is real, the consumer is absent.

**How to apply:** before filing a missing-field or missing-line finding on the journal, name who reads it and check whether git, the redirected render log or an existing field already answers. A hypothetical representation drift (`rlang::hash()` on tibbles) was also measured absent the same day: `gs` and `local` reads hash identically on all three tabs.
