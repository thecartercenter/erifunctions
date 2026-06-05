# Convert a Date to a CDC epiweek number

Returns the epidemiological week number (1–53) for each date. The
inverse of
[`eri_epiweek_date()`](https://thecartercenter.github.io/erifunctions/reference/eri_epiweek_date.md).
Uses CDC Sunday-start convention by default (matching DR and Haiti
surveillance data); pass `week_start = "Monday"` for ISO weeks.

## Usage

``` r
eri_date_to_epiweek(date, week_start = "Sunday")
```

## Arguments

- date:

  A `Date` vector (or character coercible to Date).

- week_start:

  `chr` `"Sunday"` (CDC default) or `"Monday"` (ISO).

## Value

An integer vector of epiweek numbers (1–53).

## Details

Dates that fall in an epiweek belonging to a different calendar year
(e.g. Dec 31 in CDC epiweek 1 of the following year) return the correct
week number for that epiweek. Use
[`lubridate::epiyear()`](https://lubridate.tidyverse.org/reference/year.html)
/
[`lubridate::isoyear()`](https://lubridate.tidyverse.org/reference/year.html)
to obtain the corresponding epi year when needed.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_date_to_epiweek(as.Date("2024-01-07"))   # 1
eri_date_to_epiweek(as.Date("2024-12-29"))   # 52

# Add epiweek to a case line list
cases |> dplyr::mutate(epiweek = eri_date_to_epiweek(sample_date))
} # }
```
