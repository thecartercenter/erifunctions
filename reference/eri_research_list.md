# List all research projects in Azure

Returns a tibble of projects under `research/` in the `data/` Azure
blob. Each row reflects what was recorded in the project's
`research.yaml` at last upload.

## Usage

``` r
eri_research_list(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with columns: `project_name`, `azure_path`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_list()
} # }
```
