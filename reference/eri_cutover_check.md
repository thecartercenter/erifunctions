# Compare a stream's period and record it in the cutover ledger

Runs the **cutover-standard** comparison —
`eri_compare(new, old, by, strict_schema = FALSE, tolerance, ignore)` —
for one data stream's `period` and appends the outcome to
`_cutover/cutover_log.yaml` in the `data/` blob. This is the per-period
evidence the cutover gate is built on (ADR-0015): run it each period of
the parallel run, then check the streak with
[`eri_cutover_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_status.md).

## Usage

``` r
eri_cutover_check(
  new,
  old,
  country,
  disease,
  data_source,
  period,
  by,
  data_type = NULL,
  tolerance = 0,
  ignore = NULL,
  record = TRUE,
  data_con = NULL,
  new_con = NULL,
  old_con = NULL
)
```

## Arguments

- new, old:

  The new (`data/staged`) and reference (legacy `projects/intermediate`)
  datasets — data frames or Azure blob paths, as in
  [`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md).

- country, disease, data_source:

  `chr` The stream's axes.

- period:

  `chr` The period being checked (e.g. `"2024_06"`, `"2024-W01"`).

- by:

  `chr` Key column(s) uniquely identifying a row (required — the gate
  needs per-cell reconciliation).

- data_type:

  `chr` or `NULL` The measure, where it splits the stream.

- tolerance:

  `num` Absolute numeric tolerance for the comparison. Default `0`.

- ignore:

  `chr` or `NULL` Columns to exclude from the comparison.

- record:

  `lgl` Append the outcome to the ledger? Default `TRUE`.

- data_con:

  Azure container for the `data/` blob (the ledger). If `NULL`, connects
  automatically.

- new_con, old_con:

  Passed to
  [`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
  when `new`/`old` are blob paths.

## Value

The
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
result (an `eri_comparison`), invisibly.

## Details

`strict_schema = FALSE` is fixed (not exposed): the cutover gate
requires value/row parity but tolerates extra columns the new pipeline
adds. The `by` keys and `tolerance` are recorded with the entry so the
bar is auditable.

To **accept** a legitimately-expected difference (ADR-0015), record the
period with that difference excluded — pass the differing column to
`ignore`, or widen `tolerance` — so the period reconciles under the
relaxed standard, which is itself recorded in the ledger entry (visible
and attributable, not hidden).

## See also

[`eri_cutover_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_status.md)
for the streak,
[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
for the engine.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_cutover_check(
  new = "uga/oncho/programmatic/treatment/staged/2024_06.parquet",
  old = "health-rb-country-expansion-dev/intermediate/uga/2024_06.parquet",
  country = "uga", disease = "oncho", data_source = "programmatic",
  data_type = "treatment", period = "2024_06", by = c("admin2", "period")
)
} # }
```
