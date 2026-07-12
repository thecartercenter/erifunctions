# Export a DQ flag report to HTML or markdown

Renders a DQ flags tibble – either the raw `flags` from
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
(`column`/`value`/`issue`, one dataset) or the richer per-CMR-measure
tibble from
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
(adds `sheet`, `excel_row`, `status`, `note`) – to a self-contained
file. This is the artifact a DA hands back to a data source or pastes
into an email/Teams thread once DQ checks have been reviewed, replacing
ad hoc
[`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
calls with one consistent format. Deliberately hand-rolled rather than
routed through
[`eri_report_html()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_html.md)
(which hard-requires a working Quarto install): see `R/reports_lite.R`
for the shared page shell/CSS this shares with
[`eri_feedback_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_report.md).

## Usage

``` r
eri_dq_export(
  flags,
  file = NULL,
  format = c("html", "md"),
  country = NULL,
  period = NULL
)
```

## Arguments

- flags:

  `tibble` A flags tibble – must have `column`, `value`, `issue` columns
  at minimum. `sheet` groups rows into sections (omitted if absent –
  everything renders as one table); `excel_row`/`row` labels the row
  (whichever is present, `excel_row` preferred); `status` and `note` are
  shown when present.

- file:

  `chr` or `NULL` Output path. If `NULL`, writes
  `dq-report-<country>-<period>-<date>.<ext>` (falling back to just the
  date if `country`/`period` are `NULL`) in the working directory.

- format:

  `chr` `"html"` (default, self-contained, prints cleanly to PDF from a
  browser) or `"md"` (GitHub-flavoured markdown).

- country:

  `str` or `NULL` Country code, used only to label the report and
  default the output filename.

- period:

  `str` or `NULL` Reporting period, used only to label the report and
  default the output filename.

## Value

The output file path (invisibly).

## See also

[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
/
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
to generate `flags`,
[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
for the interactive triage wrapper that calls this to print its report.

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("dr", "malaria", "surveillance", "aggregate")
res    <- run_dq_checks(extract, schema)
eri_dq_export(res$flags, country = "dr")

flags <- eri_cmr_dq_report("sdn", "202605")
eri_dq_export(flags, country = "sdn", period = "202605")
} # }
```
