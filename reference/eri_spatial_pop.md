# Extract population from LandScan into spatial polygons

Downloads a LandScan raster from Azure, extracts population counts for
each feature in `shapefile` using
[`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html),
and returns the `sf` object with a `pop` column added.

## Usage

``` r
eri_spatial_pop(shapefile, year = NULL, data_con = NULL, fun = "sum")
```

## Arguments

- shapefile:

  An `sf` polygon object (e.g. from
  [`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)).

- year:

  `int` LandScan year to use. If `NULL` (default), uses the latest year
  available in Azure.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

- fun:

  `chr` Summary function passed to
  [`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html).
  Default `"sum"` returns total population per polygon.

## Value

The input `shapefile` with a `pop` column added (numeric).

## Details

By default the most recent LandScan year available in Azure is used.
Older years are accessible via `year`. Run
[`eri_landscan_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_list.md)
to see what is available.

## Examples

``` r
if (FALSE) { # \dontrun{
communes <- eri_spatial_load("ht", level = 2) |>
  eri_spatial_pop()

# Use a specific year
communes_2022 <- eri_spatial_load("ht", level = 2) |>
  eri_spatial_pop(year = 2022)
} # }
```
