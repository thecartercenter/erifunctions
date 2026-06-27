# Ingest a local data file: DQ-check and stage it

**\[experimental\]**

The general analyst ingest entry point. Reads a raw local file, runs all
DQ checks via
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
prints the flags, and writes the cleaned parquet to
`data/{country}/{disease}/{data_source}/staged/` — feeding
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).
It runs on **any** data, including a throwaway sandbox: there is no
pipeline-registry or country gate by default.

The legacy `projects`-blob dual-write (the hsp-mal cutover comparison)
is an **opt-in** mirror: pass `mirror_pipeline = "hsp-mal"` to
additionally mirror the cleaned output to
`projects/{project_folder}/intermediate/{country_subfolder}/`. This is
transitional and removed at the Phase-3 cutover (ADR-0012).

## Usage

``` r
eri_ingest(
  path,
  country,
  disease,
  data_source = "surveillance",
  data_type = "aggregate",
  schema = NULL,
  data_con = NULL,
  mirror_pipeline = NULL,
  projects_con = NULL
)
```

## Arguments

- path:

  `str` Local path to the raw file to ingest.

- country:

  `str` Country code (e.g. `"dr"`, `"ht"`).

- disease:

  `str` Disease name (e.g. `"malaria"`).

- data_source:

  `str` The channel (`"surveillance"`, `"programmatic"`, `"research"`).
  Default `"surveillance"`.

- data_type:

  `str` The measure used to select the DQ schema (e.g. `"aggregate"`,
  `"case"`). Default `"aggregate"`.

- schema:

  Named list from
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md).
  If `NULL` (default), loaded for
  `(country, disease, data_source, data_type)`.

- data_con:

  Azure container for the `data` blob. If `NULL` (default), connects
  using `ERIFUNCTIONS_DATA_STORAGE_NAME`.

- mirror_pipeline:

  `str` or `NULL` If set (e.g. `"hsp-mal"`), also mirror the cleaned
  output to the legacy `projects` blob via that pipeline registry entry.
  Default `NULL` (no mirror; sandbox-safe).

- projects_con:

  Azure container for the `projects` blob; used only when
  `mirror_pipeline` is set. If `NULL`, connects automatically.

## Value

Invisibly, the `dq_result` object (`$data`, `$log`, `$flags`).

## Examples

``` r
if (FALSE) { # \dontrun{
result <- eri_ingest("data/raw/dr_malaria_2024W01.xlsx", "dr", "malaria")
result$flags  # review before approving
eri_approve("dr", "malaria", "surveillance", "2024W01")
} # }
```
