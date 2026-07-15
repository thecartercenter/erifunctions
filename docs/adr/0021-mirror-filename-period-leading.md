# ADR-0021 — Legacy mirror filename leads with period, not country

- **Status:** Accepted
- **Date:** 2026-07-15

## Context

[`eri_split_cmr(..., mirror_pipeline = "rb-expansion")`](../../R/cmr.R) uploads the DA's raw CMR
workbook to the legacy `projects` blob's raw-drop location, under a generated filename (not
`basename(path)` verbatim — see [ADR-0017](0017-cmr-staged-file-supersession.md)'s note on why a
generated name is needed at all). Since it shipped in v0.9.8, that generated name has been
`{country}_{period}_{timestamp}.ext` (e.g. `uga_202607_20260715T....xlsx`), and
[ADR-0017](0017-cmr-staged-file-supersession.md) explicitly called this out as a *different*
convention from the `staged/` parquet files' own `{period}_..._` leading-period pattern.

Prepping the uga/ssd/nga CMR pilot session surfaced that this was backwards: the legacy pipeline's
real convention — the one the `data/` blob side already matches, and the one
[`eri_split_cmr()`](../../R/cmr.R) itself parses when auto-detecting `period` from an inbound
filename — is `YYYYMM_...`, period leading. Confirmed with the product owner during pilot-session
prep (2026-07-15) that the legacy raw-drop location should follow the same convention, not a
country-first variant invented for this one upload path.

## Decision

The mirror upload's generated filename is now `{period}_{country}_{timestamp}.ext`
(e.g. `202607_uga_20260715T....xlsx`) — period leading, matching the real `YYYYMM_...` convention
used everywhere else in this pipeline (the `staged/` parquet names, and the filename convention
`eri_split_cmr()` itself parses `period` from). This supersedes the format ADR-0017 documented;
ADR-0017's own decision (anchored, opt-in staged-file supersession) is otherwise unchanged — only
its cross-reference to the mirror filename's shape is updated to point here.

## Consequences

- **Easier:** one consistent `YYYYMM_...`-leading convention across every filename this pipeline
  generates (staged parquet, legacy mirror raw-drop), rather than two different orderings that
  happened to both embed the period.
- **Harder / accepted:** any downstream legacy-pipeline tooling that had already adapted to
  parsing `{country}_{period}_...` needs to be checked against the new order before this ships.
  Not verified against the legacy contractor's actual parsing logic (out of scope for this
  package) — if it turns out to matter, this ADR should be revisited alongside a look at whatever
  reads this location downstream.
- **Not doing:** touching `eri_stage_cmr()`'s own filenames (it copies `basename()` of whatever the
  legacy `projects` blob already has verbatim, a different code path not affected by this decision).

## References

- Supersedes the mirror filename format documented in [ADR-0017](0017-cmr-staged-file-supersession.md).
- `R/cmr.R`'s `eri_split_cmr()`, the `mirror_pipeline` branch.
