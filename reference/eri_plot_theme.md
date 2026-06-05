# ERI standard ggplot2 themes

Returns a
[`ggplot2::theme()`](https://ggplot2.tidyverse.org/reference/theme.html)
object for a given output type. Add to any ggplot with `+`.

## Usage

``` r
eri_plot_theme(type = "map")
```

## Arguments

- type:

  `chr` Theme name. One of:

  - `"map"` — `theme_void()` with legend inside a bordered box, centred
    bold title.

  - `"epicurve"` — `theme_bw()` with 45-degree x-axis tick labels.

  - `"map.inset"` — `theme_void()` with a black panel border (for
    reference insets).

## Value

A [`ggplot2::theme`](https://ggplot2.tidyverse.org/reference/theme.html)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
ggplot(...) + geom_sf() + eri_plot_theme("map")
ggplot(...) + geom_col() + eri_plot_theme("epicurve")
} # }
```
