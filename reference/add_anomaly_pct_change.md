# Flag rows with unusual period-over-period percent change

**\[experimental\]**

Computes period-over-period percent change for a numeric column and
flags rows whose absolute change exceeds `threshold`. Works on a plain
tibble or a `dq_result` object returned by
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
enabling chaining:

    run_dq_checks(data, schema) |>
      add_anomaly_pct_change("n_cases", "EpiWeek", group_cols = "Province_Residence")

When passed a `dq_result`, anomaly rows are appended to `$flags` and the
percent-change columns are added to `$data`.

## Usage

``` r
add_anomaly_pct_change(
  data,
  value_col,
  period_col,
  threshold = 0.5,
  group_cols = NULL,
  year_col = NULL
)
```

## Arguments

- data:

  A tibble or `dq_result` object.

- value_col:

  `str` Name of the numeric column to check.

- period_col:

  `str` Name of the column that defines time order within each group
  (e.g. `"EpiWeek"`, `"month"`).

- threshold:

  `num` Absolute percent change threshold (as a proportion). Default
  `0.5` flags changes greater than 50%.

- group_cols:

  `chr` vector of column names to group by before computing change (e.g.
  `c("Province_Residence", "disease")`). Default `NULL` treats the whole
  dataset as one group.

- year_col:

  `str` or `NULL` When `period_col` resets each year (e.g. `"EpiWeek"`
  1–53), supply the year column so ordering is correct across year
  boundaries. Default `NULL`.

## Value

The input object with two columns added to the data:
`pct_change_{value_col}` (numeric) and `anomaly_pct_change_{value_col}`
(logical). If the input is a `dq_result`, flagged rows are also appended
to `$flags`.

## Examples

``` r
if (FALSE) { # \dontrun{
agg <- dplyr::count(raw_dr, Year, EpiWeek, Province_Residence, name = "n_cases")
agg_flagged <- add_anomaly_pct_change(agg, "n_cases", "EpiWeek",
                                       group_cols = "Province_Residence",
                                       year_col   = "Year")
} # }
```
