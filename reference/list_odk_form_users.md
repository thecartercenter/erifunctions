# List users assigned to an ODK form

List users assigned to an ODK form

## Usage

``` r
list_odk_form_users(
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN"),
  project_id,
  form_id
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

## Value

`tibble` of assigned users and roles
