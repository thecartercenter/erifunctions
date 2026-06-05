# Copy the bundled ERI report Quarto template

Copies `inst/templates/eri_report.qmd` to `path` so analysts can
customise it for their own projects.

## Usage

``` r
eri_report_qmd_template(path, overwrite = FALSE)
```

## Arguments

- path:

  Character; destination file path (should end in `.qmd`).

- overwrite:

  Logical; overwrite an existing file (default `FALSE`).

## Value

`path` invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_report_qmd_template("my_custom_report.qmd")
} # }
```
