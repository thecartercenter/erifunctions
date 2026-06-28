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
  data_source,
  layer,
  period = NULL,
  row_count = NULL,
  data_con = NULL,
  data_type = NULL
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

- data_source:

  `chr` The channel (`"surveillance"`, `"programmatic"`, `"research"`).

- layer:

  `chr` Storage layer (`"raw"`, `"staged"`, or `"processed"`).

- period:

  `chr` or `NULL` Data period string (e.g. `"2024-W01"`, `"202405"`).

- row_count:

  `int` or `NULL` Number of rows in the file, if known.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

- data_type:

  `chr` or `NULL` The measure (e.g. `"case"`, `"treatment"`, `"tas"`);
  `NULL` for legacy four-axis entries (ADR-0012).

## Value

The registered entry (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_catalog_register(
  path        = "uga/oncho/programmatic/treatment/processed/2024_06.parquet",
  country     = "uga",
  disease     = "oncho",
  data_source = "programmatic",
  data_type   = "treatment",
  layer       = "processed",
  period      = "2024-06"
)
} # }
```
