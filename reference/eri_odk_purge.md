# Permanently remove an ODK form from the shared Azure registry

**Hard-deletes** every matching registry entry — active *or* already
soft-deleted — removing it from `odk/registry.yaml` entirely. Unlike
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md),
which soft-deletes (`active: false`) and preserves the sync history,
this leaves no trace. Use it to clean up **practice / sandbox**
registrations (which otherwise linger as inactive rows in the shared
registry); for a real form prefer
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md),
which keeps the audit trail.

## Usage

``` r
eri_odk_purge(project_id, form_id, server_url = NULL, data_con = NULL)
```

## Arguments

- project_id:

  `int` ODK Central project ID.

- form_id:

  `str` ODK Central form ID (xmlFormId).

- server_url:

  `str` or `NULL` ODK Central server URL. If `NULL`, matches on
  `project_id` and `form_id` alone (removes every server's matching
  entry).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, the number of entries removed.

## See also

Other ODK Central functions:
[`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md),
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md),
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md),
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md),
[`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md),
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
# Tear down a sandbox registration completely
eri_odk_purge(project_id = 99999, form_id = "eri_test_river_prospection")
} # }
```
