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

## Examples

``` r
if (FALSE) { # \dontrun{
eri_odk_deregister(project_id = 7, form_id = "RiverProspection")
} # }
```
