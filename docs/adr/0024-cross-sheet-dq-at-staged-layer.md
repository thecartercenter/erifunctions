# ADR-0024 — Cross-sheet DQ checks: declared in the CMR routing schema, evaluated at DQ time

- **Status:** Accepted
- **Date:** 2026-07-30

## Context

Emalee reported (email, cc Hannah, no rush, 2026-07-30) three DQ checks needed while reviewing
Ethiopia's most recent CMR upload, none of which the existing DQ engine can express:

1. Population reported for a district (IU) on the RB Treatment tab must equal population reported
   for that same district on the LF Treatment tab.
2. For a country with CDD/CS/HW training tabs: if the sum of RB+LF treated for a district is > 0,
   the sum of CDD+CS+HW training for that district must also be > 0.
3. The inverse: if that treatment sum is 0, the training sum must also be 0.

`run_dq_checks()` (`R/dq.R`) operates on one already-loaded dataframe. Its `consistency:` schema
block (`add_anomaly_consistency()`) compares two columns of the *same row* of that one sheet. Even
`eri_cmr_dq_report()`, which already loops over every sheet in one workbook, runs `run_dq_checks()`
separately per measure and just concatenates the flags -- it never joins or aggregates across
measures. This relationship is not Ethiopia-specific: every RBLF country in this codebase (sdn, ssd,
uga, eth, nga, mad, tcd) shares the same RB/LF-treatment + combined-training-schema shape, so per
CLAUDE.md's global-vs-local guardrail this needed a real, reusable capability, not an Ethiopia-only
script.

A key constraint discovered while designing this: staged parquet still carries raw `#field-code`
columns (`eri_split_cmr()` stages data "as-is" -- alias resolution to canonical names like
`district`/`population`/`treated`/`tot`/`training_type` only happens inside `run_dq_checks()`). Any
cross-sheet join has to happen on the *canonical, post-`run_dq_checks()`* data, not on raw staged
files.

## Decision

1. **`cross_consistency:` is a new declarative block on the CMR *routing* schema**
   (`inst/schemas/cmr/{country}.yaml`), not a per-measure DQ schema. Only the routing schema knows a
   whole workbook's sheet-to-measure map; a per-measure DQ schema cannot express "compare me against
   a sibling sheet" by construction. Rule format (see `R/dq_cross.R`'s header comment for the full
   spec): an ordered list of named rules, each a `join_key`, an `lhs`/`rhs` side (`agg` type --
   `sum`/`unique`/`max`/`min`/`mean`/`n` -- plus one or more `sources`, each a `(disease, data_type,
   column[, sheets])` reference), and an `op` (`==`/`!=`/`<`/`<=`/`>`/`>=`/`same_sign`).
2. **Rules are evaluated inside `eri_cmr_dq_report()`**, against the canonical `result$data` each
   sheet's own `run_dq_checks()` pass already produced -- collected into a `tables` list during the
   existing per-measure loop, joined/aggregated by a new pure engine (`R/dq_cross.R`'s
   `.eri_cross_check_run()`) after it. Not via `eri_query()`/DuckDB: that tool works against
   `processed/` parquet with unresolved field codes, is a `Suggests` dependency (routing a
   default-on DQ check through it would make an optional package effectively mandatory for the CMR
   pipeline), and the canonical tables the join needs are already in hand from the loop that just
   ran -- re-reading them would be pure waste. `eri_query()` remains the right tool for the
   deliberate, downstream, analytic joins it already serves.
3. **Findings are workbook-level, not attributable to one measure.** One `dq_flags` log entry at
   `{country}/rblf/programmatic/consistency/logs/` (`consistency` is a new registered `data_type`
   in `inst/registry/data_model.yaml`), surfacing through the existing flags tibble ->
   `eri_dq_review()` -> `eri_dq_export()` -> `eri_dq_flag_resolve()` chain via a new `cross` logical
   column (`sheet = "(cross-sheet)"`, `row`/`excel_row = NA`). A population mismatch between RB and
   LF isn't a defect of "the oncho measure" specifically -- you can't tell which side is wrong, and
   rule 2 has three source measures with no defensible "primary" to attribute it to.
4. **`eri_approve_cmr()` gains a workbook-level gate on unresolved cross-consistency findings**, but
   deliberately does **not** require a cross-check to have run at all -- it blocks only on a
   genuinely *open* finding. Most countries have no `cross_consistency:` rules declared yet, so no
   entry is ever logged for them; treating that absence as "outstanding" would retroactively make
   every period approved before this feature shipped unapprovable.
5. **Absence is always a silent no-op**, at every level: a country's routing schema with no
   `cross_consistency:` block, a rule whose sources match zero available sheets (e.g. a country
   without CDD/CS/HW tabs), and a join key present on only one side of a comparison (e.g. LF's
   smaller endemic-district roster versus RB's) are never errors and never flag anything. A rule
   author's mistake (unrecognized `op`/`agg`, a missing required field) *does* warn loudly and skip
   just that rule -- the same "fail loud on a typo, fail quiet on a legitimate absence" posture
   `R/dq.R`'s `range_when`/`range_overrides` (fixed 2026-07-29) already established.

## Why this is not the join ADR-0012 says stays downstream

[ADR-0012](0012-source-measure-data-model.md) governs the **data model**: no join may be baked into
a *stored* artifact, so a staged/processed file is always exactly one sheet's rows. Nothing here is
written as data -- the join built by `.eri_cross_check_run()` is transient, in-memory, read-only,
and discarded the moment the check returns. It exists solely to compute a review flag on staged data
*before* the human approval gate. Ingest-time joining would destroy information (you could no longer
see what each sheet said on its own); DQ-time cross-referencing preserves it and is exactly what
makes a split-then-check-per-measure pipeline trustworthy in the first place. `processed/` remains
the layer for deliberate downstream joins, and `eri_query()` remains the tool for them.

## Why `staged/`, not `processed/`

`eri_approve_cmr()` promotes measures to `processed/` **per-measure** -- one measure can be approved
while a sibling is still blocked or unreviewed, so `processed/` is not guaranteed to have every
measure of one workbook in sync at any given moment. `staged/`, right after `eri_split_cmr()`, is
the only point where every sheet of one submission is simultaneously present and stable. It is also
*before* the approval gate, which is where a blocking check belongs.

## Consequences

**Easier:** a DA gets a real cross-tab check inside the DQ report they already read, with no new
concept to learn (rules reuse the `op`/`message` vocabulary the `consistency:` block already uses).
Other RBLF countries opt in by editing their routing schema's YAML, not by writing code.

**Harder / accepted:**
- A cross flag has no single Excel row or sheet, so `eri_dq_review()`'s per-flag menu for it drops
  "Fix in source" and "Adjust the schema" (neither has a single target to point at) -- a real,
  if modest, usability narrowing for this flag type versus an ordinary single-measure flag.
- `eri_approve_cmr()`'s cross gate and `eri_dq_review()`'s re-run/dedup logic both needed dedicated
  handling (a cross flag's `(disease, data_type)` is the `"rblf"`/`"consistency"` pseudo-measure,
  which never matches a real resplit measure's key -- without an explicit guard, a re-run would
  duplicate the stale cross row alongside the freshly re-derived one).
- `agg: unique` (used for the population-match rule) will surface a *new* kind of finding never
  checked before -- population inconsistent across `treatment_round` rows within the same sheet --
  which is a real, useful check in its own right, but means some first-run noise should be expected
  on real workbooks that were never validated this way before.
- `eri_cmr_dq_report()` sometimes runs against a **scoped** plan (e.g. `eri_dq_review()`'s targeted
  re-check of one just-resplit measure) that doesn't carry every sheet a cross rule needs. A fallback
  loader (`.eri_cross_load_missing()`) tops up from that period's full last plan before evaluating
  rules, at the cost of one extra `eri_cmr_last_plan()` lookup on every call with rules declared --
  a no-op past that lookup when the plan was already complete.

**Not doing (out of scope for this PR):**
- A general cross-dataset join engine for arbitrary `processed/` data -- `eri_query()` already is
  that, and stays the tool for deliberate downstream analysis.
- Cross-*workbook*, cross-period, or cross-country checks.
- Materializing any joined artifact -- the join is computed and discarded every run.
- Rules for any country other than `eth` -- each country's real sheet names (tcd/mad's templates are
  in French) and district-roster overlaps between diseases are different enough that copying eth's
  rules elsewhere would be guesswork, not generalization. Other countries opt in when someone with
  real knowledge of that country's template asks.

## References

- [ADR-0012](0012-source-measure-data-model.md) -- the source-measure data model and its
  "joins stay downstream" principle this ADR carves a narrow, deliberate exception from.
- [ADR-0023](0023-cmr-ingest-stamps-sheet-name.md) -- the `sheet`/`training_type` discriminator a
  rule's `sheets:` filter (e.g. `[CDD Training, CS Training, HW Training]`) selects against.
- [ADR-0018](0018-dq-schema-local-overrides.md) -- the per-measure DQ schema override lifecycle;
  `cross_consistency:` lives on the CMR *routing* schema instead, which that override path does not
  cover.
- `R/dq_cross.R` (the engine and its schema-format header comment), `R/cmr.R`'s
  `eri_cmr_dq_report()`/`eri_approve_cmr()`, `R/dq_review.R`'s cross-flag guards,
  `inst/schemas/cmr/eth.yaml`'s `cross_consistency:` block, `tests/testthat/test-dq_cross.R`.
