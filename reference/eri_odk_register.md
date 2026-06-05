# Register an ODK form in the shared Azure registry

Appends a new entry to `odk/registry.yaml` in the `data/` Azure blob.
Errors if the `(server_url, project_id, form_id)` triple is already
active.

## Usage

``` r
eri_odk_register(
  project_id,
  form_id,
  country,
  disease,
  server_url,
  form_display_name = NULL,
  con = NULL,
  data_con = NULL
)
```

## Arguments

- project_id:

  `int` ODK Central project ID.

- form_id:

  `str` ODK Central form ID (xmlFormId).

- country:

  `str` Country code (e.g. `"uga"`). Must be a known ERI country.

- disease:

  `str` Disease name (e.g. `"oncho"`).

- server_url:

  `str` ODK Central server URL (e.g. `"https://odk.example.org"`).

- form_display_name:

  `str` or `NULL` Human-readable form name. Defaults to `form_id`.

- con:

  `odk_connection` or `NULL` ODK connection from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md).
  Not used for registry writes, but included for consistency with other
  ODK functions.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The new registry entry (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_odk_register(
  project_id = 7, form_id = "RiverProspection",
  country = "uga", disease = "oncho",
  server_url = "https://odk.example.org"
)
} # }
```
