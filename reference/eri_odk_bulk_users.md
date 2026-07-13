# Manage ODK app users in bulk from a validated CSV

Reads a CSV of user/form actions, runs pre-flight validation against the
live ODK server, then executes all actions. All validation errors are
collected and reported together before any API calls are made.

## Usage

``` r
eri_odk_bulk_users(csv_path, con = NULL, dry_run = FALSE)
```

## Arguments

- csv_path:

  `chr` Path to a CSV file with columns `project_id`, `form_id`,
  `action`, `actor_name`. Supported actions: `"assign"`, `"remove"`,
  `"create"`.

- con:

  `odk_connection` or `NULL` ODK connection from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md).
  Falls back to `ODK_URL` / `ODK_TOKEN` environment variables.

- dry_run:

  `lgl` If `TRUE`, run pre-flight only and print what would happen. No
  API mutation calls are made.

## Value

A tibble with one row per input row and a `result` column (invisibly).
In `dry_run` mode returns `invisible(NULL)`.

## Details

For `"assign"` rows: if the named app user does not yet exist in the
project, they are created automatically before the form assignment is
made. The assignment uses ODK Central role ID 2 (App User / data
collection role).

For `"remove"` rows: the form assignment is revoked using role ID 2. The
app-user account itself is not deleted.

## See also

Other ODK Central functions:
[`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md),
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md),
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

## Examples

``` r
if (FALSE) { # \dontrun{
# CSV contents:
# project_id,form_id,action,actor_name
# 7,RiverProspection,assign,Jane Fieldworker
# 7,FlyCollection,remove,Jane Fieldworker

eri_odk_bulk_users("users.csv", dry_run = TRUE)
eri_odk_bulk_users("users.csv")
} # }
```
