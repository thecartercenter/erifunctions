# Load a DQ schema

Loads a disease surveillance data quality schema from Azure blob
storage, or falls back to the schema bundled with the package.

## Usage

``` r
load_dq_schema(
  country,
  disease,
  azcontainer = suppressMessages(get_azure_storage_connection(storage_name =
    Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")))
)
```

## Arguments

- country:

  `str` Country identifier matching the schema filename prefix (e.g.,
  `"dominican_republic"`, `"haiti"`).

- disease:

  `str` Disease name matching the schema filename suffix (e.g.,
  `"malaria"`).

- azcontainer:

  Azure container object from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
  Defaults to the `data` container via `ERIFUNCTIONS_DATA_STORAGE_NAME`.
  Pass `NULL` to use only the locally bundled schema files.

## Value

A named list representing the parsed YAML schema.

## Details

Schema files are YAML documents stored at
`schemas/<country>_<disease>.yaml` in the `data` Azure container (or in
`inst/schemas/` locally). The container name is read from
`ERIFUNCTIONS_DATA_STORAGE_NAME` (default `"data"`).

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("dominican_republic", "malaria")
schema <- load_dq_schema("haiti", "malaria")
} # }
```
