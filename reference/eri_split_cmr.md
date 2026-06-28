# Split a CMR monthly report into per-disease, per-measure staged datasets

**\[experimental\]**

Reads every sheet a country's CMR schema routes (those declaring a
`disease` and a `data_type`), and writes each sheet's parsed rows to
`data/{country}/{disease}/programmatic/{data_type}/staged/` in the
`data` blob (ADR-0012, \#175). The **disease comes from the sheet**
(e.g. `RB Treatment` → `oncho`, `SCH Treatment` → `sch`, `LF MMDP` →
`lf`); cross-programme Training sheets route together under the combined
`rblf` disease. The per-row `#..._disease` field — which holds
program-coverage codes (`RB` / `RBLF` / `RBLFSCH`) — is kept as a data
column, **not** split on, so no row is duplicated across diseases.

Data is staged **parsed as-is** (machine-readable `#field-code` columns;
no reshape, no automated DQ — CMR review is manual).
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
then promotes each `{disease}/programmatic/{data_type}` to `processed/`.

## Usage

``` r
eri_split_cmr(
  path,
  country,
  data_con = NULL,
  overwrite = FALSE,
  dry_run = FALSE
)
```

## Arguments

- path:

  `str` Local path to the CMR Excel file.

- country:

  `str` Three-letter country code (e.g. `"uga"`); resolves the CMR
  schema via
  [`load_cmr_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_cmr_schema.md).

- data_con:

  Azure container for the `data` blob. `NULL` connects using
  `ERIFUNCTIONS_DATA_STORAGE_NAME`.

- overwrite:

  `logical` If `FALSE` (default), warns before overwriting an existing
  staged file.

- dry_run:

  `logical` If `TRUE`, returns the routing plan and writes nothing.
  Default `FALSE`.

## Value

Invisibly, a tibble with one row per routed sheet: `sheet`, `disease`,
`data_type`, `dest`, `n_rows`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Preview where each sheet would land
eri_split_cmr("uga_2024_06.xlsx", "uga", dry_run = TRUE)
# Stage for real, then approve each disease/measure
eri_split_cmr("uga_2024_06.xlsx", "uga")
eri_approve("uga", "oncho", "programmatic", "2024-06", data_type = "treatment")
} # }
```
