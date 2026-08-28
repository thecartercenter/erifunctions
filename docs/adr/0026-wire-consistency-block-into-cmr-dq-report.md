# ADR-0026 — `eri_cmr_dq_report()` actually evaluates a schema's `consistency:` block

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

`run_dq_checks()`'s roxygen and the `dq-pipeline.Rmd` vignette both describe a `consistency:`
schema block (`add_anomaly_consistency()`, `R/dq.R`) for cross-field rules that can't be expressed
as a single column's `range`/`allowed_values` (e.g. `treated <= target_pop`). Many real schemas
already declare one -- `implausible_overcoverage`/`treated_nonneg` appear in essentially every
`*_programmatic_treatment.yaml` schema across every RB-expansion country.

While implementing issue #334 (a new training-tabs consistency rule, reported by Emalee), it
surfaced that `add_anomaly_consistency()` is **never actually called** anywhere in the real CMR DQ
flow. `eri_cmr_dq_report()` -- the function `eri_do()`'s DQ-review step and every direct DA/script
call to check staged CMR data actually runs -- calls only `run_dq_checks(staged, schema)`.
`add_anomaly_consistency()` exists solely as a manually-chainable extra step
(`run_dq_checks(data, schema) |> add_anomaly_consistency(schema)`, per its own `@examples`), which
no production code path ever does. The result: every `consistency:` rule in every schema in this
package, not just the new one this issue adds, has been silently inert since the block format was
introduced -- authored, documented, and unit-tested against `add_anomaly_consistency()` directly,
but never evaluated against a real staged CMR file.

This is unrelated to, and does not overlap with, the `derived:`/`.dq_aggregate_checks()` mechanism
(a different schema block, already wired into `run_dq_checks()`'s own pipeline) -- the two share
similar names ("consistency checks" / "aggregate consistency") but are separate features with
separate schema keys.

## Decision

`eri_cmr_dq_report()` now chains `add_anomaly_consistency(result, schema)` immediately after
`run_dq_checks(staged, schema)` for every measure that declares a `consistency:` block (guarded on
the block's presence, so a schema without one doesn't print an unconditional "No consistency rules
defined" notice on every run). The resulting flags append to the same `$flags` tibble
`.eri_dq_log_write()` already logs and `eri_dq_review()`/`eri_dq_flag_resolve()`/`eri_approve_cmr()`
already consume -- no new flag shape, no new consumer-side code needed.

`run_dq_checks()` itself is deliberately left unchanged (still does not call
`add_anomaly_consistency()` internally) -- it's a general-purpose function used outside the CMR
pipeline too (surveillance ingest, ad hoc analyst scripts), and its own docstring/vignette already
document `add_anomaly_consistency()` as an opt-in chained step for those callers. Only
`eri_cmr_dq_report()`, the CMR-specific orchestrator, is fixed to always chain it.

## Consequences

- **Easier:** every existing `consistency:` rule -- `implausible_overcoverage`/`treated_nonneg` on
  essentially every treatment schema, plus the new `gender_sum_matches_type_sum` training-tabs rule
  this issue adds -- actually protects real CMR uploads going forward, closing a gap that existed
  since the feature was introduced, not just enabling the one new rule this issue was scoped to add.
- **Harder / accepted, real production blast radius:** the very next `eri_do()` CMR run for ANY
  country with an existing `consistency:` block may surface flags that were always technically true
  of the data but were never actually checked before. This is the intended fix, not a regression,
  but it is a genuine behavior change with the same class of blast radius as ADR-0022's per-sheet
  duplicate-field-code reversal -- confirmed with Nishant before implementing, not assumed safe on
  the code's own authority.
- **Not doing:** wiring `add_anomaly_consistency()` into `run_dq_checks()` itself, or into any
  non-CMR ingest path (surveillance, ODK) -- out of scope for this issue, and those paths' own
  schemas mostly don't declare `consistency:` blocks today. Revisit if that changes.

## References

- Issue #334 / the training-tabs `gender_sum_matches_type_sum` consistency rule that surfaced this.
- `R/cmr.R`'s `eri_cmr_dq_report()`.
- `R/dq.R`'s `add_anomaly_consistency()` and its `lhs_sum`/`rhs_sum` extension (same PR).
