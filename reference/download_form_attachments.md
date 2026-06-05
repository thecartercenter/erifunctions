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
