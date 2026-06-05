# Save an ERI workbook to disk

Writes the workbook to a `.xlsx` file. Creates parent directories if
needed.

## Usage

``` r
eri_wb_save(wb, path, overwrite = TRUE)
```

## Arguments

- wb:

  An `openxlsx2` workbook object.

- path:

  Character; output file path (should end in `.xlsx`).

- overwrite:

  Logical; overwrite an existing file (default `TRUE`).

## Value

`path` invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_wb_save(wb, "outputs/malaria_report.xlsx")
} # }
```
