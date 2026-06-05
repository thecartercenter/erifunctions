# Add a data table slide to an ERI PowerPoint

Renders a data frame as an
[`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
flextable on a new slide.

## Usage

``` r
eri_pptx_add_table(pptx, data, title = NULL, footnote = NULL)
```

## Arguments

- pptx:

  An `officer` rpptx object.

- data:

  A data frame or tibble to display.

- title:

  Optional character; slide title.

- footnote:

  Optional character; passed to
  [`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md).

## Value

The updated rpptx object.
