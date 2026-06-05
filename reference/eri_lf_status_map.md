# LF programme status choropleth map

Wrapper around
[`eri_map_choropleth()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_choropleth.md)
that applies the standard `"lf.status"` colour scheme and discrete
factor levels from
[`eri_lf_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_program_levels.md).

## Usage

``` r
eri_lf_status_map(
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

  An `sf` polygon object.

- status_data:

  A data frame with a status column and a join key.

- eu_col:

  `chr` Column present in BOTH `shapefile` and `status_data` used to
  join them (e.g. `"eu"` or `"adm2_name"`).

- status_col:

  `chr` Column in `status_data` with LF programme status values (should
  match
  [`eri_lf_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_program_levels.md)
  entries).

- title:

  `chr` Map title. Default `NULL`.

- scale_bar:

  `lgl` Add ggspatial scale bar? Default `TRUE`.

- north_arrow:

  `lgl` Add ggspatial north arrow? Default `TRUE`.

## Value

A ggplot object.

## Details

Requires `ggplot2` (in Imports). `ggspatial` (Imports) is used for scale
bar and north arrow by default; set
`scale_bar = FALSE, north_arrow = FALSE` to suppress.

## Examples

``` r
if (FALSE) { # \dontrun{
eu_sf   <- eri_spatial_load("dr", level = 2)
eri_lf_status_map(eu_sf, lf_status, "adm2_name", "status",
                  title = "DR LF programme status 2024")
} # }
```
