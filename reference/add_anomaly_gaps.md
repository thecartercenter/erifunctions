# Flag missing time periods in surveillance data

**\[experimental\]**

Identifies gaps in a time series by inferring the full expected sequence
of periods between the observed minimum and maximum, then returning rows
for any missing periods. Works on a plain tibble or a `dq_result`
object.

Supports two period types:

- `"week"` — expects contiguous integers 1–53 within each year. A gap at
  the year boundary (week 52/53 → week 1 of the next year) is handled
  correctly.

- `"month"` — expects contiguous integers 1–12 within each year.

## Usage

``` r
add_anomaly_gaps(
  data,
  period_col,
  period_type = c("week", "month"),
  group_cols = NULL,
  year_col = NULL
)
```

## Arguments

- data:

  A tibble or `dq_result` object.

- period_col:

  `str` Column containing the period value (integer week 1–53 or month
  1–12).

- period_type:

  `str` One of `"week"` or `"month"`.

- group_cols:

  `chr` vector of columns to check for gaps within each group (e.g.
  `c("Province_Residence")`). Default `NULL` checks the full dataset.

- year_col:

  `str` or `NULL` Column containing the year. Required when
  `period_type = "week"` or `"month"` to detect cross-year gaps.

## Value

A tibble of missing periods with columns `year` (if `year_col`
supplied), `period`, any `group_cols`, and `issue = "structural_gap"`.
If the input is a `dq_result`, missing-period rows are also appended to
`$flags` (with `row = NA`). Returns an empty tibble when no gaps are
found.

## Examples

``` r
if (FALSE) { # \dontrun{
gaps <- add_anomaly_gaps(agg_data, "EpiWeek", "week",
                          group_cols = "Province_Residence", year_col = "Year")
} # }
```
