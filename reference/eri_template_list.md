# List available Quarto and R templates

Returns a tibble combining bundled package templates (always available
offline) with any custom templates registered in the Azure `templates/`
directory. Falls back to bundled-only if no Azure connection is
available.

## Usage

``` r
eri_template_list(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically. Pass `NA` to skip Azure and return bundled templates
  only.

## Value

A tibble with columns: `name`, `description`, `source` (`"bundled"` or
`"azure"`), `filename`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_template_list()

# Bundled only (no Azure connection needed)
eri_template_list(data_con = NA)
} # }
```
