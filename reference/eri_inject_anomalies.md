# Inject controllable anomalies into a clean dataset

Perturbs a data frame with a chosen set of realistic, reproducible
anomalies — the simulation-harness counterpart to the `add_anomaly_*`
detectors. Use it to stand in dirty "new data" for otherwise-clean
staged files so the data-quality and reconciliation paths
([`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md))
are genuinely exercised (roadmap Phase 3).

## Usage

``` r
eri_inject_anomalies(
  data,
  types = c("missing", "outlier", "negative", "typo", "duplicate", "drop"),
  n = 1L,
  cols = NULL,
  seed = NULL
)
```

## Arguments

- data:

  A data frame to perturb.

- types:

  `chr` Which anomalies to inject. Any of missing, outlier, negative,
  typo, duplicate, drop. Defaults to all.

- n:

  `int` How many anomalies to inject **per type** (cells for cell-level
  types, rows for `duplicate`/`drop`). Capped at what's available.
  Default `1`.

- cols:

  `chr` or `NULL` Restrict the cell-level types (`missing`, `outlier`,
  `negative`, `typo`) to these columns. `NULL` (default) auto-picks
  eligible columns per type (numeric for `outlier`/`negative`,
  character/factor for `typo`, any for `missing`).

- seed:

  `int` or `NULL` Optional RNG seed for a reproducible perturbation (set
  locally; the global RNG state is left untouched).

## Value

`data` with anomalies injected, plus an `"eri_anomalies"` attribute (a
tibble of what was changed).

## Details

Anomaly types:

- `missing` — set cells to `NA`.

- `outlier` — replace numeric cells with an extreme value.

- `negative` — make numeric cells implausibly negative (e.g. negative
  counts).

- `typo` — perturb character/factor cells (case, stray characters,
  whitespace).

- `duplicate` — duplicate whole rows.

- `drop` — remove whole rows.

The result carries an `"eri_anomalies"` attribute: a tibble logging
every injection (`type`, `row`, `column`, `original`, `new`) — the
ground truth a simulation can check detection against. `row` is the row
index in the input `data`. This attribute is **in-session only**: it is
dropped the moment the frame is written to Parquet or passed through
most `dplyr` verbs, so capture it before staging the dirty data.
`duplicate` rows are appended, then `drop` removes original rows, so the
logged row indices stay valid.

When the dirty data is destined for
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md),
pass `cols` to keep the cell-level types off the join keys — corrupting
a key changes row-matching rather than producing a detectable value
anomaly.

## See also

[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
to reconcile,
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
to detect.

## Examples

``` r
clean <- data.frame(
  id = 1:10, cases = c(5, 8, 3, 6, 9, 4, 7, 2, 5, 8), site = letters[1:10]
)
dirty <- eri_inject_anomalies(clean, types = c("missing", "outlier"), n = 2, seed = 1)
#> ℹ Injected 4 anomalies: 2 missing and 2 outlier.
attr(dirty, "eri_anomalies")
#> # A tibble: 4 × 5
#>   type      row column original new  
#>   <chr>   <int> <chr>  <chr>    <chr>
#> 1 missing     9 id     9        NA   
#> 2 missing     2 id     2        NA   
#> 3 outlier     4 id     4        4000 
#> 4 outlier     1 id     1        1000 
```
