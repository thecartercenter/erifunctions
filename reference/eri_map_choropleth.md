# Choropleth map from a shapefile and data frame

Joins `fill_data` to `shapefile` by `admin_col`, applies
`eri_plot_theme("map")`, and returns a ggplot. The fill variable can be
continuous or discrete; pass a `scale_fill_*` layer to customise.

## Usage

``` r
eri_map_choropleth(
  shapefile,
  fill_data,
  fill_col,
  admin_col,
  title = NULL,
  fill_label = NULL,
  scale_bar = TRUE,
  north_arrow = TRUE
)
```

## Arguments

- shapefile:

  An `sf` polygon object (e.g. from
  [`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)).

- fill_data:

  A data frame with the values to map.

- fill_col:

  `chr` Column in `fill_data` used for fill aesthetics.

- admin_col:

  `chr` Column present in BOTH `shapefile` and `fill_data` used to join
  them (e.g. `"adm2_name"`).

- title:

  `chr` Map title. Default `NULL` (no title).

- fill_label:

  `chr` Legend title. Default `NULL` (uses `fill_col`).

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
eri_map_choropleth(
  communes, case_summary,
  fill_col  = "n_cases",
  admin_col = "adm2_name",
  title     = "Haiti malaria cases 2024"
)
} # }
```
