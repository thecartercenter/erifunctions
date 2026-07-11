# Mark a log entry as handled

Records a triage note on a single log YAML (by its `log_path` from
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)),
flagging it handled so it drops out of the open backlog. Adds a `triage`
block (`handled`, `handled_by`, `handled_at`, `note`, `forced`) to the
file in place; the original operation record is preserved.

## Usage

``` r
eri_logs_resolve(log_path, note = NULL, data_con = NULL, forced = FALSE)
```

## Arguments

- log_path:

  `chr` Blob path of the log to resolve (the `log_path` column from
  [`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)).

- note:

  `chr` or `NULL` An optional note describing how it was handled.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

- forced:

  `lgl` Mark the entry `handled` because something else bypassed it
  (e.g.
  [`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)'s
  `force = TRUE` path), not because it was actually reviewed and
  resolved. Default `FALSE`. Distinguishes an annotated bypass from a
  genuine resolution in the record –
  [`eri_audit()`](https://thecartercenter.github.io/erifunctions/reference/eri_audit.md)
  renders the two differently.

## Value

Invisibly, `TRUE`.

## Details

Same single-editor caveat as
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md):
this is a read-modify-write with no optimistic-concurrency protection,
so two people resolving the *same* log entry around the same time can
silently clobber one another.

## Examples

``` r
if (FALSE) { # \dontrun{
backlog <- eri_logs(status = "error")
eri_logs_resolve(backlog$log_path[1], note = "Re-ran after the source fixed the file.")
} # }
```
