# ADR-0023 — `eri_ingest_cmr()` stamps the real sheet name onto every row

- **Status:** Accepted
- **Date:** 2026-07-16

## Context

Several CMR schemas cover more than one sheet under a single `(country, disease, data_source,
data_type)` identity — most visibly the `rblf/training` schemas (`sdn`, `ssd`, `uga`, `eth`, `nga`,
`mad`, `tcd`), which each alias 6–10 distinct training sheets (CDD Training, Field Ento Training,
ToT Regional, ...) into one canonical column set, per [ADR-0012](0012-source-measure-data-model.md)'s
combined training code. `eri_split_cmr()` routes all of them to the same
`{country}/rblf/programmatic/training/staged/` destination because `load_dq_schema()` can only
resolve one schema file per that four-part identity.

This has a real consequence: once staged (or processed), there was no way to tell which specific
sheet a row came from. Rolling up `tot` (people trained) across the whole `rblf/training` measure
— e.g. via `eri_query()` — silently conflated genuinely different training audiences. Ethiopia's
case makes this concrete: "ToT" (Training of Trainers) counts trainer-cascade capacity, a different
metric from the other 9 sheets' front-line worker headcounts, with no column to separate them
(flagged in the PR #311 review, 2026-07-16).

## Decision

`eri_ingest_cmr()` — the shared, general-purpose CMR sheet reader every ingest path (`eri_split_cmr()`,
direct calls) goes through — now stamps a `sheet` column onto every row it returns, holding the
real sheet name. This resolves correctly whether `sheet` was passed as a name, a country-schema
slug (via `sheet_aliases`), or a 1-based index. It is a change to the function's general return
contract, not scoped to training sheets specifically — the same "problem is general, solve it
generally" reasoning as `excel_row`/`country` (already stamped the same way).

Each of the 7 `rblf_programmatic_training.yaml` schemas aliases this new `sheet` column into a new
canonical `training_type` column (`required: true`, `allowed_values` = that country's exact real
training-sheet names). Non-training schemas leave `sheet` unaliased — it lands in the staged data
but sits inert, exactly like any other raw column no schema references (`run_dq_checks()` has no
"reject unknown columns" behavior).

## Consequences

- **Easier:** anyone rolling up a combined-schema measure can now filter/group by `training_type`
  to compare like with like, instead of every row of `rblf/training` looking interchangeable.
- **Harder / accepted:** every already-staged (not yet approved) training parquet split *before*
  this change lacks a `sheet` column entirely, so `training_type`'s `required: true` will now flag
  it as missing on the next DQ check. This is the same situation ADR-0017's `supersede_staged`
  already exists for — re-run `eri_split_cmr(..., supersede_staged = TRUE)` against the same source
  workbook to refresh already-staged training data with the new column. Nothing auto-migrates.
- **Not doing:** a general "which sheet did this row come from" column for every CMR data type's
  schema (treatment, mmdp, tas, prevalence, entomology) — only the training schemas actually need
  a discriminator today, since they're the only ones combining multiple sheets under one identity.
  The `sheet` column is available to any future schema that needs the same pattern without a further
  `eri_ingest_cmr()` change.

## References

- [ADR-0012](0012-source-measure-data-model.md) — the combined-training-code design this
  discriminator serves.
- [ADR-0017](0017-cmr-staged-file-supersession.md) — `supersede_staged`, the existing mechanism for
  refreshing already-staged data after a schema/ingest change like this one.
- `R/cmr.R`'s `eri_ingest_cmr()`; `inst/schemas/{sdn,ssd,uga,eth,nga,mad,tcd}_rblf_programmatic_training.yaml`.
