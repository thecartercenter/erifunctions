# Reconstruct a past `eri_split_cmr()` run's routing plan

**\[experimental\]**

Recovers the routing plan (`sheet`, `disease`, `data_type`, `dest`,
`n_rows`) for a country/period from the persisted operation log, without
rerunning
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
or needing to have kept its return value in your R session.
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
records the full plan in its op-log on every successful run; this reads
the most recent one back.

"Most recent" assumes a re-split for the same country/period supersedes
the one before it with an equal-or-larger set of measures (the normal
case: a corrected workbook re-uploaded whole). If a later run split a
workbook with *fewer* routable sheets than an earlier one for the same
period, only the narrower, newer set is returned – the earlier run's
other measures won't appear here (or in
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)'s
task list) even though they were routed. Not expected in normal use;
worth knowing if periods get re-split from partial/corrective files
rather than a full re-upload.

## Usage

``` r
eri_cmr_last_plan(country, period, data_con = NULL)
```

## Arguments

- country:

  `str` Country code (e.g. `"sdn"`).

- period:

  `str` Reporting period matching the run you want (e.g. `"202605"`).

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with one row per routed sheet: `sheet`, `disease`, `data_type`,
`dest`, `n_rows` – identical in shape to what
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
returns.

## See also

Other CMR pipeline functions:
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md),
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md),
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)

## Examples

``` r
if (FALSE) { # \dontrun{
plan <- eri_cmr_last_plan("sdn", "202605")
} # }
```
