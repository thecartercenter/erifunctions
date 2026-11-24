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

## Addendum (issue #374): a consistency rule that cannot run must not look like one that passed

**Found when:** Ethiopia's August 2026 CMR had real gender-vs-type training mismatches that were not
flagged. The `gender_sum_matches_type_sum` rule was wired in correctly (this ADR) but could not find
its columns on CDD/CS/HW Training, which use a different template layout, so it skipped with one
console line. Wired-in-but-inert and ran-and-passed produced the same empty report.

**Decision:**
- `add_anomaly_consistency()` records every rule it cannot evaluate: `$skipped_rules` on a `dq_result`,
  `attr(, "skipped_rules")` on a plain tibble (columns `rule`, `reason`, `expected`).
- `eri_cmr_dq_report()` aggregates them per rule and sheet, prints them after the flags, returns them as
  `attr(<result>, "skipped_rules")`, and does not print "all clean" when an unexpected skip exists.
- A rule may declare `skip_ok: true` when it is written for one sheet layout and skipping on another is by
  design (`skip_ok` on the two Ethiopia training rules; the ToT sheets are covered separately, below). Those skips are recorded (`expected = TRUE`) but shown
  as a quiet note, so a warning always means something unexpected. A rule without `skip_ok` that skips is
  a warning.
- If **every** rule in a schema skips on a sheet, no consistency check ran on it at all: that is always
  reported as unexpected (a warning) regardless of `skip_ok`, unless the schema lists the sheet under a
  top-level `consistency_not_applicable_sheets:` key (Ethiopia: the ToT sheets). This closes the hole
  where two layout-specific `skip_ok` rules both lose their columns and the report reads clean.
- `add_anomaly_consistency()` no longer ends with "All consistency checks passed." when a rule was
  skipped: it says "not a full pass" (unexpected skips) or "N not applicable here, by design".
- `cross_consistency:` skips (R/dq_cross.R) and sheets that cannot be read or have no schema are **not**
  covered yet.
- Rules that run on a *partial* column match (some summed columns present, others absent) were not covered
  here either; they are now, see the #376 addendum below.

**Consequences:** no change to which rows are flagged by existing rules. Newly checked Ethiopia
CDD/CS/HW sheets (new `monthly_gender_sum_matches_type_sum` rule) may surface new flags -- same class of
blast radius as the original wiring. Tradeoff accepted: a `skip_ok` rule whose aliases later drift is only
a quiet note, not a warning, as long as another rule still ran on that sheet. The all-rules-skipped guard only catches the case where none did, so reviewers should still check that each sheet ran the rule it should have.
- **Duplicated per country, on purpose (for now).** The `gender_sum_matches_type_sum` rule and its 48
  monthly columns are copied into the ht/nga/sdn/ssd/uga training schemas (and Ethiopia's), because
  schemas have no include/inheritance mechanism and this is how every other shared column set is
  already carried. Revisit a shared fragment if a seventh copy is needed. `mad` and `tcd` have training
  schemas but no processed training files to verify against yet, so they do not get the rule until real
  data exists (their sheets would otherwise be unverifiable guesses). *(#373: Madagascar now has a
  202609 CMR and its CDD/CS/health-worker tab names are checked for the cross-sheet rule; this
  training-sum rule is still to do for it.)*

## Addendum (issue #376): a summed side with only some of its columns present runs, and says so

**Decision:** when an `lhs_sum`/`rhs_sum` side resolves some but not all of its columns,
`add_anomaly_consistency()` still evaluates the rule on the columns present (missing ones count as 0), and:

- records a row in the skipped-rules table with `expected = FALSE` and a `reason` such as
  `"lhs_sum incomplete, ran without 1 of 24 column(s): trained_male_nov"`. `skip_ok` does not apply: it
  means "this rule is for another layout" (none of its columns present), whereas a partial match means
  columns were lost from the layout the rule was written for;
- appends `"(checked without <columns>: not found in the data)"` to each flag the rule raises;
- does not end with "All consistency checks passed" when such a rule found nothing.

`eri_cmr_dq_report()` prints these rows as their own warning block (naming the missing columns per sheet),
does not count them towards "every rule skipped on this sheet" (the rule ran), and does not say "all
clean" while one exists. Incomplete rows are told apart from true skips by the `reason` marker, through one
helper (`.dq_is_incomplete()`), rather than by adding a column to the skipped-rules table.

**Why run rather than skip:** checked against all 215 real staged and processed training files (eth, ht,
nga, sdn, ssd, uga), exactly one summed side was partial: Ethiopia's June 2026 CDD Training sheet, whose
`#cddtrn_male_mov` is a template typo for `#cddtrn_male_nov`. November was empty in that file, and the rule
raised 2 flags that are real mismatches in other months; with the typo aliased it raises the same 2.
Skipping the rule would have hidden them. Running it and labelling the result keeps real findings and tells
the reviewer which flags might come from the missing column. Emalee chose this over skipping (2026-11-19).

**Why no `allow_partial` opt-in:** the rule already runs; an opt-in would only silence the warning, and no
schema has a legitimate partial layout. Add one if a real case appears.

**Consequences:** no change for sides that resolve all or none of their columns; on the 215 real files,
flag counts are identical before and after. A file with a renamed or dropped monthly field code now shows a
warning naming the column, and that rule's flags carry the note. Flags are not matched across runs by their
`issue` text (each `eri_cmr_dq_report()` run supersedes the previous run's log for the period), so the
longer `issue` text does not affect review state.

## Addendum (issue #372): `rhs_scale`, a 2x overcoverage limit, and numbers in the flag value

**Context:** once this ADR wired `consistency:` into `eri_cmr_dq_report()`, `implausible_overcoverage`
(`treated <= target_pop`) fired on every row over 100% raw coverage. Population estimates are often low
(reported for South Sudan and Ethiopia), so most flags were noise, and the flag's `value` held only the
lhs, so a DA could not judge it without the workbook.

**Decision:**
- `consistency:` rules accept `rhs_scale`, one positive number that multiplies a column rhs (`rhs` /
  `rhs_sum`) before the comparison. It is rejected with `rhs_value` (write the scaled constant). An
  invalid value, or a non-numeric rhs column to scale, skips the rule and records it (`expected = FALSE`)
  rather than checking something other than what the schema says. `eri_schema_validate()` uses the same
  check (`.dq_rhs_scale_problem()`).
- `implausible_overcoverage` uses `rhs_scale: 2` in all 20 treatment schemas that carry it, and in the
  onboarding template. One global value, chosen by Emalee (2026-11-19): on all 4,172 current staged and
  processed treatment rows, 1.5x and 2x flag exactly the same 30 rows (vs 578 at 1x), so the choice only
  matters for future data; 2x matches the LF `coverage_pct` bound and still catches an extra-digit typo.
  Per-country limits were not needed.
- Every consistency flag's `value` carries the row's numbers: the lhs, the unscaled rhs from the data and,
  for `<=`/`>=`/`<`/`>` rules with a non-zero rhs, the raw lhs/rhs percentage
  (`"180,617 vs target_pop 150,000 (120%)"`). A summed rhs is named by its column count. Rules against a
  constant keep just the lhs. The numbers go in `value`, not `issue`, because `issue` must stay the same
  for every row of a rule: the DQ summary groups flags by it.

**Consequences:** far fewer overcoverage flags (578 to 30 on current data). The remaining flags are rows
with target population 0 and two real outliers. Any code reading a consistency flag's `value` as a bare
number would now get text; nothing in the package does (it is only displayed and logged).
