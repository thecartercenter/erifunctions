# Query processed data with SQL (serverless DuckDB)

Run SQL across one or more **processed** datasets without standing up a
database or writing a chain of per-file reads. `eri_query()` attaches
the relevant parquet into an in-process [DuckDB](https://duckdb.org)
session and returns the result as a tibble. The Azure blob stays the
system of record (ADR-0004).

## Usage

``` r
eri_query(
  sql,
  country = NULL,
  disease = NULL,
  data_source = NULL,
  data_type = NULL,
  period = NULL,
  table = "data",
  tables = NULL,
  data_con = NULL
)
```

## Arguments

- sql:

  `chr` A single SQL statement (DuckDB dialect) referencing the in-scope
  table names.

- country, disease, data_source, data_type, period:

  Catalog filters selecting the **processed** datasets to attach as the
  `table` view. Any combination; all `NULL` (default) means "use only
  `tables`".

- table:

  `chr` Name for the catalog-driven table in SQL (default `"data"`).

- tables:

  Named list of additional tables to register: each entry a data.frame,
  a local parquet path, or a `data/` blob path.

- data_con:

  Azure container for the `data/` blob; `NULL` connects automatically
  (only when a catalog query or a blob path is actually needed, so pure
  data.frame queries stay offline).

## Value

A tibble of the query result.

## Details

There are two ways to put data in scope, and they compose:

- **Catalog-driven (roll-ups).** Pass any of `country` / `disease` /
  `data_source` / `data_type` / `period`; `eri_query()` looks up the
  matching **processed** files in the data catalog, reads them, stamps
  each row with its `country` / `disease` / `data_source` / `data_type`
  / `period`, and unions them into a single table named by `table`
  (default `"data"`). This makes cross-country / cross-period
  aggregation a one-liner:
  `SELECT country, SUM(total_cases) FROM data GROUP BY country`. Those
  five column names are **reserved** in this mode — if a dataset already
  carries one, it is overwritten with the catalog value (the path is
  authoritative for these axes) and a warning is issued. Matched files
  with differing columns are unioned by name; missing columns become
  `NA`.

- **Explicit tables (joins).** Pass `tables = list(name = x)` where each
  `x` is a data.frame, a local `.parquet` path, or a `data/` blob path.
  Each is registered under its name so you can join, e.g. cases to a
  population table.

## Requirements

Needs the optional `duckdb` and `DBI` packages
(`install.packages(c("duckdb", "DBI"))`). Very large cross-dataset scans
are bounded by local memory / download (ADR-0004).

## Examples

``` r
if (FALSE) { # \dontrun{
# Cross-country roll-up from the catalog
eri_query(
  "SELECT country, SUM(total_cases) AS cases FROM data GROUP BY country ORDER BY cases DESC",
  disease = "malaria", data_type = "aggregate"
)

# Join an approved dataset to a population table you supply
eri_query(
  "SELECT d.adm1, SUM(d.cases) * 1000.0 / p.pop AS rate
     FROM data d JOIN pop p USING (adm1) GROUP BY d.adm1, p.pop",
  disease = "malaria", data_type = "case", tables = list(pop = pop_df)
)
} # }
```
