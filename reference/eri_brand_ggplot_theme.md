# ERI-branded ggplot2 theme

Extends `eri_plot_theme("epicurve")` with Carter Center font and colour
conventions: Calibri-like base (falls back gracefully if unavailable),
`#44546A` axis titles, and a clean panel suitable for reports.

## Usage

``` r
eri_brand_ggplot_theme(base_size = 11)
```

## Arguments

- base_size:

  Numeric; base font size in points (default `11`).

## Value

A `ggplot2` theme object.

## Examples

``` r
if (FALSE) { # \dontrun{
ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
  ggplot2::geom_point() +
  eri_brand_ggplot_theme()
} # }
```
