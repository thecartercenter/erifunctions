# ADR-0022 — A duplicate CMR field code blocks the whole workbook, not just its sheet

- **Status:** Accepted — reverses the v0.9.8 decision below
- **Date:** 2026-07-15

## Context

`eri_ingest_cmr()` reads a CMR sheet's row 5 for machine-readable field codes. A real, recurring
defect in the Carter Center master template — first confirmed in Sudan/South Sudan's May 2026
submissions, since also confirmed live in a uga/ssd/nga pilot-session dry run (2026-07-15,
`eri_feedback` ticket via a DA, screenshot on file) — types the same field code twice in one
sheet's row 5 (a copy-paste slip when a monthly block was duplicated), most often on the
"RB Ento Surveys" sheet.

Prior to v0.9.8, this defect aborted the **entire** `eri_split_cmr()` run, not just the affected
sheet — reported at the time as a bug, since it blocked an otherwise-valid submission's other
sheets (oncho/lf/sch treatment data, unrelated to the entomology-survey defect) over one sheet's
template quirk. v0.9.8 (`eb2b5530`/`863eb5e9`) changed this to select columns by position, warn,
and continue: the duplicate column is kept and uniquified (`__1`, `__2`, ...), and every other
sheet — including the affected one — still routes and stages normally.

Pilot-session prep surfaced that this tolerant behavior is itself wrong for how DAs actually work:
a CMR submission is reviewed and approved as **one workbook**, not sheet-by-sheet. Letting a known
template defect quietly pass through in one sheet, while the rest of the workbook proceeds to
staging, means a DA can approve a period without ever being forced to notice that sheet's data
went through with a silently-renamed column — and there is no equivalent "whole workbook" DQ gate
that would catch it later, since DQ review operates per measure. Confirmed with the product owner
during pilot-session prep (2026-07-15) that this should block the whole upload instead: a DA
working with a defective workbook needs a corrected file before *anything* from it is staged, not
a partial success they might not notice.

## Decision

`eri_ingest_cmr()` now aborts (not warns) on a duplicate field code. `eri_split_cmr()`'s per-sheet
loop catches this, writes a best-effort `status = "error"` log entry (so the failure is still
visible via `eri_logs()` even though it happens before `eri_split_cmr()`'s own op-log would
normally be written), and re-raises — aborting the whole run before any sheet is staged, dry run
or real. This reverts the v0.9.8 relaxation and restores the pre-v0.9.8 behavior, now with an
explicit rationale and a logged trail (which the pre-v0.9.8 behavior never had).

## Consequences

- **Easier:** a DA can never approve a workbook that silently passed through a known template
  defect without seeing it; the failure is unmissable (a hard error) and has an audit trail (the
  logged entry), neither of which the pre-v0.9.8 behavior had.
- **Harder / accepted:** since "RB Ento Surveys" duplicate field codes are a **recurring,
  template-wide defect** (not country-specific — confirmed in sdn, ssd, and now uga), this will
  likely block a meaningful share of real CMR uploads until Carter Center's template maintainers
  fix the master template at the source. That blast radius is the explicit trade-off being
  accepted here, in exchange for never letting the defect pass through unnoticed. A DA hitting
  this is expected to flag it to whoever maintains the CMR template and get a corrected file
  before retrying, per the error message.
- **Not doing:** any per-sheet allowlist or auto-repair of known-defective sheets (e.g. silently
  fixing "RB Ento Surveys" specifically) — the template defect belongs fixed at the source, not
  tolerated indefinitely in the ingest code.

## References

- Reverses the tolerant behavior introduced in v0.9.8 (`eb2b5530`/`863eb5e9`,
  "Sudan/South Sudan pilot").
- `R/cmr.R`'s `eri_ingest_cmr()` and `eri_split_cmr()`.
- **Working around the abort for schema authoring:** a sheet blocked by this ADR can still
  have specific columns (e.g. a district list) read directly via
  `readxl::read_excel(path, sheet = sheet, skip = 4, col_names = TRUE)` — bypassing
  `eri_ingest_cmr()` entirely, since only that ADR's duplicate-code *dedup* logic (not raw
  Excel reading) is affected. Used in v0.9.40 to source real `allowed_values` for
  `uga_oncho_programmatic_entomology.yaml`/`eth_oncho_programmatic_entomology.yaml` while
  their "RB Ento Surveys" sheet was still blocked. Reach for this before leaving a schema
  column unconstrained "pending a template fix."
