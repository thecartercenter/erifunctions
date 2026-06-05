# Incidence choropleth map

Joins `case_data` to `shapefile`, computes an incidence rate as
`(case_col / pop_col) * multiplier`, categorises it into the standard
`"malaria.incidence"` breaks (0 / \<1 / 1–10 / \>=10), and returns a
ggplot with `eri_color_scheme("malaria.incidence")` applied.

## Usage

``` r
eri_map_incidence(
  shapefile,
  case_data,
  case_col,
  pop_col,
  admin_col,
  multiplier = 1000,
  title = NULL,
  scale_bar = TRUE,
  north_arrow = TRUE
)
```

## Arguments

- shapefile:

  An `sf` polygon object.

- case_data:

  Data frame with case counts and population.

- case_col:

  `chr` Column with case counts.

- pop_col:

  `chr` Column with denominator population.

- admin_col:

  `chr` Column used to join `case_data` to `shapefile`.

- multiplier:

  `num` Rate multiplier. Default `1000` (cases per 1 000 population).

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
eri_map_incidence(
  communes, annual_cases,
  case_col  = "n_cases",
  pop_col   = "pop",
  admin_col = "adm2_name",
  title     = "Haiti malaria incidence per 1 000, 2024"
)
} # }
```
