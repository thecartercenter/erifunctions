# List all app users in an ODK project

List all app users in an ODK project

## Usage

``` r
list_all_odk_app_users(
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN"),
  project_id
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

## Value

`tibble` of app users
