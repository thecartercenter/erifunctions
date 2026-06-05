# Sync an ODK form's submissions to Azure

Downloads all submissions for a registered ODK form and writes them as a
Parquet file to `data/{country}/{disease}/odk/raw/{form_id}.parquet` in
the Azure `data/` container. The registry entry's `last_synced`
timestamp is updated on success.

## Usage

``` r
eri_odk_sync(
  project_id,
  form_id,
  con = NULL,
  data_con = NULL,
  overwrite = TRUE
)
```

## Arguments

- project_id:

  `int` ODK Central project ID.

- form_id:

  `str` ODK Central form ID (xmlFormId).

- con:

  `odk_connection` or `NULL` ODK connection from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md).
  If `NULL`, falls back to the `ODK_URL` and `ODK_TOKEN` environment
  variables.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically using `ERIFUNCTIONS_*` environment variables.

- overwrite:

  `lgl` Whether to overwrite an existing Parquet file in Azure. Defaults
  to `TRUE`.

## Value

The downloaded tibble (invisibly), or `invisible(NULL)` when zero
submissions are found.

## Examples

``` r
if (FALSE) { # \dontrun{
con      <- init_odk_connection()
data_con <- get_azure_storage_connection()
eri_odk_sync(project_id = 7, form_id = "RiverProspection",
             con = con, data_con = data_con)
} # }
```
