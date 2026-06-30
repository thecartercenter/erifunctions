# Report a stream's cutover readiness from the ledger

Reads `_cutover/cutover_log.yaml`, takes the most recent entry per
`period` for the stream, and computes the **streak**: the number of
consecutive most-recent periods that are `equivalent` (ADR-0015). A
stream is *eligible* for cutover when the streak reaches `n`. Periods
are ordered by the **data `period`** (which for a stream uses one
consistent, lexically-sortable label), and re-checking a period updates
its standing — so backfilling an earlier period is handled correctly.

## Usage

``` r
eri_cutover_status(
  country,
  disease,
  data_source,
  data_type = NULL,
  n = 3,
  data_con = NULL
)
```

## Arguments

- country, disease, data_source:

  `chr` The stream's axes.

- data_type:

  `chr` or `NULL` The measure, where it splits the stream.

- n:

  `int` Consecutive equivalent periods required for eligibility. Default
  `3`.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, a list with `eligible` (lgl), `streak` (int), `n`, and
`periods` (a tibble of `period`, `equivalent`, the delta counts, and
`recorded_at`, in checked order).

## See also

[`eri_cutover_check()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_check.md)
to record a period.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_cutover_status("uga", "oncho", "programmatic", data_type = "treatment")
} # }
```
