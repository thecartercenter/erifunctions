# Download all media attachments from an ODK form

Download all media attachments from an ODK form

## Usage

``` r
download_form_attachments(
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN"),
  project_id,
  form_id,
  folder_loc,
  image_label,
  other_vars,
  add_condition = FALSE,
  condition = NULL
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

- folder_loc:

  `chr` Local directory to write downloaded attachments

- image_label:

  `chr` Column name used as the output file stem

- other_vars:

  `chr` Additional columns to include in the returned tibble

- add_condition:

  `lgl` Apply a row filter before downloading

- condition:

  Unquoted
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
  expression; used when `add_condition = TRUE`

## Value

`tibble` of attachment metadata

## See also

Other ODK Central functions:
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md),
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
