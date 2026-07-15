# Log a free-text note against a CMR period, outside of any single DQ flag

**\[experimental\]**

[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md)
and
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
both take a `note`, but only as part of resolving something – there's no
way to record an observation that isn't tied to a flag. DAs review more
than the flagged fields: cross-checking the workbook's narrative section
against the data itself is routine, and whatever that turns up
(confirmed, a discrepancy worth flagging to the country, anything else)
needs a home in the log even when it never produced a DQ flag. This
writes exactly that – a standalone entry alongside the period's other
CMR logs, picked up by
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
like any other log entry.

## Usage

``` r
eri_dq_review_note(country, period, note, data_con = NULL)
```

## Arguments

- country:

  `str` Country code (e.g. `"sdn"`).

- period:

  `str` Reporting period (e.g. `"202605"`).

- note:

  `str` The note itself. Required, non-empty.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, the log path written.

## See also

[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
for notes tied to a specific flag/entry.

Other CMR pipeline functions:
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md),
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md),
[`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md),
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)

## Examples

``` r
if (FALSE) { # \dontrun{
eri_dq_review_note("sdn", "202605", "Narrative section matches the data -- no discrepancy.")
} # }
```
