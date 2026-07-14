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
timestamp is updated on success. A pull that now returns zero
submissions (e.g. all test data was deleted from ODK Central) overwrites
raw with the empty result by default, so raw never silently goes stale
relative to the source – see `overwrite`. Per
[ADR-0010](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0010-odk-repeat-group-tables.md)
point 4 (amended by ADR-0019), a zero-row parent clears the whole set:
any repeat table already in `raw/` that this pull did not return is
deleted too, so no orphaned child survives pointing at submissions that
no longer exist.

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

  `lgl` Whether a zero-submission pull overwrites (clears) the form's
  existing raw Parquet file(s) in Azure – including deleting any repeat
  table this pull did not return. Defaults to `TRUE`, so raw faithfully
  mirrors the ODK source, including a genuine deletion of all
  submissions at the source. Set `FALSE` to instead skip the
  write/delete entirely and leave whatever is already in Azure
  untouched, e.g. if a 0-row pull might be a transient ODK API failure
  rather than a real deletion. Unlike `overwrite` elsewhere in the
  package (e.g.
  [`eri_stage()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage.md),
  which gates collision handling on a *non-empty* write), this
  `overwrite` only ever fires on a *zero-row* pull – a normal non-empty
  sync always writes through regardless of this argument.

## Value

Invisibly, the downloaded tibble (single-table forms) or a named list of
tibbles (forms with repeat groups); `invisible(NULL)` when zero
submissions are found and `overwrite = FALSE`.

## See also

Other ODK Central functions:
[`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md),
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md),
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md),
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md),
[`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md),
[`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md),
[`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md),
[`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md),
[`list_all_odk_app_users()`](https://thecartercenter.github.io/erifunctions/reference/list_all_odk_app_users.md),
[`list_odk_forms()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_forms.md),
[`list_odk_projects()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_projects.md),
[`update_odk_app_user_role()`](https://thecartercenter.github.io/erifunctions/reference/update_odk_app_user_role.md)

## Examples

``` r
if (FALSE) { # \dontrun{
con      <- init_odk_connection()
data_con <- get_azure_storage_connection()
eri_odk_sync(project_id = 7, form_id = "RiverProspection",
             con = con, data_con = data_con)
} # }
```
