# Standard LF programme status levels

Returns the canonical ordered character vector of WHO/GPELF LF
elimination status levels. Use with
`factor(status_col, levels = eri_lf_program_levels())` to ensure correct
ordering in tables and maps.

## Usage

``` r
eri_lf_program_levels()
```

## Value

A character vector of length 5.

## Examples

``` r
if (FALSE) { # \dontrun{
data |>
  dplyr::mutate(status = factor(status, levels = eri_lf_program_levels()))
} # }
```
