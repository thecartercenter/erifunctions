# Add an inset reference map to a main map

Draws a small reference map showing `country_sf` in grey with
`highlight_sf` shaded red, then overlays it on `main_map` at the
requested position using
[`cowplot::ggdraw()`](https://wilkelab.org/cowplot/reference/ggdraw.html).
The inset uses `eri_plot_theme("map.inset")` (void theme with a black
border).

## Usage

``` r
eri_map_inset(
  main_map,
  country_sf,
  highlight_sf,
  position = c(0.65, 0.05, 0.32, 0.38),
  highlight_color = "#e63946"
)
```

## Arguments

- main_map:

  A ggplot object (the primary map).

- country_sf:

  An `sf` object for the country/region outline.

- highlight_sf:

  An `sf` object for the study area to highlight in red.

- position:

  `num` vector of length 4 giving the inset position and size as
  fractions of the main map: `c(xmin, ymin, width, height)`. Default
  `c(0.65, 0.05, 0.32, 0.38)`.

- highlight_color:

  `chr` Fill colour for the highlighted area. Default `"#e63946"` (red).

## Value

A cowplot `ggdraw` object (also a ggplot).

## Details

Requires the `cowplot` package.

## Examples

``` r
if (FALSE) { # \dontrun{
haiti <- eri_spatial_load("ht", level = 0)
dept  <- eri_spatial_load("ht", level = 1)
main  <- eri_map_choropleth(dept, data, "n_cases", "adm1_name")
eri_map_inset(main, haiti, dept)
} # }
```
