# Add a title slide to an ERI PowerPoint

Adds a slide using the "Title Slide" layout from the loaded template.

## Usage

``` r
eri_pptx_add_title(pptx, title, subtitle = NULL)
```

## Arguments

- pptx:

  An `officer` rpptx object from
  [`eri_pptx_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_create.md).

- title:

  Character; main title text.

- subtitle:

  Optional character; subtitle text.

## Value

The updated rpptx object.

## Examples

``` r
if (FALSE) { # \dontrun{
pptx <- eri_pptx_create() |>
  eri_pptx_add_title("Hispaniola Malaria 2024", subtitle = "Annual Report")
} # }
```
