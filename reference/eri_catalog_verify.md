# Verify that catalog entries still exist in Azure

Checks each entry in the data catalog against the live `data/` blob.
Returns a tibble with an `exists` column. Updates `last_verified_at` for
entries that are found. Missing entries are flagged but not removed.

## Usage

``` r
eri_catalog_verify(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble (the result of
[`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md))
with an added `exists` column.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- eri_catalog_verify()
result[!result$exists, ]   # see what is missing
} # }
```
