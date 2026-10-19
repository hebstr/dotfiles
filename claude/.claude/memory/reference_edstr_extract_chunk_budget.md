---
name: reference_edstr_extract_chunk_budget
description: Sizing an edstr extraction chunk, the budget being characters and columns rather than a document count, and where the chunking mechanism itself belongs
metadata:
  type: reference
---

An `edstr_extract()` chunk is sized by the text volume it carries, not by its document count: `unnest_tokens()` expands the text into tens of millions of token rows and replicates every column carried alongside it.
So `.chunk_doc_max <- 15000`, the value `eds-prise` and `crpv-ciclo` both run, is a proxy for roughly 310 M characters per chunk under corpora averaging about 20,600 characters per document, measured 2026-10-19 on both clean parquets (20,580 over 109,957 documents in ciclo, 20,817 over 90,907 in prise, 1.2 percent apart).

**15,000 is a sound default across this user's EDS projects, because CHU document length barely varies and the value was set with a factor-2 margin.**
Three corpora measured 2026-10-19, cleaned text where available and raw where not: 20,580 characters per document in ciclo and 20,817 in prise (both cleaned), 19,100 raw in `eds-avc/collect/data/sej_m=2023-01/`, which cleaning would bring near 16,500, ciclo having lost 13.5 percent of its characters between import and clean. A spread of about 25 percent against a margin of 2, so the corpus is not what decides.
Re-derive the value, by `avg(length(<text column>))` on the clean parquet, only when the mean passes roughly 30,000 characters per document, when the machine changes, or when the documents are not hospital reports (full-text PDFs, transcripts).

The memory model behind it, measured in `eds-prise/.claude/DESIGN-CORPUS.md` on a 15 GB machine with three columns and `ngram_max = 3`: 0.27 GB per 1,000 documents plus a 1.4 GB base, linear to within 0.25 GB over 15,000 to 30,000 documents, with the feasibility wall near 30,000 to 35,000. Chunking is the condition of execution rather than an optimisation.

**The column count is the second lever and it is the brutal one.** Three columns and eleven are indistinguishable, about 5.8 GB per chunk; the 23-column composed table reaches 8.6 GB. So hand the extractor its keys and its text, and rejoin the metadata after the recombination, which is what `.decore()` does in `eds-prise`.

Two traps that raise nothing. `ngram_max` is not where the peak lives: reading and filtering the parquet is about 73 percent of it, so dropping to unigrams saves under 10 percent. And a per-chunk `BETWEEN` on a group column only reads one range while the clean parquet stays sorted by that column; a lost sort makes every child read the whole corpus in silence, which is what the partition assertion in each project's `*_extract-run.R` exists to catch.

**The mechanism itself is moving into edstr, decided 2026-10-19 and not yet implemented**, as a `chunk` argument of `edstr_extract()` owning the plan, the `callr` children, the recombination, the global `summary`, the three output files, the partition assertion and the removal of the per-chunk directories.
So a project script that chunks is transitional: do not design a new one, and do not consolidate the existing two in place.
The decision, its rejected alternatives and the probe that recomputes a single-pass `summary` from the chunk rds are in `crpv-ciclo/.claude/PLAN.md`, step P.

Related: [[reference_nanoparquet_col_select]], [[feedback_benchmark_power_state]].
