# Approve staged data and promote it to processed

**\[experimental\]**

The human approval gate in the three-layer pipeline. Finds all files in
the `staged/` directory whose names contain `period`, moves them to
`processed/`, and writes a YAML approval log alongside them.

Analyst identity is read from the `ERI_ANALYST_ID` environment variable,
falling back to `Sys.info()[["user"]]` if unset.

An operation log capturing every step (including errors) is always
written to `{country}/{disease}/{data_type}/logs/` in the data
container, regardless of whether the approval succeeds or fails. This
log is the primary debugging artifact for pipeline issues.

## Usage

``` r
eri_approve(country, disease, data_type, period, azcontainer = NULL)
```

## Arguments

- country:

  `str` Country code (e.g. `"dr"`, `"ht"`).

- disease:

  `str` Disease name (e.g. `"malaria"`).

- data_type:

  `str` Data input type: `"surveillance"`, `"cmr"`, or `"odk"`.

- period:

  `str` Period string matched against staged filenames (e.g.
  `"2024-W01"`, `"2024-01"`). Any staged file whose name contains this
  string is promoted.

- azcontainer:

  Azure container object for the `data/` blob, returned by
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
  If `NULL` (default), connects automatically using
  `ERIFUNCTIONS_DATA_STORAGE_NAME`.

## Value

Invisibly, a character vector of the promoted file paths in
`processed/`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_approve("dr", "malaria", "surveillance", "2024-W01")
} # }
```
