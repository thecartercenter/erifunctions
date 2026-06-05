# Add a ggplot figure slide to an ERI PowerPoint

Saves the ggplot as a temporary PNG and inserts it onto a new slide.

## Usage

``` r
eri_pptx_add_plot(pptx, plot, title = NULL, width = 8, height = 5, dpi = 150)
```

## Arguments

- pptx:

  An `officer` rpptx object.

- plot:

  A `ggplot` object.

- title:

  Optional character; slide title.

- width:

  Figure width in inches (default `8`).

- height:

  Figure height in inches (default `5`).

- dpi:

  Resolution in DPI (default `150`).

## Value

The updated rpptx object.
