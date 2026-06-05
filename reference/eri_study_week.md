# Calculate study week relative to an index date

Returns the integer number of weeks between a data row's epiweek and an
`index_date`. Positive values are after the index, negative are before.
Week 1 is the week containing `index_date`.

## Usage

``` r
eri_study_week(year, week, index_date, week_start = "Sunday")
```

## Arguments

- year:

  `int` Year column.

- week:

  `int` Epiweek column.

- index_date:

  `Date` The reference / treatment date.

- week_start:

  `chr` First day of the epidemiological week. `"Sunday"` (CDC default)
  or `"Monday"`.

## Value

An integer vector of study weeks (can be negative for pre-index
periods).

## Details

Based on `calc_sweek()` from `dr_irs.R`.

## Examples

``` r
if (FALSE) { # \dontrun{
data |> dplyr::mutate(sweek = eri_study_week(year, epiweek, as.Date("2020-01-05")))
} # }
```
