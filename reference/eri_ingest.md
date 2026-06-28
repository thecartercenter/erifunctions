# Ingest a local data file: DQ-check and stage it

**\[experimental\]**

The general analyst ingest entry point. Reads a raw local file, runs all
DQ checks via
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
prints the flags, and writes the cleaned parquet to
`data/{country}/{disease}/{data_source}/{data_type}/staged/` — feeding
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
with the matching measure. It runs on **any** data, including a
throwaway sandbox: there is no pipeline-registry or country gate by
default.

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

  `str` or `NULL` The measure (e.g. `"aggregate"`, `"case"`,
  `"treatment"`). Selects the DQ schema **and** is the measure level in
  the staged path `.../{data_source}/{data_type}/staged/`. Default
  `"aggregate"`. Whatever you pass here, **promote with the same
  measure** —
  `eri_approve(country, disease, data_source, period, data_type = <same>)`
  — or the approve will look one level up and find nothing. `NULL`
  stages channel-level (four-axis), for the rare measure-less case.

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
# Default measure is "aggregate", so it stages to
# dr/malaria/surveillance/aggregate/staged/ ...
result <- eri_ingest("data/raw/dr_malaria_2024W01.xlsx", "dr", "malaria")
result$flags  # review before approving
# ... and the same measure promotes it:
eri_approve("dr", "malaria", "surveillance", "2024W01", data_type = "aggregate")
} # }
```
