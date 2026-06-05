# Point overlay map

Converts `point_data` to an `sf` object using `lat_col` and `lon_col`,
overlays it on a base `shapefile`, and returns a ggplot. Rows with `NA`
coordinates are dropped with a warning (same as
[`eri_spatial_join()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_join.md)).

## Usage

``` r
eri_map_points(
  shapefile,
  point_data,
  lat_col,
  lon_col,
  fill_col = NULL,
  shape_col = NULL,
  point_size = 2,
  point_shape = 21,
  title = NULL,
  scale_bar = TRUE,
  north_arrow = TRUE
)
```

## Arguments

- shapefile:

  An `sf` polygon object used as the base layer.

- point_data:

  Data frame with coordinate columns.

- lat_col:

  `chr` Latitude column name.

- lon_col:

  `chr` Longitude column name.

- fill_col:

  `chr` Column in `point_data` used for point fill/colour. `NULL`
  (default) produces solid points.

- shape_col:

  `chr` Column in `point_data` used for point shape. `NULL` (default)
  uses a single shape.

- point_size:

  `num` Point size. Default `2`.

- point_shape:

  `int` Shape number when `shape_col = NULL`. Default `21` (filled
  circle with colour border).

- title:

  `chr` Map title. Default `NULL`.

- scale_bar:

  `lgl` Add a ggspatial scale bar? Default `TRUE`.

- north_arrow:

  `lgl` Add a ggspatial north arrow? Default `TRUE`.

## Value

A ggplot object.

## Examples

``` r
if (FALSE) { # \dontrun{
communes <- eri_spatial_load("ht", level = 2)
eri_map_points(
  communes, tas_results,
  lat_col   = "lat",
  lon_col   = "lon",
  fill_col  = "fts_result",
  title     = "Haiti LF TAS results 2024"
)
} # }
```
