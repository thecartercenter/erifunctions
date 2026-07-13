# Deregister an ODK form from the shared Azure registry

Soft-deletes by setting `active: false` on the matching entry. Sync
history (`last_synced`, `last_cursor`) is preserved.

## Usage

``` r
eri_odk_deregister(project_id, form_id, server_url = NULL, data_con = NULL)
```

## Arguments

- project_id:

  `int` ODK Central project ID.

- form_id:

  `str` ODK Central form ID (xmlFormId).

- server_url:

  `str` or `NULL` ODK Central server URL. If `NULL`, matches on
  `project_id` and `form_id` alone (errors if ambiguous).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The updated entry (invisibly).

## See also

Other ODK Central functions:
[`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md),
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md),
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md),
[`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md),
[`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md),
[`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
[`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md),
[`list_all_odk_app_users()`](https://thecartercenter.github.io/erifunctions/reference/list_all_odk_app_users.md),
[`list_odk_forms()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_forms.md),
[`list_odk_projects()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_projects.md),
[`update_odk_app_user_role()`](https://thecartercenter.github.io/erifunctions/reference/update_odk_app_user_role.md)

## Examples

``` r
if (FALSE) { # \dontrun{
eri_odk_deregister(project_id = 7, form_id = "RiverProspection")
} # }
```
