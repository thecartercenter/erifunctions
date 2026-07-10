# Submit a local DQ schema override for a maintainer to fold in

**\[experimental\]**

Packages a live local schema override (from
[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md))
into a ticket via
[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md):
the message is an auto-drafted, human-readable diff against the schema
it was forked from (so a maintainer never has to retype YAML from a
prose description), the full override file is attached, and the four
ADR-0012 axes plus the schema's own stem are recorded as `context`.
Filed under `area = "dq"`.

Submitting does **not** apply the change anywhere else — it only files
the ticket. Folding it in means a maintainer updates the Azure
`schemas/` `.yaml` blob directly
([`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
already prefers the Azure copy over the bundled one), which takes effect
for every DA within minutes, not at the next package release. Your own
local override keeps working independently (see
[`eri_dq_schema_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_status.md))
until it's reset or the upstream change retires it.

## Usage

``` r
eri_dq_schema_submit(
  country,
  disease,
  data_source = NULL,
  data_type = NULL,
  note = NULL,
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

- note:

  `str` or `NULL` An optional one-line note appended after the
  auto-drafted diff (e.g. why the change matters, or which real
  submission surfaced it).

- azcontainer:

  Azure container object from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

## Value

Invisibly, the logged ticket from
[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md)
(`NULL` if the override is identical to upstream, in which case nothing
is filed).

## See also

[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md)
to create the override being submitted,
[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md)
for the general ticket log.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_dq_schema_edit("sdn", "oncho", "programmatic", "treatment")
# ... edit the file, e.g. widen a range or add a district alias ...
eri_dq_schema_submit("sdn", "oncho", "programmatic", "treatment",
                     note = "Barbar's real submissions use this alias")
} # }
```
