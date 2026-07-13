# Delete a local DQ schema override

**\[experimental\]**

Removes the local override created by
[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md)
(and its sidecar), so
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
goes back to resolving Azure/bundled directly. Does not touch retired
overrides (`.retired-*` files) – those stay on disk as a record of what
a DA's local changes used to be.

## Usage

``` r
eri_dq_schema_reset(
  country,
  disease,
  data_source = NULL,
  data_type = NULL,
  confirm = TRUE
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

- confirm:

  `logical` Ask for confirmation in an interactive session before
  deleting. Default `TRUE`; non-interactive sessions (scripts/CI)
  proceed without asking regardless.

## Value

Invisibly, `TRUE` if an override was deleted, `FALSE` otherwise.

## See also

Other DQ schema functions:
[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md),
[`eri_dq_schema_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_path.md),
[`eri_dq_schema_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_status.md),
[`eri_dq_schema_submit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_submit.md),
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)

## Examples

``` r
if (FALSE) { # \dontrun{
eri_dq_schema_reset("atlantis", "oncho", "programmatic", "treatment")
} # }
```
