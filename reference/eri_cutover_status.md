# Report a stream's cutover readiness from the ledger

**This function's `eligible` result is load-bearing beyond its own
name.**
[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)
calls it internally (`.eri_wizard_should_mirror_cmr()` /
`.eri_wizard_should_mirror_ingest()` in `R/wizard.R`) to decide whether
to dual-write a stream to the legacy contractor pipeline as it processes
a submission. ADR-0015's streak-based cutover gate this was built for is
superseded by
[ADR-0027](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0027-erifunctions-owns-bi-output-contract.md):
nothing currently records new entries (see
[`eri_cutover_check()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_check.md)),
so the streak this reports will not grow. That is intentional, not a bug
to chase — an `eligible = FALSE` that never flips keeps
[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)
mirroring, which is the correct behaviour until erifunctions writes the
BI outputs directly (Stages 2–3). If you're reading this to decide
whether to *raise* `n` or otherwise force eligibility: don't — that
decision belongs to ADR-0027's stage plan, not this function's caller.

Reads `_cutover/cutover_log.yaml`, takes the most recent entry per
`period` for the stream, and computes the **streak**: the number of
consecutive most-recent periods that are `equivalent`. A stream is
*eligible* for cutover when the streak reaches `n`. Periods are ordered
by the **data `period`** (which for a stream uses one consistent,
lexically-sortable label), and re-checking a period updates its standing
— so backfilling an earlier period is handled correctly.

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
