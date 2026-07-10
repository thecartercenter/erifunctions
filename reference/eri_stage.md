# Stage intermediate pipeline output into the data/ blob

**\[experimental\]**

Pulls cleaned files from the `projects` blob's `intermediate/` folder
for a registered pipeline and copies them into
`data/{country}/{disease}/surveillance/staged/`, ready for analyst
review via
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

If any destination file already exists in `staged/`, a warning is issued
for each collision and the file is overwritten.

### Registered pipelines

|  |  |  |
|----|----|----|
| Name | Project folder | Countries |
| `hsp-mal` | health-hsp-malaria-dev | `"dr"`, `"ht"` |
| `rb-expansion` | health-rb-country-expansion-dev | `"eth"`, `"nga"`, `"sdn"`, `"ssd"`, `"uga"`, `"mad"`, `"tcd"` |

## Usage

``` r
eri_stage(
  pipeline,
  country,
  disease,
  pattern = NULL,
  overwrite = FALSE,
  projects_con = NULL,
  data_con = NULL
)
```

## Arguments

- pipeline:

  `str` Registered pipeline name: `"hsp-mal"` or `"rb-expansion"`.

- country:

  `str` Country code (e.g. `"dr"`, `"ht"`).

- disease:

  `str` Disease name (e.g. `"malaria"`).

- pattern:

  `str` or `NULL` Optional substring filter applied to filenames before
  staging (e.g. `"2026"` to stage only 2026 files). Default `NULL`
  stages all files.

- overwrite:

  `logical` Controls behaviour when a file already exists in `staged/`.
  `FALSE` (default) issues a
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  for each collision before overwriting — useful for interactive review.
  `TRUE` overwrites silently — intended for scripted or automated
  workflows.

- projects_con:

  Azure container object for the `projects` blob. If `NULL` (default),
  connects automatically using
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

- data_con:

  Azure container object for the `data` blob. If `NULL` (default),
  connects using `ERIFUNCTIONS_DATA_STORAGE_NAME`.

## Value

Invisibly, a character vector of the staged file paths in the `data`
blob.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_stage("hsp-mal", "dr", "malaria")
eri_stage("hsp-mal", "ht", "malaria", pattern = "2026")
eri_stage("hsp-mal", "dr", "malaria", overwrite = TRUE)  # silent, for scripts
} # }
```
