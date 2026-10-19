---
name: reference_edstr_extract_chunk_budget
description: Sizing an edstr extraction chunk, the budget being characters and columns rather than a document count and a soft bound whose overshoot warning misstates its cause, and what calling edstr_extract(chunk =) needs since the mechanism moved into the package
metadata:
  type: reference
---

An `edstr_extract()` chunk is sized by the text volume it carries, not by its document count: `unnest_tokens()` expands the text into tens of millions of token rows and replicates every column carried alongside it.
So `chunk = 15000`, the value `eds-prise` and `crpv-ciclo` both run, is a proxy for roughly 310 M characters per chunk under corpora averaging about 20,600 characters per document, measured 2026-10-19 on both clean parquets (20,580 over 109,957 documents in ciclo, 20,817 over 90,907 in prise, 1.2 percent apart).

**15,000 is a sound default across this user's EDS projects, because CHU document length barely varies and the value was set with a factor-2 margin.**
Three corpora measured 2026-10-19, cleaned text where available and raw where not: 20,580 characters per document in ciclo and 20,817 in prise (both cleaned), 19,100 raw in `eds-avc/collect/data/sej_m=2023-01/`, which cleaning would bring near 16,500, ciclo having lost 13.5 percent of its characters between import and clean. A spread of about 25 percent against a margin of 2, so the corpus is not what decides.
Re-derive the value, by `avg(length(<text column>))` on the clean parquet, only when the mean passes roughly 30,000 characters per document, when the machine changes, or when the documents are not hospital reports (full-text PDFs, transcripts).

The memory model behind it, measured in `eds-prise/.claude/DESIGN-CORPUS.md` on a 15 GB machine with three columns and `ngram_max = 3`: 0.27 GB per 1,000 documents plus a 1.4 GB base, linear to within 0.25 GB over 15,000 to 30,000 documents, with the feasibility wall near 30,000 to 35,000. Chunking is the condition of execution rather than an optimisation.

**The column count is the second lever and it is the brutal one.** Three columns and eleven are indistinguishable, about 5.8 GB per chunk; the 23-column composed table reaches 8.6 GB. So hand the extractor its keys and its text, and rejoin the metadata after the recombination, which is what `.decore()` does in `eds-prise`.

**`chunk` is a soft bound: the planner splits on `ceiling(cumsum(doc) / chunk)`, so a chunk exceeds the budget by at most the group straddling its boundary.**
Measured 2026-10-19 on ciclo, two of eight chunks over 15,000 (15,233 and 15,015) with no group above 641 documents over 3,073 groups.
edstr warns about the overshoot and names a group larger than the budget as the cause, which is the other way it happens and not this one; read the group-size distribution before believing the message, and the model's factor-2 margin absorbs an overshoot of one group.

Two traps that raise nothing. `ngram_max` is not where the peak lives: reading and filtering the parquet is about 73 percent of it, so dropping to unigrams saves under 10 percent. And a per-chunk `BETWEEN` on a group column only reads one range while the clean parquet stays sorted by that column; a lost sort makes every child read the whole corpus in silence, which `edstr_extract(chunk = )` now warns about from the per-group `file_row_number` range.

**The mechanism lives in edstr since 2026-10-19**, as `edstr_extract(chunk = )`: it owns the plan, the `callr` children, the recombination, the global `summary`, the three output files, the partition assertions and the removal of the per-chunk directories, and `chunk = TRUE` takes the 15,000 default.
No project hand-rolls a chunked run any more: `crpv-ciclo` is migrated, and `eds-prise`'s `extract/prise_extract-run.R` is the last site.
Its migration needs three things, none of them automatic: `id = "id_doc"` passed explicitly, since the `(id, group, text)` projection leaves nothing to auto-detect from; `chunk_sort = "sej_date_entree"` for the date order its `.decore()` applies; and a check that the clean parquet carries the same metadata columns as `extract_data_import()`, which is where that helper reads them today.
Design record, the eight assertions and the measurements: `~/Documents/packages/R-edstr/.claude/CHUNK.md`. The decision and its rejected alternatives: `crpv-ciclo/.claude/PLAN.md`, step P.

Related: [[reference_nanoparquet_col_select]], [[feedback_benchmark_power_state]].
