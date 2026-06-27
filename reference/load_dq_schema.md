# Load a DQ schema

Loads a data quality schema for a
`(country, disease, data_source, data_type)` identity (ADR-0012) from
Azure blob storage, falling back to the bundled copy. Schema files live
at `schemas/{country}_{disease}_{data_source}_{data_type}.yaml`; for
`research` the `data_type` (measure) is optional. When a schema is not
found the error lists every available bundled schema.

## Usage

``` r
load_dq_schema(
  country,
  disease,
  data_source = NULL,
  data_type = NULL,
  azcontainer = suppressMessages(get_azure_storage_connection(storage_name =
    Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")))
)
```

## Arguments

- country:

  `str` Country code (e.g. `"dr"`, `"uga"`).

- disease:

  `str` Disease (e.g. `"malaria"`, `"lf"`). In the legacy two-argument
  form this slot held a combined schema key.

- data_source:

  `str` The channel: `"surveillance"`, `"programmatic"`, `"research"`.
  `NULL` (default) selects the legacy two-argument form.

- data_type:

  `str` The measure (e.g. `"case"`, `"treatment"`, `"tas"`); optional
  for `research`.

- azcontainer:

  Azure container object from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
  Pass `NULL` to use only the locally bundled schema files.

## Value

A named list representing the parsed YAML schema.

## Details

The legacy two-argument form `load_dq_schema(country, key)` — where
`key` was a combined `{disease}_{measure}` string like `"malaria_case"`
or `"lf_tas"` — still resolves during the migration via an alias to the
new name.

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("dr", "malaria", "surveillance", "case")
schema <- load_dq_schema("uga", "oncho", "programmatic", "treatment")
} # }
```
