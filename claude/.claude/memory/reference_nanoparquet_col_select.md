---
name: nanoparquet col_select corrupts NA-bearing columns
description: nanoparquet::read_parquet(col_select = ) silently drops NAs and shifts values up within a row group; read the full file then dplyr::select instead. Check this first when a parquet column comes back with zero missing values, or when counts derived from a parquet disagree with a previously recorded figure
metadata:
  type: reference
---

Observed on nanoparquet **0.5.1**, R 4.6, in `~/Documents/des/eds/eds-prise` (2026-08-05).

`read_parquet(file, col_select = c("id_pat", "pat_date_deces_insee"))` returned `pat_date_deces_insee` with **0 NA** where the same column read without a narrow `col_select` has **122 955 NA** out of 164 835 rows. The full-read figure was the correct one: it reproduced a patient-level count (8 127 deaths) recorded independently weeks earlier.

**Failure shape.** The corruption starts at exactly the first NA row of the affected column, and values below it are shifted up by one rank per preceding NA. It is bounded by the row group, so the damage stays inside each `num_rows_per_row_group` block (1000 here) rather than cascading through the file. On a column with 12 NAs spread over 6 row groups, 1 105 of 164 835 rows came back wrong.

**Only columns that actually contain NA are affected.** Every NA-free column (`id_sej`, `id_pat`, `pat_sexe`, `pat_age`, `sej_date_entree`, logical indicator columns) was verified `identical()` between the two reads. That is what makes the bug dangerous: most `col_select` calls in a codebase are correct, so the pattern looks safe until one call hits a sparse column.

**Not every `col_select` triggers it.** A selection of 21 of the file's 22 columns (dropping only the large text column) returned the correct NAs. Narrow selections did not. The mechanism was not pinned down further; treat the safe/unsafe boundary as unknown rather than as "wide selections are fine".

**Rule adopted by the user (2026-08-05): never use the `col_select` argument, read the file and `dplyr::select()` as usual.** Applies to all projects.

Cost to budget for when converting: the projection pushdown is what `col_select` was buying. In eds-prise, `total_prise_import.parquet` is 743 MB on disk and 3 GB in memory (11 s), because it carries a full-text column. Converting what was then `scripts/_setup.R` (split on 2026-08-23 into `setup.R` for session setup and `scripts/_common.R` for shared output prep, so the name resolves only through `0ad59e5`) meant reading once into a dot-prefixed intermediate, deriving every frame from it by `select()`, then `rm()` on the intermediate; that file went to 15.3 s. Reading the same file once per consumer script would have tripled that, so a shared single read belongs at the session-setup entry point, today `df_init <- read_collect()` in `setup.R`, under the project's own placement rule (see [[project_md_nesrine_render_pitfalls]] for the hebstr-stack conventions this sits in). The rule is stated, not enforced: `scripts/_mesure_cohorte.R` reads the same import parquet a second time, after `_setup.R` has already `rm()`'d the shared intermediate, so a render pays that read twice.

**Impact found in eds-prise**: `df_pat_cp` read `pat_cp` (12 NAs) through `col_select`, so 24 of the 7 034 study patients carried another patient's postal code, moving the Table 1 territory counts from 5 772 / 950 / 312 to 5 767 / 954 / 313.
