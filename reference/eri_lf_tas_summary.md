# Summarise LF TAS antigen test results

Cross-tabulates FTS and RDT results from an individual-level TAS dataset
and returns a tidy tibble with one row per FTS/RDT combination.
Optionally grouped by a geographic or survey unit column.

## Usage

``` r
eri_lf_tas_summary(data, fts_col, rdt_col, group_col = NULL)
```

## Arguments

- data:

  A data frame of individual TAS results (one row per person).

- fts_col:

  `chr` Column with FTS results (e.g. `"Positive"` / `"Negative"`).

- rdt_col:

  `chr` Column with RDT results (e.g. `"Positive"` / `"Negative"` /
  `NA`).

- group_col:

  `chr` or `NULL`. If supplied, the summary is produced per unique value
  of this column (e.g. `"commune"` or `"eu"`).

## Value

A tibble with columns `fts_result`, `rdt_result`, `n`, `pct` (and
`group_col` if supplied).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_lf_tas_summary(tas_data, "fts_result", "rdt_result", group_col = "commune")
} # }
```
