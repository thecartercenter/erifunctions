# ADR-0010 — ODK repeat groups land as a relational set of tables, approved together

- **Status:** Accepted — point 4 amended by [ADR-0017](0017-odk-zero-row-parent-clears-raw-set.md)
- **Date:** 2026-06-26

## Context

Most real ODK forms have **repeat groups** — a section the enumerator fills in more than once per
submission (several larvae sampled at one site, several household members per visit, several nets per
household). ODK Central exports such a form as **multiple tables** inside `submissions.csv.zip`: a
parent `{form_id}.csv` (one row per submission) plus one child `{form_id}-{repeat}.csv` per repeat
group (one row per repeat instance), linked by a `PARENT_KEY` column whose value matches the parent
row's `KEY`.

Until PR #168, `download_odk_form()` read only the parent CSV and `eri_odk_sync()` wrote a single
Parquet, so **repeat data was silently dropped**. PR #168 fixed the capture (a `tables` flag on
`download_odk_form()`; `eri_odk_sync()` writes one Parquet per export table into `…/odk/raw/`). That
change introduced a structural fact that nothing in the canon yet governs: **a single ODK form can now
land as several files in `raw/`**, and Phase 4 (ODK live pilot — cleaning rules, edit tracking, the
survey dashboard) will be built on top of that shape. This ADR fixes the contract before that work
starts, so staging, cleaning, and the catalog all assume the same model.

## Decision

**An ODK form's submissions are stored in `raw/` as a faithful relational *set* of tables — one
Parquet per ODK export table — and that set is the unit that moves through the pipeline together.**

1. **Lossless relational shape, no flattening on ingest.** `eri_odk_sync()` writes each export table
   verbatim: `{form_id}.parquet` (parent, one row per submission) and `{form_id}-{repeat}.parquet`
   for each repeat group (one row per instance). We do **not** denormalize into one wide table on
   sync — flattening duplicates every parent field across its repeats, is lossy for multiple/nested
   repeats, and discards the `PARENT_KEY` ↔ `KEY` relationship that ODK Central itself uses.
   Consumers that want a flat frame rejoin downstream (`left_join(child, parent, by = c("PARENT_KEY"
   = "KEY"))`), as the DA ODK guide shows.

2. **The relationship lives in the data, not in file order.** `PARENT_KEY` → `KEY` is the only link
   that matters. Child tables are named by their export CSV and ordered incidentally (alphabetically,
   parent first); no code or consumer may depend on child ordering or count to reconstruct the
   relationship.

3. **A form's tables are approved as a set, for one period.** When this raw set is staged and approved
   (the same `raw → staged → processed` human gate — CLAUDE.md core model, with approver integrity per
   ADR-0003), the parent and all its children move **together** — you never approve a parent without
   its children, or vice versa.
   Referential integrity (every `PARENT_KEY` resolves to an approved parent `KEY`) is a property the
   approval gate preserves; the catalog records the set as belonging to one form/period.

4. **No parents, no set.** If the parent table has zero rows, nothing is written (the existing
   warn-and-return behavior) — children cannot exist without parents, so an empty parent means an
   empty sync. *(Amended by [ADR-0017](0017-odk-zero-row-parent-clears-raw-set.md): this is now the
   `overwrite = FALSE` behavior only. By default (`overwrite = TRUE`), a zero-row parent instead
   clears the whole raw set — parent and any orphaned children — to match the source.)*

## Consequences

- **Easier (and what Phase 4 can now assume):**
  - **Cleaning rules** (the on-read layer, roadmap Phase 4) apply per table; a rule that needs
    parent + child context operates on the joined view, not on a pre-flattened blob. `raw/` stays
    pristine and relational underneath.
  - **Edit tracking** keys naturally off the submission `KEY` at the parent; child edits ride along
    via `PARENT_KEY`.
  - **The survey dashboard** consumes the joined view, with parent-level and repeat-level metrics
    cleanly separable.
  - **Nested repeats** (a repeat within a repeat) export as further `{form_id}-{outer}-{inner}.csv`
    tables and are captured by the same "read every CSV" logic with no special-casing.
- **Harder / accepted:**
  - A form is now *several* catalog/processed artifacts, not one. Staging and approval must treat the
    set atomically; the precise set-aware mechanics (how `eri_approve()` groups a form's tables for a
    period, and how the catalog labels them as one form) are **implemented when Phase 4 staging is
    built** — this ADR fixes the model they must honour, not the code.
  - Downstream analysis must perform an explicit join to get a flat frame; the guide teaches this so it
    is a known step, not a surprise.
- **Not doing:**
  - Flattening/denormalizing ODK data into one wide table on sync (lossy; rejected above).
  - A relational database for ODK data — storage stays Parquet-in-blob with YAML metadata (ADR-0002);
    DuckDB remains a read-side query layer only (ADR-0004).
  - Auto-joining on read — the relational set is the stored truth; joins are explicit and downstream.

## References

- PR #168 — repeat-group capture (`download_odk_form(tables=)`, multi-table `eri_odk_sync()`).
- CLAUDE.md "Core model" — the `raw → staged → processed` human gate this set travels through;
  ADR-0003 — approver identity/integrity at that gate.
- ADR-0002 — YAML metadata concurrency rules the catalog/registry follow.
- `docs/roadmap.md` Phase 4 — ODK live pilot (cleaning rules, edit tracking, dashboard) built on this
  shape.
