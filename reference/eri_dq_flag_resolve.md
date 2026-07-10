# Triage a single DQ flag within a logged `eri_dq_log()` entry

**\[experimental\]**

Works through **one flag at a time** rather than an entire DQ-log entry:
marks a specific flag `"not_important"`, `"fixed"`, or `"noted"`, with
an optional note, so a DA can triage a multi-flag entry (e.g. one CMR
measure with several issues) issue by issue instead of all-or-nothing.
Distinct from
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
which closes out the *whole* entry (and marks it `handled`, dropping it
from the open backlog / unblocking
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md))
– resolving every individual flag here does not by itself mark the entry
handled; call
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
afterward for that (it will auto-summarize from the per-flag decisions
if you don't pass your own note).

**Known limitation: single-editor assumption.** This does a
read-modify-write of the whole log YAML with no optimistic-concurrency
check (no ETag/retry, unlike the metadata-store writes in
`catalog.R`/`odk_registry.R`/`artifacts.R`). If two people resolve
different flags in the *same* log entry around the same time, the second
write can silently overwrite the first. Fine for the current one-DA-per-
country-workbook CMR pilot; revisit before assuming it's safe for two
people triaging the same measure's flags concurrently.

## Usage

``` r
eri_dq_flag_resolve(
  flag_id,
  status = c("not_important", "fixed", "noted"),
  note = NULL,
  data_con = NULL
)
```

## Arguments

- flag_id:

  `chr` A flag identifier from
  [`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
  (or built by hand as `paste0(log_path, "::", index)`, where `index` is
  the flag's 1-based position within that log entry).

- status:

  `chr` One of `"not_important"`, `"fixed"`, or `"noted"`.

- note:

  `chr` or `NULL` What you did or decided for this specific flag.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, `TRUE`.

## Examples

``` r
if (FALSE) { # \dontrun{
flags <- eri_cmr_dq_report("sdn", "202605")
eri_dq_flag_resolve(flags$flag_id[1], "fixed", note = "corrected district spelling upstream")
eri_dq_flag_resolve(flags$flag_id[2], "not_important", note = "known template quirk")
} # }
```
