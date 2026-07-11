# Reconstruct a chronological audit trail for a dataset

**\[experimental\]**

Walks every log entry across the given axes
([`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)'s
own discovery logic) and explodes each into one row per meaningful event
– a file staged, a CMR workbook split (with its routing plan), a DQ
check run, each individual flag resolved, a whole log entry closed out
via
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
an approval – into a single chronological timeline, **oldest first** (a
timeline reads forward; the triage backlog in
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
reads newest-first — different jobs, different order).

[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
already records which `dq_flags` entries backed each approval (its
`dq_reviewed` field); this is the function that cashes that in —
`log_path` stays on every row so a power user can still drill into the
raw YAML, but nobody should *have* to follow paths by hand to answer
"what happened to this dataset, and who signed off on it."

No CMR-specific entry point is needed: leaving `disease`/`data_source`/
`data_type` `NULL` (the default) already enumerates every
disease/channel/ measure under `country` — for a CMR workbook that
naturally includes the `rblf/cmr` split/approve logs *and* every
fanned-out measure's own logs.

## Usage

``` r
eri_audit(
  country,
  disease = NULL,
  data_source = NULL,
  data_type = NULL,
  period = NULL,
  data_con = NULL
)
```

## Arguments

- country:

  `chr` Country code (e.g. `"sdn"`). Required — an audit trail with no
  country would try to reconstruct a system-wide timeline, which isn't
  the job this function is scoped for.

- disease, data_source, data_type:

  `chr` or `NULL` Narrow further; any left `NULL` is enumerated from the
  blob (same scoping as
  [`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)).

- period:

  `chr` or `NULL` Restrict to one reporting period. Matched as an exact
  string against the value recorded on each entry (the codebase has no
  single canonical period format across sources — CMR periods look like
  `"202605"`, surveillance periods like `"2024-01"`); if nothing matches
  but the scope did contain events, the message lists which periods were
  actually found, so a format mismatch is diagnosable.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble, **oldest first**, with columns `timestamp`, `event`, `actor`,
`detail`, `log_path`, `country`, `disease`, `data_source`, `data_type`,
`period`, `source_hash` (an MD5 identity hash of the source file the
entry's operation ran against, when one was recorded — lets you trace
which exact bytes are behind a given step without opening the raw YAML).
Class `eri_audit_trail`; printing it renders a `cli`-formatted timeline
— the tibble itself is still the API (filter, join, whatever you need).

## See also

[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
for the newest-first triage backlog this reuses for discovery,
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
and
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md)
for the events this timeline surfaces.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_audit("sdn", period = "202605")                      # a whole CMR period
eri_audit("sdn", "oncho", "programmatic", "treatment")   # one measure, all periods
} # }
```
