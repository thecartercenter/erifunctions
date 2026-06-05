# List ODK projects

List ODK projects

## Usage

``` r
list_odk_projects(
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN")
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

## Value

`tibble` with columns `project_id`, `project`, `description`
