# Download all submissions from an ODK form

Download all submissions from an ODK form

## Usage

``` r
download_odk_form(
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN"),
  project_id,
  form_id,
  attachments = FALSE,
  tables = FALSE,
  data_con = NULL
)
```

## Arguments

- con:

  An `odk_connection` from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md),
  or `NULL` to use env vars

- url:

  `chr` Server URL (used when `con = NULL`)

- auth:

  `chr` Bearer token (used when `con = NULL`)

- project_id:

  `int` Project ID from
  [`list_odk_projects()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_projects.md)

- form_id:

  `chr` Form ID from
  [`list_odk_forms()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_forms.md)

- attachments:

  `lgl` Include attachment metadata columns

- tables:

  `lgl` If `TRUE`, return a **named list** of every table in the export
  – the main submission table first, then one child table per repeat
  group (ODK Central exports each repeat as a separate CSV, linked to
  the parent by a `PARENT_KEY` column). Child tables follow in
  alphabetical order of their CSV name, not the form-defined order. If
  `FALSE` (default), return only the main submission table as a single
  tibble.

- data_con:

  Azure container for operation logging; `NULL` skips logging

## Value

A `tibble` of submissions, or – when `tables = TRUE` – a named list of
tibbles (one per export table, main table first).

## See also

Other ODK Central functions:
[`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md),
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md),
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md),
[`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md),
[`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md),
[`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
[`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md),
[`list_all_odk_app_users()`](https://thecartercenter.github.io/erifunctions/reference/list_all_odk_app_users.md),
[`list_odk_forms()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_forms.md),
[`list_odk_projects()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_projects.md),
[`update_odk_app_user_role()`](https://thecartercenter.github.io/erifunctions/reference/update_odk_app_user_role.md)
