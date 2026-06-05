# Convert CDC epiweek and year to a Date

Returns the first day (Sunday for CDC / Monday for ISO) of the given
epiweek in the given year. Consistent behaviour across DR and Haiti
datasets.

## Usage

``` r
eri_epiweek_date(year, week, week_start = "Sunday")
```

## Arguments

- year:

  `int` 4-digit year.

- week:

  `int` Epiweek number (1–53).

- week_start:

  `chr` First day of the epidemiological week. `"Sunday"` (CDC default)
  or `"Monday"` (ISO).

## Value

A `Date` vector of the same length as `year` and `week`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_epiweek_date(2024, 1)      # first Sunday of epiweek 1, 2024
eri_epiweek_date(2024, 1, "Monday")
} # }
```
