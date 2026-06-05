# Create, delete, assign, or revoke an ODK app user role

Create, delete, assign, or revoke an ODK app user role

## Usage

``` r
update_odk_app_user_role(
  action,
  con = NULL,
  url = Sys.getenv("ODK_URL"),
  auth = Sys.getenv("ODK_TOKEN"),
  project_id,
  form_id = NULL,
  actor_name = NULL,
  role_id = NULL,
  actor_id = NULL
)
```

## Arguments

- action:

  `chr` One of `"create"`, `"delete"`, `"assign"`, `"revoke"`

- con:

  An `odk_connection` from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md),
  or `NULL` to use env vars

- url:

  `chr` Server URL (used when `con = NULL`)

- auth:

  `chr` Bearer token (used when `con = NULL`)

- project_id:

  `int` Project ID

- form_id:

  `chr` Form ID; required for `"assign"` and `"revoke"`

- actor_name:

  `chr` Display name; required for `"create"`

- role_id:

  `int` Role ID; required for `"assign"` and `"revoke"`

- actor_id:

  `int` Actor ID; required for `"delete"`, `"assign"`, `"revoke"`

## Value

Named list (for `"create"`) or logical (for all others)
