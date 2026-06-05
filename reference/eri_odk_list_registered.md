# List all actively registered ODK forms

Returns a tibble of active entries from `odk/registry.yaml` in the
`data/` blob.

## Usage

``` r
eri_odk_list_registered(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with columns: `server_url`, `project_id`, `form_id`,
`form_display_name`, `country`, `disease`, `added_by`, `added_at`,
`last_synced`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_odk_list_registered()
} # }
```
