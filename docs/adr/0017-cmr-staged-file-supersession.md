# ADR-0017 — Superseding staged CMR files: opt-in delete, anchored match

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

A DA fixing a DQ issue in a monthly CMR workbook is expected to save a corrected copy locally (the
`_fixed.xlsx` convention) rather than overwrite the original, so the true-as-submitted file is always
preserved. Re-running [`eri_split_cmr()`](../../R/cmr.R) against that corrected copy for a period
already split previously left the broken original's staged parquet sitting **alongside** the
corrected one in each destination folder — [`eri_approve()`](../../R/dal.R) promotes by a period
match against the staged filenames, so it would promote **both** to `processed/`.

Fixing this means `eri_split_cmr()` needs to identify and remove a prior staged file for the same
period when a re-split supersedes it. This is the **first place in erifunctions that deletes
previously-staged data as a side effect of a routine operation** — every other write path in the
package is additive (stage, approve, log), with [`eri_approve()`](../../R/dal.R) as the only existing
human gate, and that gate is about promotion, not deletion. A destructive operation needs its own,
deliberate policy, not an incidental default buried in a bug fix.

Two risks came up in review:

1. **Collision risk in matching "the same period."** `programmatic/{data_type}/staged/` is not
   partitioned by period — every period's files for a given country/disease/measure share one flat
   folder (per [ADR-0012](0012-source-measure-data-model.md)'s five-axis path model). Filename is the
   only signal available. An unanchored substring match on the six-digit period (e.g. "does this
   filename contain `202605` anywhere") can hit an unrelated file that happens to mention those digits
   for a different reason (a date, a facility code, a different upload entirely) and delete it.
2. **No undo.** Unlike promotion to `processed/` (inspectable, and gated by a human decision), a
   delete from `staged/` has no equivalent checkpoint and nothing in the package manages Azure
   soft-delete/versioning as a safety net.

## Decision

1. **Match the real filename convention, anchored, not an unanchored substring.** A candidate stale
   file's basename must **start with** the period (`^{period}(?!\d)`, a negative lookahead so a longer
   number that happens to start the same way — e.g. `2026050` doesn't falsely match period `202605`),
   matching the actual convention observed in real submissions and everything this package generates
   (`{period}_...`, the mirror upload's `{country}_{period}_{timestamp}`). A file that merely mentions
   the period elsewhere in its name is never a candidate.
2. **Detection is unconditional; deletion is opt-in.** Whenever `period` is resolved, `eri_split_cmr()`
   always looks for anchored-match candidates in each destination folder and reports them. Whether
   they're actually removed is gated by a new parameter, `supersede_staged` (default `FALSE`): the
   default only warns, listing exactly what would be removed and why; passing `TRUE` performs the
   delete. **Destructive behavior in this package requires an explicit, per-call opt-in — it is never
   the default**, mirroring the spirit of `eri_approve()` being a deliberate human action rather than
   an automatic promotion.
3. **No period, no action.** If `period` can't be resolved (no `YYYYMM_` prefix and none passed), the
   whole detection/deletion path is skipped — silently reverting to the pre-fix behavior (both files
   left in `staged/`) rather than guessing. The existing "could not resolve a period" warning already
   flags this case; a DA who wants a re-split's supersession to work must supply `period` explicitly
   if their filename doesn't carry it.
4. **Every removal is logged.** A `supersede_staged` op-log step records exactly what was deleted, on
   the same run that deleted it — an auditable trail, not a silent side effect.

## Consequences

- **Easier:** the duplicate-promotion bug is fixed without introducing automatic, unreviewed deletion;
  a DA re-splitting a corrected file sees exactly what's superseded before choosing to remove it.
- **Harder:** removing a stale file now takes an explicit `supersede_staged = TRUE`, not just a
  re-split — one extra argument to know about, documented in the CMR guide and the function's own
  `@param` doc.
- **Not doing:** anything that manages Azure blob versioning/soft-delete on erifunctions' behalf (out
  of scope; if the storage account has it enabled, deletes are recoverable there regardless), and not
  adding a general-purpose "delete stale files" utility beyond this one CMR-specific case — a broader
  need should get its own ADR, not inherit this one's scope.
- **Precedent for any future destructive operation in this package:** anchor matches to the narrowest
  signal that's actually true of the real data (not the broadest substring that happens to work),
  default to detect-and-report, and require an explicit opt-in to actually delete.
