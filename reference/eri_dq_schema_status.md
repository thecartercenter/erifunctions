# List local DQ schema overrides

**\[experimental\]**

Lists every local override created by
[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md),
with its age and whether it is still active or has gone stale (the
upstream schema changed since it was forked – it will be retired
automatically the next time
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
resolves it). Read-only: unlike a real schema load, checking status
never itself retires a stale override.

## Usage

``` r
eri_dq_schema_status(
  azcontainer = suppressMessages(get_azure_storage_connection(storage_name =
    Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")))
)
```

## Arguments

- azcontainer:

  Azure container object from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
  Pass `NULL` to check staleness against only the bundled copies.

## Value

A tibble with columns `stem`, `forked_at`, `forked_by`, `base_source`,
`status` (`"active"`, `"stale (will be retired on next load)"`,
`"unknown (upstream unreachable)"`, or
`"incomplete (missing override file)"` for a sidecar whose paired schema
file is missing, e.g. from an interrupted retire). Zero rows if there
are no overrides.

## See also

Other DQ schema functions:
[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md),
[`eri_dq_schema_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_path.md),
[`eri_dq_schema_reset()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_reset.md),
[`eri_dq_schema_submit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_submit.md),
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)

## Examples

``` r
if (FALSE) { # \dontrun{
eri_dq_schema_status()
} # }
```
