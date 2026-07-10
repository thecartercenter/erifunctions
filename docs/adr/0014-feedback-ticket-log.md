# ADR-0014 — In-package feedback / ticket log

- **Status:** Accepted — capture implemented 2026-06-29 (#237); triage 2026-06-29 (#239)
- **Date:** 2026-06-29

## Context

Adoption by Data Analysts and Epidemiologists hinges on a tight feedback loop: when a user hits
friction we need it captured in the moment, attributed, and durable enough to triage later. Email,
chat, and verbal reports are none of those — they are unattributed, scattered, and lost. We want the
lowest-friction possible capture (one line from R, where the user already is) feeding a single backlog
the team can work through.

This is the **capture** half of an internal ticketing system. The **triage** half — moving a ticket
through a status lifecycle and reporting progress back — is a separate, later feature; pinning the
store and schema now lets that feature build on a stable shape.

## Decision

Add `eri_feedback(message, area)` that appends a ticket to a single YAML log,
`_feedback/feedback_log.yaml`, in the `data/` blob, and `eri_feedback_list()` that reads it.

- **One store, same conventions as the other metadata blobs** (`_catalog/`, `odk/`, `artifacts/`):
  a single underscore-prefixed YAML with an `entries` list.
- **Reuse, don't reinvent.** The append goes through `.eri_yaml_update()` (ADR-0002), so it is
  concurrency-safe and the auto-incrementing `id` — computed inside the mutate against the freshly
  re-read log — stays unique even when two people file at once. The author is the **verified**
  identity from `.eri_analyst_id()` (ADR-0003), not a self-declared name.
- **Ticket schema:** `id`, `submitted_at` (UTC), `submitted_by` (verified), `area`, `status`,
  `message`. `area` is `"general"` or a section (`"odk"`, `"ingest"`, `"reporting"`, …); it is free
  text (a typo must never reject a user's feedback) with a non-blocking nudge toward the known set so
  the vocabulary self-converges for triage. Two optional fields (added in the DQ workflow redesign,
  phase 4; see [ADR-0018](0018-dq-schema-local-overrides.md)) are present only when actually used, so
  a ticket filed without them is byte-for-byte the shape above: `context` (a named list scoping the
  ticket to a specific dataset/object, e.g. the four ADR-0012 axes) and `attachment` (a blob path
  under `_feedback/attachments/{token}/`, uploaded *before* the log append — a failed upload aborts
  before any ticket exists; the converse, an upload that succeeds followed by a log-append failure,
  is an accepted low-probability gap that leaves an orphaned blob with no automatic cleanup, per
  `eri_feedback()`'s own `@param attachment` doc).
- **Status lifecycle:** tickets are born `"submitted"`. Advancing them (`planned`, `in_progress`,
  `fixed`, `declined`) is the job of the triage surface — `eri_feedback_status(id, status, note)` (which
  records a who/when/from/to audit entry on the ticket's `history`) and `eri_feedback_board()` (the
  per-status summary) — **not** `eri_feedback()`. `status` is a controlled set; `area` is not.

## Consequences

- **Easier:** a user files friction in one line without leaving R; every ticket is attributable and in
  one place; the triage feature has a stable store and schema to build on.
- **Harder:** introduces a fifth shared metadata store to keep healthy (mitigated by reusing the
  ADR-0002 write path rather than a new mechanism).
- **Not doing now:** assignment/owners or a graphical tracking UI — the status lifecycle ships
  (`eri_feedback_status()`), but assignment and a richer board can follow. Not standing up an external
  issue tracker; the blob stays the system of record, consistent with ADR-0004.
