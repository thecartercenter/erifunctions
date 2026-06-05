# Filter data to an epiweek range

Returns rows of `data` whose year + epiweek falls within the inclusive
range `[start_year/start_week, end_year/end_week]`. Handles cross-year
ranges (e.g. week 40/2023 through week 10/2024) correctly.

## Usage

``` r
eri_epiweek_range(
  data,
  year_col,
  week_col,
  start_year,
  start_week,
  end_year,
  end_week
)
```

## Arguments

- data:

  A data frame or tibble.

- year_col:

  `chr` Name of the column containing the 4-digit year.

- week_col:

  `chr` Name of the column containing the epiweek number (1–53).

- start_year:

  `int` Start epi year (inclusive).

- start_week:

  `int` Start epiweek number (inclusive).

- end_year:

  `int` End epi year (inclusive).

- end_week:

  `int` End epiweek number (inclusive).

## Value

A filtered tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
# Keep weeks 40/2023 through 10/2024
eri_epiweek_range(weekly_data, "year", "epiweek",
                   start_year = 2023, start_week = 40,
                   end_year   = 2024, end_week   = 10)
} # }
```
