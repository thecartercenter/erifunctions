# Add a styled data sheet to an ERI workbook

Writes a data frame to a new worksheet in the workbook using ERI
branding: bold navy header row, alternating body shading, Calibri font,
frozen first row, and auto-fitted column widths.

## Usage

``` r
eri_wb_add_sheet(wb, sheet_name, data, title = NULL)
```

## Arguments

- wb:

  An `openxlsx2` workbook object from
  [`eri_wb_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_create.md).

- sheet_name:

  Character; name of the new worksheet tab.

- data:

  A data frame or tibble to write.

- title:

  Optional character; written as a bold heading in row 1; data starts in
  row 2 when provided.

## Value

The updated workbook object (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
wb <- eri_wb_create("Report")
wb <- eri_wb_add_sheet(wb, "Cases", cases_df, title = "Malaria cases 2024")
} # }
```
