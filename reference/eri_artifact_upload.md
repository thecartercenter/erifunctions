# Upload a non-standard reference file to the artifact registry

Uploads a local file to `artifacts/{type}/{name}/` in the `data/` Azure
blob and registers it in `artifacts/_registry.yaml`. Use this for files
that don't go through the standard DQ pipeline — external study data,
population grids, project-specific inputs.

## Usage

``` r
eri_artifact_upload(
  local_path,
  name,
  type,
  description,
  version = NULL,
  data_con = NULL
)
```

## Arguments

- local_path:

  `chr` Path to the local file to upload.

- name:

  `chr` Short identifier for this artifact (e.g. `"dr_irs_2024"`). Must
  be unique in the registry; re-uploading the same name updates the
  entry (upsert).

- type:

  `chr` Artifact type. One of `"spatial"`, `"population"`,
  `"study_data"`, `"reference"`, `"other"`.

- description:

  `chr` Human-readable description of what this file contains.

- version:

  `chr` or `NULL` Optional version string (e.g. `"1.0"`, `"2024-05"`).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The registered entry (invisibly).

## Details

Standard spatial files already in `data/spatial/` do not need to go
through this function; pull them directly via
[`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_artifact_upload(
  local_path  = "data/raw/dr_irs_campaign_2024.xlsx",
  name        = "dr_irs_2024",
  type        = "study_data",
  description = "IRS campaign data from MoH for Dominican Republic 2024"
)
} # }
```
