# Query the data catalog

Returns a filtered tibble of catalog entries from
`_catalog/data_catalog.yaml` in the `data/` Azure blob. All filter
arguments are optional; `NULL` means no filter on that dimension.

## Usage

``` r
eri_catalog_query(
  country = NULL,
  disease = NULL,
  data_source = NULL,
  data_type = NULL,
  layer = NULL,
  period = NULL,
  data_con = NULL
)
```

## Arguments

- country:

  `chr` or `NULL` Filter by country code.

- disease:

  `chr` or `NULL` Filter by disease name.

- data_source:

  `chr` or `NULL` Filter by channel (`"surveillance"`, `"programmatic"`,
  ...).

- data_type:

  `chr` or `NULL` Filter by measure (`"case"`, `"treatment"`, ...).

- layer:

  `chr` or `NULL` Filter by storage layer.

- period:

  `chr` or `NULL` Filter by period string (exact match).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with columns: `path`, `country`, `disease`, `data_source`,
`data_type`, `layer`, `period`, `file_format`, `row_count`,
`size_bytes`, `registered_at`, `registered_by`, `last_verified_at`.

## Examples

``` r
if (FALSE) { # \dontrun{
# All processed Uganda oncho data
eri_catalog_query(country = "uga", disease = "oncho", layer = "processed")

# Everything in the catalog
eri_catalog_query()
} # }
```
