# ADR-0013 — Submission backfill: erifunctions writes records *into* ODK Central

- **Status:** Accepted
- **Date:** 2026-06-28

## Context

Every ODK function in the package so far moves data **out of** ODK Central: `download_odk_form()`
pulls submissions, `eri_odk_sync()` lands them in `raw/`. But the team also needs the **other
direction** — taking a table of already-collected records (paper forms, a legacy spreadsheet, data
captured in another system) and **creating them as submissions** on an existing ODK Central form, so
that history lives in ODK Central alongside genuine field submissions and flows through the same
`raw → staged → processed` pipeline thereafter.

The ODK Central API supports this (verified):

- `POST /v1/projects/{projectId}/forms/{xmlFormId}/submissions`, `Content-Type: application/xml` (or
  `text/xml` — Central accepts both), body = one **XML instance** per submission. There is **no bulk
  endpoint** — submissions are created one at a
  time (a loop, as with every other `eri_odk_*` call).
- Each submission carries a `<meta><instanceID>`. Re-POSTing an existing instanceID returns **HTTP
  409**; the form must be **published**; **attachments cannot be supplied at creation** (a separate
  per-submission endpoint adds them afterward).
- `GET .../forms/{id}/fields` returns the flat `{name, path, type}` field list (the column→element
  map); `GET .../forms/{id}.xml` returns the XForm, whose **primary-instance template** carries the
  exact root element, its `id`/`version` attributes, and the group/repeat nesting, plus inline select
  choices.

Writing *into* the field-data system of record is a new kind of action for this package, and
backfilled rows are, by definition, not genuine device captures. That raises provenance and
idempotency questions that should be settled before the code lands, rather than discovered later.
This ADR fixes the contract; the implementation is `eri_odk_upload()` (issue #211).

## Decision

**`erifunctions` may create submissions on a published ODK form from a tabular extract, under four
rules that make the operation safe, repeatable, and auditable.**

1. **Deterministic instanceID → idempotent by construction.** Each row's `<meta><instanceID>` is
   derived deterministically from the row's content (a hash of a caller-named key column, or of the
   whole row when none is given), not a fresh random UUID. Re-running the same extract therefore
   re-derives the same ids, and ODK Central's **HTTP 409** rejects the duplicates — so a re-run is a
   safe no-op (`skipped`), never a silent double-load. Idempotency is a property of the id scheme, not
   of caller discipline.

2. **The form schema is the source of truth; columns map by field name.** The upload reads the live
   form's `/fields` schema and `.xml` template and maps **input columns to fields by name**, using the
   same convention `download_odk_form()` emits — groups flattened as `group-field`, repeat groups as
   separate child tables linked `PARENT_KEY` → parent `KEY`. A `download_odk_form(tables = TRUE)`
   export is thus a valid input: **download ↔ upload round-trips**. Columns that don't resolve to a
   field, and required fields with no column, are reported — never guessed.

3. **Repeats reuse the ADR-0010 relational shape; the XML is rebuilt from the template.** A form with
   repeat groups is supplied as the same parent + child table set ADR-0010 defines, and the nested
   submission XML is reconstructed by cloning the form's primary-instance template and filling it by
   path (so namespaces, root identity, and version come from the form itself, not from string
   assembly). This is the exact inverse of the relational *capture* ADR-0010 specifies.

4. **Validate first, report per row, never abort the batch.** A `dry_run` pass validates the whole
   extract — column reconciliation, required-field presence, type/format coercion (dates → ISO,
   geopoints → `lat lon alt acc`, numeric ints/decimals), and **best-effort** select-value checks
   (inline choices parsed from the form XML; silently skipped when choices are external/dataset-backed
   and cannot be extracted) — and POSTs nothing. A real run reports a **per-row outcome**
   (`created` / `skipped` (409) / `failed` + message) and continues past a bad row rather than failing
   the whole load.

## Consequences

- **Easier:**
  - A paper/legacy backfill becomes one governed call, and the result lands in `raw/` ready for the
    normal pipeline (`eri_odk_sync()` then DQ → approve).
  - Re-running after fixing a few rows is safe: the good rows 409-skip, only the corrected ones load.
  - The download/upload symmetry means a DA can pull a form, correct it, and push it back with no
    bespoke transformation, and the guide can teach that round-trip.
- **Harder / accepted:**
  - We take a dependency on `xml2` (new in Imports) to build and parse instance XML robustly.
  - Best-effort choice validation will not catch invalid values for forms using external/dataset
    choices; those surface as ODK-side `failed` rows at POST time instead. Accepted for v1.
  - Backfilled submissions are real submissions in ODK Central; their non-field origin is recorded
    only in the upload's operation log, not stamped on the submission. Acceptable — the alternative
    (mutating the form to carry a provenance field) is out of scope.
- **Not doing:**
  - **Attachments on creation** — the REST submission endpoint excludes them; out of scope.
  - **Form-definition upload** (XLSForm → a new ODK form) — a different endpoint and a separate
    feature; this ADR is only about *submissions*.
  - **An explicit arbitrary-header `mapping` argument** (for extracts whose columns don't follow the
    download convention) — deferred to a fast-follow; v1 requires field-name-matching columns.
  - **Random per-row UUIDs** — rejected; they make re-runs duplicate (rule 1).

## References

- Issue #211 — `eri_odk_upload()`.
- ADR-0010 — ODK repeat groups as a relational set of tables (the shape reused here, inverted).
- ADR-0003 — approver identity at the governance gate the backfilled data later passes through.
- CLAUDE.md "Core model" — the `raw → staged → processed` pipeline backfilled data joins.
- `docs/roadmap.md` Phase 4 — ODK live pilot ("Submission backfill" bullet).
