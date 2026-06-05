# Create an ERI-branded Excel workbook

Initialises an
[`openxlsx2::wb_workbook()`](https://janmarvin.github.io/openxlsx2/reference/wb_workbook.html)
pre-loaded with the Carter Center brand colour set and a creator field.
Use the returned object with
[`eri_wb_add_sheet()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_add_sheet.md)
and
[`eri_wb_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_save.md)
to build up a workbook sheet by sheet before writing to disk.

## Usage

``` r
eri_wb_create(title = NULL, author = Sys.info()[["user"]])
```

## Arguments

- title:

  Character; workbook title stored in document properties.

- author:

  Character; author stored in document properties. Defaults to the
  current system user.

## Value

An `openxlsx2` workbook object.

## Examples

``` r
if (FALSE) { # \dontrun{
wb <- eri_wb_create("Hispaniola Malaria 2024")
wb <- eri_wb_add_sheet(wb, "Summary", summary_df)
eri_wb_save(wb, "malaria_report.xlsx")
} # }
```
