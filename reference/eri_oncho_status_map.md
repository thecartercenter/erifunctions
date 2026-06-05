# Choropleth map of OEPA oncho program status by focus

Joins `status_data` to `shapefile` on `eu_col` and produces a filled
choropleth using the `oncho.status` colour scheme. The status column is
coerced to a factor ordered by
[`eri_oncho_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_program_levels.md)
so the legend always renders in the correct progression.

## Usage

``` r
eri_oncho_status_map(
  shapefile,
  status_data,
  eu_col,
  status_col,
  title = NULL,
  scale_bar = TRUE,
  north_arrow = TRUE
)
```

## Arguments

- shapefile:

  An sf object with one row per evaluation unit.

- status_data:

  A data frame with at least `eu_col` and `status_col`.

- eu_col:

  Name of the evaluation-unit join key in both `shapefile` and
  `status_data`.

- status_col:

  Name of the column in `status_data` containing the program status
  string.

- title:

  Optional map title.

- scale_bar:

  Logical; add a scale bar via `ggspatial` (default `TRUE`).

- north_arrow:

  Logical; add a north arrow via `ggspatial` (default `TRUE`).

## Value

A `ggplot` object.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_oncho_status_map(focus_sf, status_df, eu_col = "focus", status_col = "status")
} # }
```
