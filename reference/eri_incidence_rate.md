# Compute incidence rate per population

Vectorized incidence rate: `(cases / pop) * multiplier`. Returns `NA`
for rows where `pop <= 0` or either argument is `NA`.

## Usage

``` r
eri_incidence_rate(cases, pop, multiplier = 1000)
```

## Arguments

- cases:

  `num` Case counts (can be a vector).

- pop:

  `num` Denominator population (same length as `cases`).

- multiplier:

  `num` Rate multiplier. Default `1000` (cases per 1 000).

## Value

A numeric vector of incidence rates.

## Examples

``` r
if (FALSE) { # \dontrun{
data |> dplyr::mutate(rate = eri_incidence_rate(n_cases, population))
} # }
```
