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

If the country's CMR routing schema (`inst/schemas/cmr/{country}.yaml`)
declares a `cross_consistency:` block, this also evaluates those rules –
declarative checks that span more than one sheet (e.g. "population on
the RB Treatment tab must match population on the LF Treatment tab for
the same district"), which no single-sheet DQ schema can express (see
ADR-0024). Findings are logged as one workbook-level `dq_flags` entry
(`{country}/rblf/programmatic/consistency/logs/`, not attributable to
any one measure) and returned as rows with `sheet = "(cross-sheet)"` and
`cross = TRUE`. Most countries have no `cross_consistency:` block yet,
in which case this step is a silent no-op.

## Usage

``` r
eri_cmr_dq_report(
  country,
  period,
  plan = NULL,
  supersede = TRUE,
  cross = TRUE,
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

- cross:

  `logical` Also evaluate the country's `cross_consistency:` rules, if
  any. Default `TRUE`. Set `FALSE` to skip cross-sheet checks entirely
  (e.g. when re-checking one measure in isolation and cross-sheet
  context isn't needed).

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with one row per flag across every measure: `sheet`
(`"(cross-sheet)"` for a cross-consistency flag), `disease`,
`data_type`, `log_path`, `flag_id`, `row` (the flag's index into the
checked data, not the workbook; `NA` for a cross-sheet flag),
`excel_row` (the real row in the original Excel sheet – use this one
when telling a DA what to go fix; `NA` for a cross-sheet flag, which has
no single row), `column`, `value`, `issue`, `status` (all `"open"` on a
fresh run), `note` (`NA` on a fresh run – only set once a flag has been
triaged via
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md)
and this function is re-run), `cross` (`TRUE` for a cross-consistency
flag, `FALSE` for an ordinary single-measure flag). Zero rows if every
measure (and any cross-consistency rules) is clean.

## See also

Other CMR pipeline functions:
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md),
[`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md),
[`eri_dq_review_note()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review_note.md),
[`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md),
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)

## Examples

``` r
if (FALSE) { # \dontrun{
flags <- eri_cmr_dq_report("sdn", "202605")
flags[flags$status == "open", ]
eri_dq_flag_resolve(flags$flag_id[1], "fixed", note = "corrected upstream")
} # }
```
