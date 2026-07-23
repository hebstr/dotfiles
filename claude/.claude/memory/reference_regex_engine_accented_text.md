---
name: Regex engine choice for big alternations over accented text
description: ICU backtracking vs automaton (re2) on large regex alternations; RE2 \b is ASCII-only and breaks on accented words; fold with Latin-ASCII + re2_locate_all + two offset maps + slice-original recovers accents AND ligatures ~100x faster. Surface on R/Python text-matching perf over French/accented corpora.
metadata:
  type: reference
---

When a pipeline matches text against a **large regex alternation** (tens to hundreds of `|`-joined tokens), the engine choice dominates wall-clock, and the naive conclusions are wrong twice over. Measured on edstr `avc` (189-token alternation, 2026-06-06, revised 2026-07-22).

**1. ICU backtracking explodes; an automaton is linear.** stringr/stringi use ICU (backtracking). At identical work (no `\b`, same 13595 matches): ICU 197s vs re2 (Google RE2 automaton) 0.32s = **615x**. The lever is the engine, not Unicode. Do not assume "it's just R being slow" or "drop Unicode to go fast".

**2. RE2's `\b` is ASCII-only.** re2 (R package) ran the same pattern in 0.22s but was only 98% match-equivalent: it misses French accented words at word edges (méningé, thrombolysé, oculomotricité, élocution). Cause isolated: `\b(m[eéèêëœ]n[iîï]ng[eéèêëœ])\b` matches "méningé" in ICU but returns NA in re2, because RE2 treats `é` as a non-word char, so the trailing `\b` after `é` never forms. RE2 has **no Unicode word boundary and no lookaround**, so no in-engine fix. Rust's `regex` crate has Unicode `\b` (correct) but the Unicode boundary forces its slow engine (40s ≈ ICU). So no off-the-shelf engine is simultaneously fast + Unicode-correct *with `\b` in the pattern*.

**3. The fix: move the boundary out of the engine by folding the source with `Latin-ASCII`.**
- Fold with `stri_trans_general(x, "Latin-ASCII")`, **the same transliteration the tokenisation uses**. That identity is the point: a matched token and the folded source are the same string by construction, so nothing has to bridge a spelling gap, and ASCII `\b` lands on real word edges.
- Match with `re2::re2_locate_all(folded, pattern)` in **default** mode (NOT `longest_match=TRUE`, which over-matches across punctuation, e.g. "anevrismale.Axes").
- `re2_locate_all` returns 1-based inclusive **byte** offsets. Carry them back through **two** maps, byte → folded char → original char, then slice the **original** to recover the true surface form (accents, ligatures, case). Both maps are the same expression, `findInterval(pos - 1L, cumsum(width)) + 1L`, which is why one handles a zero-width unit and a match ending mid-expansion. Must stay vectorized: a naive loop costs ~10s.
- `Latin-ASCII` never deletes a character (verified over all of Unicode), so a document whose folded length is unchanged mapped 1:1 and can skip the second map entirely.

**4. Do NOT use the 1:1 `NFD; Mn Remove; NFC` fold.** It is the obvious choice (length-preserving, trivial offsets) and it was used first, then abandoned 2026-07-22: Unicode gives `œ`/`æ` **no decomposition at all** (unlike the typographic `ﬁ`), so a diacritic-stripping fold silently drops every ligature. Those terms then match at the token level but can never be confirmed against the source, and are dropped as mismatches. `œ` occurs in 22.8% of `avc` docs (1801/7883): cœur, œdème, œsophage, cœlioscopie. Cost of the correct fold: `Latin-ASCII` is **3.3x slower** than the NFD fold (10.3s vs 3.1s on 49 MB), about +14% end to end. Accepted deliberately, do not re-litigate.

**5. The offset map assumes `Latin-ASCII` is context free** (transliterating char by char equals transliterating whole). The per-document guard is `sum(per-char widths) == nchar(folded, "chars")`, falling back to ICU on the original for that document. Note this is necessary, not sufficient: a context-dependent transliteration preserving total length would pass it.

**Decision for edstr:** re2 suffices, Rust ruled out (no cargo toolchain needed). Shipped; the ligature fix is commit `69f384c`, full measurements and traps in the project's `.claude/PERF.md`.

General takeaway beyond edstr: for big-alternation matching over accented corpora, benchmark an automaton engine on identical work before blaming the language, and reconcile the Unicode `\b` gap with a fold rather than abandoning Unicode correctness. Pick the fold that matches your tokenisation, not the one with the easiest arithmetic. Relates to [[reference_modern_r_model_tooling]] and [[feedback_review_severity_edstr]].
