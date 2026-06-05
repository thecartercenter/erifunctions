# Expand a bounding box by a distance in metres

Takes an `sf` bounding box and expands it by `X` metres in the east-west
direction and `Y` metres in the north-south direction. Useful for adding
padding around a study area before mapping.

## Usage

``` r
eri_bbox_expand(bbox, X, Y, X2 = X, Y2 = Y, crs_out = 4326)
```

## Arguments

- bbox:

  A bounding box produced by
  [`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html).

- X:

  `num` Padding in metres on the west side (and east if `X2` is not
  given).

- Y:

  `num` Padding in metres on the south side (and north if `Y2` is not
  given).

- X2:

  `num` Padding in metres on the east side. Defaults to `X`.

- Y2:

  `num` Padding in metres on the north side. Defaults to `Y`.

- crs_out:

  `int` EPSG code for the output CRS. Defaults to `4326` (WGS84
  lat/lng).

## Value

A bounding box object (`bbox`). Convert to an `sf` polygon with
[`sf::st_as_sfc()`](https://r-spatial.github.io/sf/reference/st_as_sfc.html).

## Details

Ported from `sirfunctions::f.expand.bbox()` / basemapR.

## Examples

``` r
if (FALSE) { # \dontrun{
haiti <- eri_spatial_load("ht", level = 0)
bbox  <- sf::st_bbox(haiti) |> eri_bbox_expand(X = 10000, Y = 10000)
} # }
```
