# Interactively review and resolve a CMR workbook's DQ flags, then approve

**\[experimental\]**

The interactive front door over the scriptable DQ core built in Phases
2-6 of the DQ workflow redesign:
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
for the combined flags tibble,
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md)
and
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
for triage,
[`eri_dq_schema_edit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_edit.md)/[`eri_dq_schema_submit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_submit.md)
for schema fixes,
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
for re-running against a corrected workbook, and
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
(including its `force = TRUE` path) for the sign-off. Every mutation
goes through one of those functions immediately – this wrapper holds no
state of its own beyond one in-memory, per-call path cache (which local
workbook you're fixing this session), so closing the laptop mid-review
and running `eri_dq_review()` again later picks up exactly where the log
YAMLs say things are.

The loop: clean -\> offered approval; flagged -\> work through flags one
at a time (fix in the source workbook, adjust the schema, or mark
not-important/noted), re-run, force-approve, print a report, or exit.
CMR-only for now – the plan machinery this dispatches to
([`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md))
is CMR-specific; generalizing to other ingest shapes later only touches
this orchestration layer.

**Interactive only.** In a script or CI, use the scriptable core
directly:
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md).

## Usage

``` r
eri_dq_review(country, period, plan = NULL, data_con = NULL)
```

## Arguments

- country:

  `str` Country code (e.g. `"sdn"`).

- period:

  `str` Reporting period (e.g. `"202605"`).

- plan:

  `tibble` or `NULL` The plan from
  [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  /
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md).
  `NULL` (default) looks it up via
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md).

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, one of `"approved"`, `"force_approved"`, or `"exited"` – how
the session ended, for a caller like
[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)
that hands off into this same loop and needs to know whether to print
its own closing message. Every effect happens through the scriptable
core it calls, which is where the real return values (approvals,
resolved flags, submitted tickets) live.

## See also

[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
for the scriptable core this orchestrates.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_dq_review("sdn", "202605")
} # }
```
