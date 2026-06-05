# Standard epidemic curve

Aggregates case data by time period and returns a bar-chart epidemic
curve ggplot with `eri_plot_theme("epicurve")` applied. Optionally group
by a categorical column or facet by a second grouping.

## Usage

``` r
eri_epidemic_curve(
  data,
  date_col,
  count_col = NULL,
  group_col = NULL,
  period = "week",
  facet_col = NULL,
  title = NULL
)
```

## Arguments

- data:

  A data frame with a date/date-like column and an optional count
  column.

- date_col:

  `chr` Column containing the case date or epiweek-start date. Passed
  through
  [`lubridate::floor_date()`](https://lubridate.tidyverse.org/reference/round_date.html)
  to bin by `period`.

- count_col:

  `chr` Column holding counts. If `NULL`, each row is one case (count =
  1).

- group_col:

  `chr` or `NULL`. If supplied, bars are stacked/filled by this column.

- period:

  `chr` Aggregation period: `"week"`, `"month"`, or `"year"`. Default
  `"week"`.

- facet_col:

  `chr` or `NULL`. If supplied, the plot is faceted by this column.

- title:

  `chr` Plot title. Default `NULL`.

## Value

A ggplot object.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_epidemic_curve(case_data, date_col = "sample_date", count_col = "n",
                   group_col = "country", period = "month",
                   title = "Hispaniola malaria cases")
} # }
```
