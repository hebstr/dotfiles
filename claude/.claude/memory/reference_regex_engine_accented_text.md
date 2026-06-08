---
name: Regex engine choice for big alternations over accented text
description: ICU backtracking vs automaton (re2) on large regex alternations; RE2 \b is ASCII-only and breaks on accented words; 1:1 NFD fold + re2_locate_all + byte→char + slice-original recovers ICU-identical output ~100x faster. Surface on R/Python text-matching perf over French/accented corpora.
metadata:
  type: reference
---

When a pipeline matches text against a **large regex alternation** (tens to hundreds of `|`-joined tokens), the engine choice dominates wall-clock, and the naive conclusions are wrong twice over. Measured on edstr `avc` (1801 docs, 189-token alternation, 2026-06-06):

**1. ICU backtracking explodes; an automaton is linear.** stringr/stringi use ICU (backtracking). At identical work (no `\b`, same 13595 matches): ICU 197s vs re2 (Google RE2 automaton) 0.32s = **615x**. The lever is the engine, not Unicode. Do not assume "it's just R being slow" or "drop Unicode to go fast".

**2. RE2's `\b` is ASCII-only.** re2 (R package) ran the same pattern in 0.22s but was only 98% match-equivalent: it misses French accented words at word edges (méningé, thrombolysé, oculomotricité, élocution). Cause isolated: `\b(m[eéèêëœ]n[iîï]ng[eéèêëœ])\b` matches "méningé" in ICU but returns NA in re2, because RE2 treats `é` as a non-word char, so the trailing `\b` after `é` never forms. RE2 has **no Unicode word boundary and no lookaround**, so no in-engine fix. Rust's `regex` crate has Unicode `\b` (correct, 5648 = ICU) but the Unicode boundary forces its slow engine (40s ≈ ICU). So no off-the-shelf engine is simultaneously fast + Unicode-correct *with `\b` in the pattern*.

**3. The fix: move the boundary out of the engine via a 1:1 ASCII fold.** Proven 100% ICU-identical output on the full corpus at ~100x:
- Fold text with `stri_trans_general(x, "NFD; [:Nonspacing Mark:] Remove; NFC")` — 1:1 per character (é→e). Do NOT use `"Latin-ASCII"`: it expands ligatures (œ→oe, æ→ae), breaking offset 1:1 (only 48.6% preserved vs 99.8% for NFD-strip).
- Match with `re2::re2_locate_all(folded, pattern)` in **default** mode (NOT `longest_match=TRUE`, which over-matches across punctuation, e.g. "anevrismale.Axes"). `\b` is now correct because all letters are ASCII.
- `re2_locate_all` returns **byte** offsets (cols `begin`/`end`, 1-based). Folded text is not pure ASCII (guillemets/punctuation survive), so byte ≠ char: map byte→char with `cumsum(nchar(per-char, type="bytes"))` + `findInterval`, then `str_sub(original, char_begin, char_end)` to recover the **accented** surface form from the untouched original.
- Result: 1801/1801 docs identical, 5648 matches. Handle the ~4 NFD non-1:1 docs (equivalence held via findInterval, but confirm). The byte→char loop in plain R is the slow part (~10s); the re2 core is 0.32s, so optimize the mapping (vectorize / C) for the full win.

**Decision for edstr:** re2 suffices, Rust ruled out (re2 reaches 100% equivalence without a cargo toolchain). Integration is [[project_review_workflow_backlog]]-style scoped work, tracked as step 8 in `.claude/PLAN.md`. The realized R-only gains (step 5 K-scan removal, step 6 discarded str_view) already cut 160s→131s before any engine change.

General takeaway beyond edstr: for big-alternation matching over accented corpora, benchmark an automaton engine on identical work before blaming the language, and reconcile the Unicode `\b` gap with a 1:1 fold rather than abandoning Unicode correctness. Relates to [[reference_modern_r_model_tooling]] (tool-selection reference, surface on request).
