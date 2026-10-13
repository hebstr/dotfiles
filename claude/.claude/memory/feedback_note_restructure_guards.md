---
name: Two guards when restructuring a line-structured note
description: An Edit whose old_string ends at a line's end and whose new_string is empty also eats that line's newline and merges it with the next, measured; and a whole-file rewrite of a note needs a snapshot plus a character-level comparison of the passages meant to survive
metadata:
  type: feedback
---

Both apply to a file whose structure is carried by its lines: a `PLAN.md` of one-line items, a `DEFERRED.md` table, an index, a checklist.

**An empty replacement at a line's end consumes the newline.** Measured twice on 2026-10-14, in the scratchpad, on a three-line list: an `Edit` whose `old_string` ends exactly at the end of line 1 and whose `new_string` is `""` left `- [ ] item one- [ ] item two.` and a two-line file. The same edit with a one-character replacement (`.`) kept the three lines intact. So the trigger is the empty replacement, not the position. When cutting a trailing clause, either keep one character of the sentence in the replacement, or re-split afterwards. Incident: two items of `claude-code-plugins/.claude/PLAN.md` merged this way during the prune pass of 2026-10-13/14 and the diff read as a plausible deletion.

**Count the structure after any such edit**, because the diff does not show it: `rg -c '^- \['` for a list, a column count for a table. That count is what caught the merge above, after the character-level diff had not.

**A whole-file rewrite needs a snapshot and a comparison of the survivors.** Rewriting a pruned note in one `Write` is several times cheaper than dozens of exact-match edits, and `Edit`'s loud failure on a mismatch is exactly what it gives up: a passage meant to survive can come back altered with nothing failing. Copy the file aside first, then after the write compare the kept passages character by character and print which ones are byte-identical, rather than trusting a reread.

**Why:** both failures are silent and both land in a file whose readers are future sessions, where a merged item or a drifted sentence is read as the record rather than as damage.

**How to apply:** on a note whose lines are its items, prefer a non-empty replacement, verify with a structure count after the edit, and when the pass rewrites the whole file, keep the snapshot until the survivor comparison has run. Related: [[feedback_edit_tool_unicode_escape]], [[feedback_line_number_cross_refs]].
