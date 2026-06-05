# Stage CMR monthly report files into the data/ blob

**\[experimental\]**

Pulls CMR Excel files from the `projects` blob's
`raw/filled_templates/{country}/{period}/` folder and copies them into
`data/{country}/rblf/cmr/staged/`, ready for analyst review via
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

If `period` is `NULL`, the most recent period folder (by `YYYYMM` name)
is selected automatically and reported to the console. If any
destination file already exists in `staged/`, a warning is issued and
the file is overwritten.

## Usage

``` r
eri_stage_cmr(
  country,
  period = NULL,
  overwrite = FALSE,
  projects_con = NULL,
  data_con = NULL
)
```

## Arguments

- country:

  `str` Three-letter country code (e.g. `"uga"`, `"eth"`). Must be
  registered in the `"rb-expansion"` pipeline.

- period:

  `str` or `NULL` Six-digit period string matching the source folder
  name (e.g. `"202603"`). Default `NULL` uses the most recent period.

- overwrite:

  `logical` If `FALSE` (default), warns before overwriting an existing
  staged file. If `TRUE`, overwrites silently (for scripted runs).

- projects_con:

  Azure container for the `projects` blob. `NULL` connects automatically
  via
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

- data_con:

  Azure container for the `data` blob. `NULL` connects using
  `ERIFUNCTIONS_DATA_STORAGE_NAME`.

## Value

Invisibly, a character vector of the staged file paths in the `data`
blob.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_stage_cmr("uga", "202603")
eri_stage_cmr("nga")  # auto-selects most recent period
} # }
```
