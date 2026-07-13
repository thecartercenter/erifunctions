# Bulk-create ODK Central submissions from a tabular extract

The inverse of
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
/
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md):
take a table of already-collected records (a paper backfill, a legacy
export, or a
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
result) and create them as **submissions** on an existing **published**
ODK Central form. One submission is POSTed per row. See ADR-0013 for the
design contract.

## Usage

``` r
eri_odk_upload(
  data,
  project_id,
  form_id,
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN"),
  key_col = NULL,
  mapping = NULL,
  dry_run = FALSE,
  data_con = NULL
)
```

## Arguments

- data:

  A file path (CSV/Excel, flat forms only), a data.frame, or a **named
  list** of tables (parent first, then `"{form_id}-{repeat}"` child
  tables) – the
  [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)`(tables = TRUE)`
  shape.

- project_id:

  `int` ODK Central project ID.

- form_id:

  `chr` ODK Central form ID (xmlFormId); the form must be published.

- con:

  An `odk_connection` from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md),
  or `NULL` to use the `ODK_URL` / `ODK_TOKEN` environment variables.

- url, auth:

  `chr` Server URL / bearer token, used when `con = NULL`.

- key_col:

  `chr` Column name(s) whose values seed the deterministic `instanceID`.
  `NULL` (default) hashes the whole parent row. To preserve the original
  submission identity on a round-trip, pass the id column (e.g.
  `"KEY"`). Names refer to the columns *after* any `mapping` is applied.

- mapping:

  Named character vector mapping **input column headers to field-column
  names**, for extracts whose headers don't already match the form (e.g.
  a paper CSV): `c(village = "site_name", date_seen = "visit-date")`.
  Targets use the same
  [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
  flattening (`group-field`). The rename is applied to the parent and
  every child table before validation, so columns you don't list are
  left as-is. `NULL` (default) maps nothing.

- dry_run:

  `lgl` If `TRUE`, run validation only and POST nothing; returns the
  validation-issue tibble.

- data_con:

  Azure container for optional operation logging; `NULL` skips it.

## Value

Invisibly: when `dry_run = TRUE`, the validation tibble (`table`,
`column`, `row`, `issue`); otherwise a per-row outcome tibble
(`instance_id`, `status` in `created`/`skipped`/`failed`, `http_status`,
`message`).

## Details

Columns are matched to form fields **by name**, using the same
flattening
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
emits: a field at `/data/visit/date` is the column `visit-date`; repeat
groups are supplied as separate child tables named
`"{form_id}-{repeat}"` and linked to the parent by a `PARENT_KEY` column
whose value matches the parent row's `KEY` (ADR-0010). A
`download_odk_form(tables = TRUE)` result is therefore a valid `data`
argument – the download/upload round-trips.

Each submission's `meta/instanceID` is derived **deterministically**
from `key_col` (or the whole row when `key_col` is `NULL`), so
re-running the same extract re-derives the same ids and ODK Central
rejects the duplicates with HTTP 409 (reported as `skipped`) instead of
double-loading.

## Limitations

Attachments cannot be attached at submission creation (an ODK API
constraint) and are out of scope. Choice-list validation is best-effort:
values for fields backed by external/dataset choices are not checked
here and surface as `failed` rows at POST time if invalid. Submission
XML is built without an instance namespace, matching XLSForm-generated
forms.

## See also

Other ODK Central functions:
[`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md),
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md),
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md),
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md),
[`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md),
[`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md),
[`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
[`list_all_odk_app_users()`](https://thecartercenter.github.io/erifunctions/reference/list_all_odk_app_users.md),
[`list_odk_forms()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_forms.md),
[`list_odk_projects()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_projects.md),
[`update_odk_app_user_role()`](https://thecartercenter.github.io/erifunctions/reference/update_odk_app_user_role.md)

## Examples

``` r
if (FALSE) { # \dontrun{
con <- init_odk_connection()

# Round-trip: pull, correct locally, push back.
tabs <- download_odk_form(con = con, project_id = 7,
                          form_id = "RiverProspection", tables = TRUE)

# Preview validation without sending anything.
eri_odk_upload(tabs, project_id = 7, form_id = "RiverProspection",
               con = con, key_col = "KEY", dry_run = TRUE)

# Create the submissions (re-runs skip already-present rows via HTTP 409).
eri_odk_upload(tabs, project_id = 7, form_id = "RiverProspection",
               con = con, key_col = "KEY")

# A paper CSV whose headers don't match the form: map them. `key_col` names a
# column left unmapped (mapping is applied first), so key on `rec`, not `village`.
paper <- read.csv("historical_records.csv")   # cols: village, date_seen, stage, rec
eri_odk_upload(paper, project_id = 7, form_id = "RiverProspection", con = con,
               mapping = c(village = "site_name", date_seen = "prospection_date",
                           stage = "river_stage"),
               key_col = "rec", dry_run = TRUE)
} # }
```
