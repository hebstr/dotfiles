---
name: reference_snds_variable_traps
description: "SNDS declaration traps verified on documentation-snds.health-data-hub.fr: ALD read by diagnosis not by number, CIP derived from ATC, BEN_CMU_TOP zeroed under ALD, AME countable only as activity, FDep tables, and the 2015 all-regime exhaustivity threshold"
metadata:
  type: reference
---

Verified 2026-10-02 on the official SNDS documentation, while declaring the extraction of the national arm of eds-prise, whose project memory lives in that repository's own `.claude/memory/`. Each item is a place where the obvious variable is the wrong one.

- **An ALD is selected by its diagnosis, never by its number.** `IR_IMB_R` carries `IMB_ALD_NUM`, which the documentation calls poorly populated and which is not corrected when the regulation changes. The recommended route rebuilds the ALD code from `MED_MTF_COD` (ICD-10 on 3 characters) joined to the `IR_CIM_V` referential on `cim_cod`, which carries `ald_030_cod`. Companion variables: `IMB_ETM_NAT` (41 list, 43 off-list, 45 polypathology) and the dates `IMB_ALD_DTD` / `IMB_ALD_DTF`. So a declaration lists ICD-10 codes, not ALD numbers.
- **A CIP list is derived from an ATC class, never typed.** `IR_PHA_R` maps CIP to ATC through `PHA_ATC_C07`; `ER_PHA_F` carries `PHA_PRS_C13` (CIP13) and `PHA_PRS_IDE` (CIP7). What ATC cannot express is the galenic form, so restricting to injectables still needs a published speciality list.
- **`BEN_CMU_TOP` of `ER_PRS_F` is forced to 0 when the benefit is liquidated under an ALD**, so it under-counts exactly in a comorbid population, and it only sees consumers. The exhaustive route is `IR_ORC_R` with `BEN_CTA_TYP` = 89.
- **AME beneficiaries cannot be counted as people, only as activity**: their NIR is often provisional, so longitudinal follow-up fails. Identified by `RGM_COD` in (95, 96, 652) or `BEN_CMU_CAT` = 5 in `ER_PRS_F`; not applicable in Mayotte.
- **The deprivation index is in the base**, tables `DEFA_UU2009` / `DEFA_UU2013` / `DEFA_UU2015` (library `CONSOPAT`), raw index `FDEPaa`, quintiles `QUINTILE_COM` and `QUINTILE_POP`, joined by `depcom`, the concatenation of `BEN_RES_DPT` and `BEN_RES_COM` of `IR_BEN_R`. A precomputed `QUINT_DEFA` exists in `EXTRACTION_PATIENTSaaaa`. It characterises the commune, not the patient, and the documentation warns against it on large heterogeneous communes.
- **2015 is the depth that matters, not the first year present.** The documentation states that 2015 is the year from which all social security regimes report sufficiently exhaustively; the DCIR goes back to 2006 for the régime général alone, and `IR_IMB_R` starts 2005 for the RG, 2014 for the MSA and 2016 for the RSI. Years before 2015 are usable in exclusion-only lookback, where incompleteness never includes wrongly.
- **NGAP acts are not documented officially.** The only route found for physiotherapy (AMS, AMK) is a 2019 community forum answer: `ER_PRS_F` crossing `PRS_NAT_REF` and `PRS_ACT_CFT`. Treat it as unconfirmed.

Entry points: `documentation-snds.health-data-hub.fr/snds/fiches/` for the thematic sheets (`variables_sociodemo`, `historique_donnees`, `beneficiaires_ald`, `medicament`, `cmu_c`, `aide_medicale_etat`), all opened and quoted first-hand that day.
