# ADR-0019 — A zero-row ODK parent clears the whole raw set, by default

- **Status:** Accepted — amends [ADR-0010](0010-odk-repeat-group-tables.md) point 4
- **Date:** 2026-07-14

## Context

ADR-0010 point 4 says: *"If the parent table has zero rows, nothing is written (the existing
warn-and-return behavior) — children cannot exist without parents, so an empty parent means an
empty sync."* That was written to guard against a transient ODK Central API failure being
mistaken for real data loss and silently wiping a good raw set.

In practice it has the opposite failure mode: it also treats a **genuine deletion at the ODK
source** as nothing-to-do. A DA who deletes test/bad submissions in ODK Central and re-syncs sees
"0 records downloaded" (proof the deletion worked), but `eri_odk_sync()` skips the Azure write
entirely — the raw Parquet(s) from the last non-empty sync stay in place, silently feeding stale
data to anything reading `raw/` (a survey dashboard, in the reported case: issue #303, Uganda
TAS-3 — a live-blob audit during remediation confirmed 23/19/16/27 stale rows still sitting in
Azure across four tables, despite the DA's resync having confirmed 0 records at the source).
`overwrite = TRUE` was already a parameter on `eri_odk_sync()`, documented as "whether to
overwrite an existing Parquet file," but was never wired to this decision.

## Decision

`eri_odk_sync(..., overwrite = TRUE)` (the default) now treats a zero-row parent pull as **the
current true state of the source**, not a suspected failure, and clears the entire raw set for
that form to match:

1. Every table returned by the pull (normally just the parent, since a form with a 0-row parent
   has no submissions to have repeat instances) is written through as-is, including empty.
2. **Any table already in `raw/` for this `form_id` that the pull did *not* return — a repeat
   group whose export CSV ODK Central omits once its parent is empty — is deleted**, not left
   behind. This is the direct extension of ADR-0010 point 3 ("the parent and all its children move
   together... you never approve a parent without its children, or vice versa") into the
   zero-row case: a surviving child Parquet with `PARENT_KEY`s pointing at submissions that no
   longer exist is exactly the orphaned-relational-set state ADR-0010 exists to prevent, just
   reached from the empty-parent direction instead of a partial-sync failure.
3. `overwrite = FALSE` restores ADR-0010 point 4's original behavior verbatim (skip and warn,
   touch nothing in Azure) for a DA who has reason to suspect a transient API failure rather than
   a real deletion, and wants to protect the existing raw set until they've confirmed which it is.

Points 1–3 of ADR-0010 (lossless relational shape, relationship lives in `PARENT_KEY`/`KEY` not
file order, a form's tables approve as one set) are unchanged and still govern the non-empty case.

## Consequences

- **Easier:** `raw/` no longer silently diverges from ODK Central. A DA's delete-and-resync
  workflow (cleaning up test data, correcting a bad submission batch) now does what it looks like
  it does, without a manual blob cleanup step.
- **Harder / accepted:** a transient ODK Central failure that happens to return 0 rows will, under
  the new default, clear a real raw set. This is the tradeoff ADR-0010 point 4 was written to
  avoid; `overwrite = FALSE` is the escape hatch for a DA who wants the old guard, but it is opt-in
  now rather than the default. Azure blob deletes are not soft — there is no undo below whatever
  retention/versioning the storage account itself provides.
- **Not doing:** validating *why* the pull returned zero rows (e.g. distinguishing "ODK confirms 0
  submissions" from "the API call degraded to an empty response") — ODK Central's submissions
  export does not currently give `download_odk_form()` a signal to tell those apart. If that
  changes, this ADR should be revisited rather than the distinction bolted on top of `overwrite`.

## References

- ADR-0010 — the relational-set model this amends point 4 of.
- Issue #303 / PR #304 — the reported bug and fix.
