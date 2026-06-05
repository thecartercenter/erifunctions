# Ingest a local surveillance file and write cleaned output to both blob targets

**\[experimental\]**

The primary analyst entry point for surveillance ingestion. Reads a raw
local Excel file, runs all DQ checks via
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
then dual-writes the cleaned parquet output to:

1.  `projects/{project_folder}/intermediate/{country_subfolder}/` —
    mirrors the GHA pipeline output for side-by-side comparison.

2.  `data/{country}/{disease}/surveillance/staged/` — feeds
    [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

DQ flags are printed to the console immediately after checks complete so
the analyst can review issues before calling
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

## Usage

``` r
eri_ingest(
  path,
  country,
  disease,
  pipeline = "hsp-mal",
  schema = NULL,
  projects_con = NULL,
  data_con = NULL
)
```

## Arguments

- path:

  `str` Local path to the raw Excel file to ingest.

- country:

  `str` Country code (e.g. `"dr"`, `"ht"`).

- disease:

  `str` Disease name (e.g. `"malaria"`).

- pipeline:

  `str` Registry entry that controls which `project_folder` and
  `country_map` are used for the projects blob write. Default
  `"hsp-mal"`.

- schema:

  Named list returned by
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md).
  If `NULL` (default), auto-loaded for the given country and disease.

- projects_con:

  Azure container object for the `projects` blob. If `NULL` (default),
  connects automatically using
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

- data_con:

  Azure container object for the `data` blob. If `NULL` (default),
  connects using `ERIFUNCTIONS_DATA_STORAGE_NAME`.

## Value

Invisibly, the `dq_result` object so the analyst can inspect `$data`,
`$log`, and `$flags`.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- eri_ingest("data/raw/dr_malaria_2024W01.xlsx", "dr", "malaria")
result$flags  # review before approving
eri_approve("dr", "malaria", "surveillance", "2024W01")
} # }
```
