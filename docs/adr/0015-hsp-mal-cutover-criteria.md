# ADR-0015 — hsp-mal cutover criteria

- **Status:** Accepted
- **Date:** 2026-06-29

## Context

Phase 3 runs the new pipeline **in parallel** with the legacy hsp-mal contractor pipeline: the opt-in
`mirror_pipeline` dual-write keeps feeding the legacy `projects/intermediate` output that Power BI reads,
while `eri_ingest()` writes the same data to `data/staged`. [`eri_compare()`](../../R/compare.R) (#244)
reconciles the two for a given period.

Before we make the `data/` blob authoritative and retire the contractor pipeline, we need a **written,
objective gate** — not a judgement call. The risk is asymmetric: a premature cutover breaks live
dashboards; an over-cautious one wastes effort. So this ADR defines exactly what "equivalent enough to
cut over" means, and requires it to hold **repeatedly**, not once. It also pins the `equivalent`
semantics that `eri_compare()` implements, so the policy and the code can't drift apart.

## Decision

Cutover is decided **per data stream** — a `country` / `disease` / `data_source` (and `data_type` where
the measure splits the stream) combination — and gated on all of:

1. **Equivalence standard.** A `period` is *equivalent* when
   `eri_compare(new_staged, legacy_mirror, by = <stream keys>, strict_schema = FALSE, tolerance = <stream tolerance>)`
   reports `equivalent = TRUE`. Concretely:
   - **Value and row parity are mandatory** — no added or dropped rows, and no per-cell value mismatches
     (within the stream's documented numeric `tolerance`, default `0`).
   - **Schema *additions* are tolerated** (`strict_schema = FALSE`): the new five-axis pipeline may carry
     extra provenance columns the legacy mirror never had. **Dropped columns and type mismatches are
     not** — a column the legacy output had but the new one lost is a regression.
   - The `by` keys and any non-zero `tolerance` are **fixed per stream and recorded**, so the bar cannot
     be quietly moved between periods.
2. **Consecutiveness.** The stream must be equivalent for **N = 3 consecutive periods** (configurable per
   stream, never below 2). A **period** is one reporting cycle of the stream — the data `period` of the
   ingest (e.g. a monthly CMR period, a surveillance epiweek), which is also the ledger's indexing unit —
   *not* a wall-clock interval or an individual ingest event. One match can be luck; a streak is evidence
   the pipelines agree structurally.
3. **No unexplained deltas.** Any delta seen during the parallel run must be explained and either fixed
   or explicitly accepted (and documented) — not merely absent from the latest run. The **streak** is the
   number of consecutive most-recent periods that are both `equivalent = TRUE` *and* carry no open
   (unexplained) delta; **any** non-equivalent period, or a reappearing/unresolved delta, resets it to
   zero. Eligibility needs streak ≥ N.
4. **Human gate.** Meeting 1–3 makes a stream *eligible*; the cutover itself is a deliberate human
   action, consistent with [`eri_approve()`](../../R/dal.R) — the system records the evidence, a person
   decides.

**Streams with no legacy mirror.** A stream the legacy hsp-mal pipeline never produced (e.g. a new
`research` measure under [ADR-0012](0012-source-measure-data-model.md), or a country/disease the
contractor never covered) has nothing to compare against and is **authoritative from the start** — no
cutover gate applies. This gate is only for streams the contractor pipeline currently owns and the
`mirror_pipeline` dual-write mirrors.

**Recording.** Each period's comparison outcome is appended to a **cutover ledger**,
`_cutover/cutover_log.yaml` in the `data/` blob — one entry per stream × period, carrying:
- the **stream identity** — `country`, `disease`, `data_source`, and `data_type` (where the measure
  splits the stream);
- the **`period`** identifier (the indexing unit above);
- `equivalent`, and the delta counts (added/dropped rows, value mismatches, schema diffs);
- the exact `eri_compare()` parameters used — the `by` keys and `tolerance` — so the bar is auditable
  and a later period can't silently use a different standard;
- who recorded it and when (the verified actor).

The ledger is the auditable record from which a stream's streak is computed (count back from the most
recent period per the rule above). The operational helpers that write and read it (record a period,
report a stream's current streak vs `N`) are built **alongside the Phase-3 simulation harness** — the
simulation is what first generates these comparison runs. The ledger reuses the concurrency-safe metadata
write path (ADR-0002) and the verified actor identity (ADR-0003), exactly like the catalog and the
feedback log.

**At cutover.** Once a stream meets the criteria and a maintainer triggers the cutover, its
`mirror_pipeline` dual-write is turned off. When **every** stream in a legacy pipeline is cut over, the
legacy adapters that [ADR-0012](0012-source-measure-data-model.md) isolates — `mirror_pipeline`,
`.eri_pipeline_registry`, `.eri_schema_country_map`, and the `rblf` combined code — are removed (Phase
3), leaving `eri_ingest()` purely general over the five-axis model.

## Consequences

- **Easier:** an objective, auditable, repeatable gate replaces a judgement call; the equivalence
  semantics live in exactly one place (this ADR + `eri_compare()`), so policy and code can't drift.
- **Harder:** requires N periods of parallel running before any cutover, and an up-front per-stream
  decision on keys and tolerance.
- **Not doing:** an *automatic* cutover (the criteria gate it; a person pulls the trigger), or a per-row
  sign-off (the period-level comparison is the unit of evidence). The blob remains the system of record
  (ADR-0004); we are not adding a separate database to track the streak.
