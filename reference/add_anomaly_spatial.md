# Validate admin unit names against a spatial reference

**\[experimental\]**

Flags rows where admin unit names in the data do not appear in the
canonical list extracted from a reference shapefile. Checks admin1 and,
optionally, admin2 when a `admin2_name_field` is defined in the schema.

The shapefile is downloaded from the Azure `data` blob at the path
stored in `schema$admin$admin1_spatial` (and `admin2_spatial`). If the
shapefile is unavailable or the `admin` block is absent from the schema,
the check is skipped with a warning — it never aborts the pipeline.

## Usage

``` r
add_anomaly_spatial(data, schema, azcontainer = NULL)
```

## Arguments

- data:

  A tibble or `dq_result` object.

- schema:

  Named list returned by
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md).

- azcontainer:

  Azure container object for the `data` blob. If `NULL` (default),
  connects automatically using `ERIFUNCTIONS_DATA_STORAGE_NAME`. Pass
  `NULL` to skip the Azure download and use only locally cached files.

## Value

For a plain tibble: a flags tibble with columns `row`, `column`,
`value`, `issue` (same structure as `$flags` in a `dq_result`). For a
`dq_result`: the same object with mismatches appended to `$flags`.

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("dominican_republic", "malaria")
result <- run_dq_checks(raw_data, schema) |> add_anomaly_spatial(schema)
} # }
```
