# Sync an ODK form's submissions to Azure

Downloads all submissions for a registered ODK form and writes them as
Parquet file(s) into `data/{country}/{disease}/research/raw/` in the
Azure `data/` container — ODK is the **research** channel's collection
format (`format: odk`) under ADR-0012, not a `data_source` of its own.
The measure (`data_type`) is assigned later, when the analyst cleans the
form into a final dataset. Forms with **repeat groups** (most real
forms) export multiple tables – the main submission table plus one child
table per repeat group – and each is written as its own Parquet
(`{form_id}.parquet`, `{form_id}-{repeat}.parquet`, ...); a flat form
writes a single `{form_id}.parquet`. The registry entry's `last_synced`
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

Invisibly, the downloaded tibble (single-table forms) or a named list of
tibbles (forms with repeat groups); `invisible(NULL)` when zero
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
