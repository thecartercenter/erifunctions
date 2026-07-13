# Fork the active DQ schema into a local, editable override

**\[experimental\]**

Copies the currently resolved upstream schema (Azure, or bundled if
Azure has none) into a per-user override directory and records a sidecar
with what it was forked from. The override then becomes the active
schema for
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
until you
[`eri_dq_schema_reset()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_reset.md)
it, or until the upstream schema changes – at which point it is retired
automatically (see
[`eri_dq_schema_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_status.md))
rather than either winning forever or vanishing silently.

This is a **local working copy**, not a submission: nothing here reaches
other DAs or the canonical Azure schema until a maintainer folds it in.

## Usage

``` r
eri_dq_schema_edit(
  country,
  disease,
  data_source = NULL,
  data_type = NULL,
  azcontainer = suppressMessages(get_azure_storage_connection(storage_name =
    Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")))
)
```

## Arguments

- country:

  `str` Country code (e.g. `"dr"`, `"uga"`).

- disease:

  `str` Disease (e.g. `"malaria"`, `"lf"`).

- data_source:

  `str` The channel: `"surveillance"`, `"programmatic"`, `"research"`.

- data_type:

  `str` The measure (e.g. `"case"`, `"treatment"`); optional for
  `research`.

- azcontainer:

  Azure container object from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
  Pass `NULL` to fork only from the bundled copy.

## Value

Invisibly, the local path to the override file.

## See also

Other DQ schema functions:
[`eri_dq_schema_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_path.md),
[`eri_dq_schema_reset()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_reset.md),
[`eri_dq_schema_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_status.md),
[`eri_dq_schema_submit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_submit.md),
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)

## Examples

``` r
if (FALSE) { # \dontrun{
path <- eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment")
file.edit(path)  # or rstudioapi::navigateToFile(path)
# ... load_dq_schema() now returns this override until eri_dq_schema_reset() ...
} # }
```
