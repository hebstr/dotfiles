---
name: reference_edstr_extract_row_order
description: edstr orders its extract output by (group, id), so re-extracting or sorting the import never changes the annotation row order
metadata:
  type: reference
---

`.extract_results()` in edstr closes on `arrange(pick(all_of(c(group, id))))` then `mutate(n = row_number())`, so the extract and note frames come out ordered by `(group, id)` (typically `id_pat`, `id_doc`) whatever the row order of the clean parquet they were read from.

Three consequences, measured 2026-10-19 on crpv-ciclo (268 retained documents, 115 patients):

- Sorting the import parquet does not change the annotation input's row order, only the clean parquet's physical layout and the contiguity of a chunked extract's `BETWEEN` ranges.
- A chunked extract preserves that order as long as the chunk ranges are ordered and disjoint, the recombination being a `list_rbind()` in chunk order.
- The annotation app's `MISALIGNED` guard, `check_note_aligned()` comparing the two `id_doc` columns, therefore does not fire after a plain re-extract of the same corpus, against the intuition that a regenerated input must reshuffle rows. An output parquet with no note filled is rebuilt from the input by the app itself, so only an annotated one has to be moved aside before a rebuild.

The `n` column is a per-chunk counter until the combine renumbers it, which is why a chunked pipeline asserts its uniqueness.
