# Join point data to admin boundaries

Converts a data frame with latitude/longitude columns to an `sf` points
object, spatially joins it to a polygon `sf` object, and returns the
result as a plain tibble. Rows with `NA` coordinates are dropped with a
warning.

## Usage

``` r
eri_spatial_join(data, lat_col, lon_col, shapefile, admin_cols = NULL)
```

## Arguments

- data:

  A data frame or tibble with coordinate columns.

- lat_col:

  `chr` Name of the latitude column.

- lon_col:

  `chr` Name of the longitude column.

- shapefile:

  An `sf` polygon object (e.g. from
  [`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)).

- admin_cols:

  `chr` vector of column names to attach from `shapefile`. If `NULL`
  (default), all non-geometry columns are attached.

## Value

A tibble with the original `data` columns plus the selected columns from
`shapefile`. Geometry is dropped from the result.

## Examples

``` r
if (FALSE) { # \dontrun{
communes  <- eri_spatial_load("ht", level = 2)
case_data <- eri_spatial_join(
  tas_data,
  lat_col    = "lat",
  lon_col    = "lon",
  shapefile  = communes,
  admin_cols = c("adm2_name", "adm1_name")
)
} # }
```
