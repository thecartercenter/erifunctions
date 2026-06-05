# Pooled prevalence estimator for LF antigen surveys

Implements the standard formula for estimating individual prevalence
from pooled test results: `1 - ((1 - npos/npool)^(1/pool_size))`.

## Usage

``` r
eri_lf_pooled_prev(npos, npool, pool_size, by = NULL)
```

## Arguments

- npos:

  `num` Number of positive pools.

- npool:

  `num` Total number of pools tested.

- pool_size:

  `num` Number of individuals per pool.

- by:

  `chr` vector or `NULL`. Column name(s) in the enclosing data frame
  (for use inside
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html))
  or a plain numeric vector equal in length to `npos`. When `NULL`
  (default), returns a single scalar.

## Value

A numeric scalar (ungrouped) or a tibble with `by` columns plus
`pooled_prev` (grouped).

## Details

When `by` is supplied the function returns one prevalence estimate per
group (weighted mean of pool-level estimates, weighted by pool count).
Matches the formula in `pooled_prev.R`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Scalar
eri_lf_pooled_prev(npos = 3, npool = 100, pool_size = 5)

# Grouped tibble
tas_data |>
  dplyr::group_by(commune) |>
  dplyr::summarise(
    npos      = sum(fts_result == "Positive"),
    npool     = dplyr::n(),
    pool_size = mean(pool_size)
  ) |>
  dplyr::mutate(prev = eri_lf_pooled_prev(npos, npool, pool_size))
} # }
```
