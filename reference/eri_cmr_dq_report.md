# Run and log DQ checks for a whole CMR workbook, one combined report

**\[experimental\]**

[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
fans one CMR workbook out into many disease/measure datasets; checking
each with
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
one at a time means reading twelve separate
[`dq_report()`](https://thecartercenter.github.io/erifunctions/reference/dq_report.md)
printouts. This runs DQ checks for every measure in `plan` (looked up
via
[`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md)
if not supplied), logs each measure's flags with
[`eri_dq_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_log.md)
as usual, and returns **one** tibble spanning every flag from every
measure – sortable/filterable in one place instead of twelve.

Each row's `flag_id` is what you pass to
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md)
to triage that specific issue (`"not_important"`, `"fixed"`, or
`"noted"`) before closing out the whole measure with
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md).

## Usage

``` r
eri_cmr_dq_report(
  country,
  period,
  plan = NULL,
  supersede = TRUE,
  data_con = NULL
)
```

## Arguments

- country:

  `str` Country code (e.g. `"sdn"`).

- period:

  `str` Reporting period (e.g. `"202605"`).

- plan:

  `tibble` or `NULL` The plan from
  [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  /
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md).
  `NULL` (default) looks it up via
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md).

- supersede:

  `logical` The normal review loop is run, fix, re-run – each run logs a
  fresh entry, and
  [`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
  blocks on *every* unresolved historical entry for a period, not just
  the newest. Default `TRUE` auto-resolves prior open entries for the
  same measure/period with a "superseded by a newer run" note when this
  run logs a new one, so re-running doesn't pile up entries you have to
  close by hand. Set `FALSE` to keep every run's entry open until you
  resolve it yourself.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with one row per flag across every measure: `sheet`, `disease`,
`data_type`, `log_path`, `flag_id`, `row` (the flag's index into the
checked data, not the workbook), `excel_row` (the real row in the
original Excel sheet – use this one when telling a DA what to go fix),
`column`, `value`, `issue`, `status` (all `"open"` on a fresh run). Zero
rows if every measure is clean.

## Examples

``` r
if (FALSE) { # \dontrun{
flags <- eri_cmr_dq_report("sdn", "202605")
flags[flags$status == "open", ]
eri_dq_flag_resolve(flags$flag_id[1], "fixed", note = "corrected upstream")
} # }
```
