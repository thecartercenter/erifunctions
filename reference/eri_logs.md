# List the operation / DQ log backlog for triage

Reads the structured operation logs (written by
[`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md),
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
[`eri_stage()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
…) and the DQ-flag logs (written by
[`eri_dq_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_log.md))
from `{country}/{disease}/{data_source}[/{data_type}]/logs/` in the
`data/` Azure blob, and returns them as a triage backlog. Filter to
failures with `status = "error"` or data-quality items with
`status = "needs_review"`, then close items out with
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md).

## Usage

``` r
eri_logs(
  country = NULL,
  disease = NULL,
  data_source = NULL,
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

- country, disease, data_source:

  `chr` or `NULL` Scope the search by country, disease, and channel; any
  left `NULL` is enumerated from the blob.

- data_type:

  `chr` or `NULL` Scope to a single measure (the five-axis layout).
  `NULL` reads the channel-level logs and every measure beneath it.

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
`operation`, `status`, `analyst`, `country`, `disease`, `data_source`,
`data_type`, `period`, `summary`, `n_issues`, `handled`, `handled_by`,
`handled_at`.

## Details

The function scopes the scan to whichever axes you supply and enumerates
the rest from the blob; the more you supply (`country` → `disease` →
`data_source` → `data_type`), the faster it is. It reads both the
four-axis channel-level logs and the five-axis measure-level logs
(ADR-0012).

## Examples

``` r
if (FALSE) { # \dontrun{
# Everything needing attention across the system
eri_logs(status = "error")

# The backlog for one dataset
eri_logs("uga", "oncho", "surveillance")

# Scope to a single measure (five-axis)
eri_logs("uga", "oncho", "programmatic", data_type = "treatment")
} # }
```
