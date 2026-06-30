# Confirm the cutover comparison catches injected divergence

Ties the Phase-3 simulation harness together: inject known anomalies
into a clean `reference` dataset (in the value columns, off the join
keys) and confirm
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
— run with the cutover standard — flags the result as **not
equivalent**. Use it to build confidence that the cutover gate
([`eri_cutover_check()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_check.md))
would catch a real divergence before relying on it.

## Usage

``` r
eri_simulate_check(
  reference,
  by,
  types = c("missing", "outlier", "negative", "typo", "drop"),
  n = 1L,
  seed = NULL,
  tolerance = 0
)
```

## Arguments

- reference:

  A clean data frame to perturb and compare against.

- by:

  `chr` Key column(s) uniquely identifying a row. Anomalies are kept off
  these so the divergence shows up as detectable row/value deltas.

- types:

  `chr` Anomaly types to inject (see
  [`eri_inject_anomalies()`](https://thecartercenter.github.io/erifunctions/reference/eri_inject_anomalies.md)).
  Defaults to all except `duplicate`. Passing `duplicate` is an error.

- n:

  `int` Anomalies per type. Default `1`.

- seed:

  `int` or `NULL` Optional RNG seed for a reproducible run.

- tolerance:

  `num` Numeric tolerance passed to
  [`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md).
  Default `0`.

## Value

Invisibly, a list with `detected` (`TRUE` the comparison flagged the
divergence, `FALSE` it missed the injected anomalies, `NA` nothing was
injected so detection wasn't exercised), `injected` (the anomaly log
from
[`eri_inject_anomalies()`](https://thecartercenter.github.io/erifunctions/reference/eri_inject_anomalies.md)),
and `comparison` (the
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
result, to inspect which deltas were caught).

## Details

`duplicate` is excluded from the default `types`: a duplicate key cannot
be reconciled per-cell, so it makes the keyed comparison abort rather
than report a delta (that is a uniqueness check, separate from
reconciliation).

## See also

[`eri_inject_anomalies()`](https://thecartercenter.github.io/erifunctions/reference/eri_inject_anomalies.md)
to dirty data,
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
to reconcile,
[`eri_cutover_check()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_check.md)
for the real gate.

## Examples

``` r
clean <- data.frame(id = 1:8, cases = c(5, 8, 3, 6, 9, 4, 7, 2), site = letters[1:8])
sim <- eri_simulate_check(clean, by = "id", n = 2, seed = 1)
#> ✔ Simulation: 10 injected anomalies - `eri_compare()` flagged the divergence.
sim$detected            # TRUE — eri_compare flagged the injected anomalies
#> [1] TRUE
sim$comparison$values   # the per-cell mismatches it caught
#> # A tibble: 6 × 4
#>      id column new    old  
#>   <int> <chr>  <chr>  <chr>
#> 1     1 cases  "5000" 5    
#> 2     2 cases  "-9"   8    
#> 3     5 cases  "-10"  9    
#> 4     7 cases  "7000" 7    
#> 5     2 site    NA    b    
#> 6     7 site   "g "   g    
```
