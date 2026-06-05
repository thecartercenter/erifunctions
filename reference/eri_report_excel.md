# Write a multi-sheet ERI-branded Excel report

Convenience wrapper around
[`eri_wb_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_create.md),
[`eri_wb_add_sheet()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_add_sheet.md),
and
[`eri_wb_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_save.md).
Accepts a named list of data frames and writes each as a separate
worksheet in a single `.xlsx` file.

## Usage

``` r
eri_report_excel(
  sheets,
  path,
  title = NULL,
  author = Sys.info()[["user"]],
  overwrite = TRUE
)
```

## Arguments

- sheets:

  Named list of data frames; each element becomes one worksheet. Names
  are used as sheet tab labels.

- path:

  Character; output file path (should end in `.xlsx`).

- title:

  Optional character; stored as workbook title in document properties.

- author:

  Optional character; stored as author in document properties. Defaults
  to the current system user.

- overwrite:

  Logical; overwrite an existing file (default `TRUE`).

## Value

`path` invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_report_excel(
  sheets   = list("Summary" = summary_df, "Cases" = case_df),
  path     = "outputs/malaria_report.xlsx",
  title    = "Hispaniola Malaria 2024"
)
} # }
```
