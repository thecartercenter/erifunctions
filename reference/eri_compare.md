# Reconcile two datasets and report the differences

Compares a `new` dataset against an `old` one and reports schema, row,
and value differences. Built for the Phase 3 cutover: prove
[`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)'s
`data/staged` output matches the legacy `projects/intermediate`
(hsp-mal) output during the parallel run, so the switch-over rests on
evidence.

## Usage

``` r
eri_compare(
  new,
  old,
  by = NULL,
  ignore = NULL,
  tolerance = 0,
  strict_schema = TRUE,
  new_con = NULL,
  old_con = NULL
)
```

## Arguments

- new:

  A data frame, or a single Azure blob path read with
  [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
  (defaults to the `data` blob). The candidate / new-pipeline output.

- old:

  A data frame, or a single Azure blob path read with
  [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
  (defaults to the `projects` blob). The reference / legacy output.

- by:

  `chr` or `NULL` Key column(s) that uniquely identify a row in both
  datasets. Required for per-cell value reconciliation; must be unique.

- ignore:

  `chr` or `NULL` Columns to drop from both sides before comparing (e.g.
  a run timestamp that is expected to differ).

- tolerance:

  `num` Absolute tolerance for numeric columns; `|new - old|` within
  `tolerance` counts as equal. Default `0` (exact).

- strict_schema:

  `lgl` If `TRUE` (default), added/dropped columns and type mismatches
  count against `equivalent`. If `FALSE`, columns present only in `new`
  are tolerated (value/row parity alone gates equivalence); dropped
  columns and type mismatches still count. See **Details**.

- new_con, old_con:

  Azure containers used only when `new`/`old` are paths. If `NULL`,
  connect automatically (`new` → `data` blob, `old` → `projects` blob).

## Value

An `eri_comparison` object (a list) with `equivalent` (logical),
`summary`, `schema` (`added`/`dropped`/`type_mismatch`), `rows`
(`added`/`dropped` key tibbles), and `values` (a tibble of per-cell
mismatches). Has a [`print()`](https://rdrr.io/r/base/print.html)
method.

## Details

With key columns (`by`) it reconciles row-for-row: which keys were added
or dropped, and — for keys present in both — exactly which cells differ.
Without `by` it still reports the schema diff and set-based row
membership, but cannot pinpoint per-cell value changes.

A key present in **both** datasets is never counted as added or dropped
— only as a possible **value** mismatch. So `rows$added` /
`rows$dropped` are purely key-membership deltas, and `values` holds the
same-key-different-value cells.

`equivalent` always requires the rows and values to match. Whether a
*column* difference also breaks equivalence is governed by
`strict_schema`: by default (`TRUE`) any added or dropped column, or a
type mismatch, makes it `FALSE`. Set `strict_schema = FALSE` to gate on
**value/row parity alone** while tolerating extra columns in `new` (e.g.
provenance the new pipeline adds that the legacy mirror never had) —
dropped columns and type mismatches still count, since those are genuine
regressions. Numeric classes (integer/double) are treated as one type,
so they never flag as a mismatch on their own.

## Examples

``` r
a <- data.frame(id = 1:3, n = c(10, 20, 30), site = c("x", "y", "z"))
b <- data.frame(id = 1:3, n = c(10, 21, 30), site = c("x", "y", "z"))
eri_compare(a, b, by = "id")            # one value mismatch on id 2
#> ✖ Not equivalent.
#> Rows: 3 new · 3 old · 3 matched · 0 added · 0 dropped
#> Values: 1 cell mismatch across 1 row (column: "n")
#> ℹ Inspect `$rows$added`, `$rows$dropped`, `$values`, `$schema`.

if (FALSE) { # \dontrun{
# New staged output vs the legacy mirror, read straight from the blobs
eri_compare(
  new = "uga/oncho/programmatic/treatment/staged/2024_06.parquet",
  old = "health-rb-country-expansion-dev/intermediate/uga/2024_06.parquet",
  by  = c("admin2", "period")
)
} # }
```
