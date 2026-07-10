# Resolve the local file path of the currently active DQ schema

**\[experimental\]**

Runs the same three-tier resolution as
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
(local override -\> Azure -\> bundled) but returns the resolved file's
local path instead of its parsed content – for opening the schema in an
editor, or for a script that wants to know exactly which file will be
used without downloading/parsing it twice.

## Usage

``` r
eri_dq_schema_path(
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

`str` Local path to the resolved schema file: the override file itself
when a live override exists, a per-user cache copy when the source is
Azure, or the bundled package path when that's the fallback.

## Examples

``` r
if (FALSE) { # \dontrun{
path <- eri_dq_schema_path("atlantis", "oncho", "programmatic", "treatment")
file.edit(path)  # or rstudioapi::navigateToFile(path)
} # }
```
