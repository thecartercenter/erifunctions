# List LandScan rasters available in Azure

Returns a tibble of LandScan rasters stored in `data/spatial/landscan/`
in the `data/` Azure blob, sorted by year descending (most recent
first).

## Usage

``` r
eri_landscan_list(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with columns `year`, `name`, `size`, `lastModified`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_landscan_list()
} # }
```
