# List the operation / DQ log backlog for triage

Reads the structured operation logs (written by
[`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md),
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
[`eri_stage()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
…) and the DQ-flag logs (written by
[`eri_dq_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_log.md))
from `{country}/{disease}/{data_type}/logs/` in the `data/` Azure blob,
and returns them as a triage backlog. Filter to failures with
`status = "error"` or data-quality items with `status = "needs_review"`,
then close items out with
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md).

## Usage

``` r
eri_logs(
  country = NULL,
  disease = NULL,
  data_type = NULL,
  status = NULL,
  operation = NULL,
  analyst = NULL,
  since = NULL,
  include_handled = FALSE,
  data_con = NULL
)
```

## Arguments

- country, disease, data_type:

  `chr` or `NULL` Scope the search. All three together read a single
  `logs/` directory; any left `NULL` triggers enumeration.

- status:

  `chr` or `NULL` Filter by status (`"success"`, `"error"`,
  `"in_progress"`, `"needs_review"`, `"clean"`).

- operation:

  `chr` or `NULL` Filter by operation (e.g. `"eri_approve"`,
  `"dq_flags"`).

- analyst:

  `chr` or `NULL` Filter by the analyst who ran the operation.

- since:

  `Date`/`chr` or `NULL` Keep logs at or after this date (ISO
  `YYYY-MM-DD`).

- include_handled:

  `lgl` Include items already marked handled. Default `FALSE`.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble, newest first, with columns: `log_path`, `timestamp`,
`operation`, `status`, `analyst`, `country`, `disease`, `data_type`,
`period`, `summary`, `n_issues`, `handled`, `handled_by`, `handled_at`.

## Details

If `country`, `disease`, and `data_type` are all supplied, only that one
log directory is read (fast). Otherwise the function enumerates the data
blob to build a system-wide backlog (slower); supplying filters narrows
the scan.

## Examples

``` r
if (FALSE) { # \dontrun{
# Everything needing attention across the system
eri_logs(status = "error")

# The backlog for one dataset
eri_logs("uga", "oncho", "surveillance")
} # }
```
