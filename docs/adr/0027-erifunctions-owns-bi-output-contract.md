# ADR-0027 — erifunctions owns the Power BI output contract

- **Status:** Accepted — supersedes [ADR-0015](0015-hsp-mal-cutover-criteria.md)
- **Date:** 2026-08-28

## Context

[ADR-0015](0015-hsp-mal-cutover-criteria.md) set the Phase 3 cutover gate: run the new pipeline in
parallel with the legacy contractor pipeline, reconcile each period with
[`eri_compare()`](../../R/compare.R), and retire the legacy adapters once a stream reached N=3
consecutive equivalent periods.

The data science consultancy that built and operated the legacy pipelines
(`health-hsp-malaria`, `health-rb-country-expansion`) ended in August 2026. Ingesting its close-out
established three things that undo that gate.

**1. The reference side of the comparison has no operator.** ADR-0015's gate compares our
`data/staged` output against `projects/…/intermediate/`, which is *produced by the contractor
pipeline*. The parallel run therefore requires someone to keep running that pipeline every period
for at least three periods. Nobody was assigned to, and assigning someone would extend the legacy
system's life by months to earn evidence for retiring it. This is a staffing and cost judgement,
not a structural impossibility — the gate could be satisfied if we chose to staff it. We are
choosing not to.

**2. There is no continuity risk for the gate to protect against.** All the repositories are
org-owned and already administered by the ERI team, the pipelines are `workflow_dispatch` GitHub
Actions, and credentials were handed over. We can run everything the contractor ran. The gate was
designed to de-risk losing a system we are not losing.

**3. The real constraint is a contract, not a pipeline.** The DAs are ready to work entirely in
erifunctions. What must not break is that outputs keep landing where Power BI reads them. For the
RBLF programme that is three files; for Hispaniola malaria it is one CSV bound onto a frozen
history. That is a much smaller and more precisely testable obligation than pipeline equivalence.

## Decision

**erifunctions produces the Power BI inputs directly**, and the contractor pipeline is consolidated
into erifunctions in stages rather than retired against a streak.

1. **The RBLF contract is three files** in the `projects` container:

   ```
   {blob_prefix}/BI_inputs/all_treatment.parquet    # discriminator column: disease
   {blob_prefix}/BI_inputs/all_training.parquet     # discriminator column: type
   {blob_prefix}/BI_inputs/all_dmdi.parquet
   ```

   `{blob_prefix}` is the pipeline's per-environment folder root, `health-rb-country-expansion-dev`
   or `health-rb-country-expansion`. `eri_ingest(mirror_pipeline=)` already writes the
   `intermediate/` layer immediately upstream, so the gap is one consolidation step. The full
   contract — sheet groupings, the prefix-strip map and its collision rule, protected columns — is
   specified outside this repo because it names infrastructure detail that does not belong in a
   public repository.

2. **The Hispaniola malaria contract is specified separately.** It is a different shape: Power BI
   reads `intermediate/dom/dr_malaria_2015_current.csv` directly, and that file binds the current
   snapshot onto a frozen 2015–2024 history.

3. **`projects/` is a live system of record, not legacy space.** erifunctions writes to it
   deliberately. Container selection must therefore be explicit at the call site rather than
   inherited from an environment variable — see the open work on the DAL container default.

4. **ADR-0015's equivalence streak is superseded.** Correctness of the BI outputs is established by
   comparing our three files against the contractor consolidation's output over the same inputs,
   once, before cutover — not by an accruing multi-period streak.

5. **Legacy adapter retirement is gated on the cutover, not on a streak.** The `mirror_pipeline`
   dual-write, `.eri_pipeline_registry`, `.eri_schema_country_map`, and the `rblf` combined code
   come out once erifunctions writes the BI outputs and the contractor pipeline no longer needs our
   raw-drop upload.

## Consequences

**Good.** The obligation is now small, explicit, and testable: three files with a known schema,
rather than equivalence across a whole intermediate layer. It does not require anyone to operate a
system we are replacing. It also removes the round-trip in which `eri_do("cmr")` writes the DA's
workbook into the contractor's raw drop and reads it back to build the governed `data/` copy.

**Good.** Onboarding a country no longer requires a matching entry in a second repository's template
config, which has already drifted once.

**Bad.** erifunctions takes on the consolidation logic, including behaviour that looks redundant and
is not — most notably the prefix-collision coalescing that keeps historical columns aligned across a
template's prefix rename. Reimplementing it carelessly loses history silently rather than loudly.

**Bad.** Writing to `projects` deliberately means a bug in erifunctions can now corrupt a live
dashboard feed. That is the reason for consequence 3 above.

**Inert, not removed.** The cutover ledger and its helpers (`eri_cutover_check()`,
`eri_cutover_status()`, `_cutover/cutover_log.yaml`) stay in place and stop accruing. Because
`eri_do()` derives `mirror_pipeline` from `eri_cutover_status()$eligible`, eligibility never being
met means the wizard keeps mirroring — which is exactly the behaviour required until the BI cutover
lands. This fails safe, but their user-facing documentation still describes the retired gate and
needs updating.

**Deferred, deliberately.** The reporting chain (the RBLF report publish triggering the malaria
repo's site publish, which deploys the portal) stays contractor code until the reporting stage. The
template-config duplication stays until its own stage. Neither is "not considered".

## More information

The staged plan and its tracking live in [`docs/roadmap.md`](../roadmap.md) Phase 3.
