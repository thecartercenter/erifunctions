# Register a processed-layer file in the data catalog

Adds or updates an entry for the given blob path in
`_catalog/data_catalog.yaml` in the `data/` Azure blob. Existing entries
are matched by `path` (upsert semantics).

## Usage

``` r
eri_catalog_register(
  path,
  country,
  disease,
  data_type,
  layer,
  period = NULL,
  row_count = NULL,
  data_con = NULL
)
```

## Arguments

- path:

  `chr` Blob path of the file (e.g.
  `"dr/malaria/surveillance/processed/2024_W01.parquet"`).

- country:

  `chr` Country code (e.g. `"uga"`).

- disease:

  `chr` Disease name (e.g. `"oncho"`).

- data_type:

  `chr` Data type (e.g. `"surveillance"`, `"cmr"`, `"odk"`).

- layer:

  `chr` Storage layer (`"raw"`, `"staged"`, or `"processed"`).

- period:

  `chr` or `NULL` Data period string (e.g. `"2024-W01"`, `"202405"`).

- row_count:

  `int` or `NULL` Number of rows in the file, if known.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The registered entry (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_catalog_register(
  path      = "uga/oncho/surveillance/processed/2024_W01.parquet",
  country   = "uga",
  disease   = "oncho",
  data_type = "surveillance",
  layer     = "processed",
  period    = "2024-W01"
)
} # }
```
