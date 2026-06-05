# List registered artifacts

Returns a tibble of entries from `artifacts/_registry.yaml` in the
`data/` Azure blob. Archived artifacts are excluded by default.

## Usage

``` r
eri_artifact_list(type = NULL, include_archived = FALSE, data_con = NULL)
```

## Arguments

- type:

  `chr` or `NULL` Filter to a specific artifact type (`"spatial"`,
  `"population"`, `"study_data"`, `"reference"`, `"other"`). `NULL`
  returns all types.

- include_archived:

  `lgl` If `TRUE`, include archived entries. Default `FALSE`.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with columns: `name`, `type`, `description`, `version`,
`azure_path`, `filename`, `file_format`, `uploaded_at`, `uploaded_by`,
`archived`.

## Examples

``` r
if (FALSE) { # \dontrun{
# All active artifacts
eri_artifact_list()

# Only study data
eri_artifact_list(type = "study_data")
} # }
```
