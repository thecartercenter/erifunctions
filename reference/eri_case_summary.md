# Summarise case data by grouping columns

Aggregates a case data frame by `group_cols`, optionally filtering to a
date range. If `count_col` is `NULL` (case-level data), counts rows. If
`count_col` is specified (pre-aggregated data), sums that column.

## Usage

``` r
eri_case_summary(
  data,
  group_cols,
  start = NULL,
  end = NULL,
  date_col = NULL,
  count_col = NULL
)
```

## Arguments

- data:

  A data frame or tibble of case records.

- group_cols:

  `chr` vector of columns to group by (e.g. `c("country", "year")`).

- start:

  `Date` or `NULL`. If supplied, keeps rows where `date_col >= start`.

- end:

  `Date` or `NULL`. If supplied, keeps rows where `date_col <= end`.

- date_col:

  `chr` or `NULL`. Required when `start` or `end` is specified. The
  column to filter on.

- count_col:

  `chr` or `NULL`. If `NULL`, counts rows. If a column name, sums that
  column.

## Value

A tibble with `group_cols` plus a `n_cases` column.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_case_summary(
  case_data,
  group_cols = c("country", "year"),
  start      = as.Date("2024-01-01"),
  end        = as.Date("2024-12-31"),
  date_col   = "sample_date"
)
} # }
```
