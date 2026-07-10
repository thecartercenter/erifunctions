# Log a piece of feedback to the shared ticket log

Appends a ticket to `_feedback/feedback_log.yaml` in the `data/` Azure
blob — the team's lightweight internal backlog. Use it to flag anything:
a bug, a rough edge, a wish, or a general comment, either about the
system as a whole (`area = "general"`) or about a specific part of it
(e.g. `area = "odk"`).

## Usage

``` r
eri_feedback(
  message,
  area = "general",
  context = NULL,
  attachment = NULL,
  data_con = NULL
)
```

## Arguments

- message:

  `chr` The feedback itself. A single non-empty string.

- area:

  `chr` Which part of the system this is about. `"general"` (default)
  for system-wide feedback, or a specific section — suggested values:
  ingest, dq, catalog, query, odk, cmr, reporting, research, spatial,
  auth, docs, other. Free text is accepted; the value is lower-cased.

- context:

  `list` or `NULL` Optional named list scoping the ticket to a specific
  dataset or object (e.g.
  `list(country = "sdn", disease = "oncho", data_source = "programmatic", data_type = "treatment", period = "202605", schema = "sdn_oncho_programmatic_treatment")`).
  Stored as a sub-block on the ticket, not new formal arguments, so any
  area can scope its tickets differently without a signature change.
  `NULL` (default) omits it entirely — a ticket with no `context` looks
  exactly like one filed before this feature existed.

- attachment:

  `chr` or `NULL` Optional path to a local file to attach — e.g. a full
  schema override for a `dq` ticket. Uploaded to
  `_feedback/attachments/{token}/{basename}` in the `data/` blob
  **before** the ticket is logged, so a failed *upload* never leaves a
  ticket referencing a file that isn't actually there. The reverse is a
  known, accepted, low-probability gap: if the upload succeeds but the
  log append then fails (e.g. exhausts its concurrency retries), the
  blob is left orphaned with no ticket pointing at it — you'll see the
  error (nothing silently succeeds for you), but there's no automatic
  cleanup sweep for the orphaned attachment. `NULL` (default): no
  attachment.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The logged ticket (invisibly), as a named list.

## Details

Each ticket records **who** filed it (the verified signed-in identity,
not a self-declared name — ADR-0003) and **when**, and is given an
auto-incrementing id. Writes are concurrency-safe (ADR-0002), so two
people filing at once never clobber each other. New tickets start at
`status = "submitted"`; moving a ticket through triage (`planned`,
`fixed`, ...) is handled by the separate tracking workflow, not by this
function.

## See also

[`eri_feedback_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_list.md)
to read the backlog,
[`eri_dq_schema_submit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_submit.md)
for the DQ-schema-specific wrapper.

## Examples

``` r
if (FALSE) { # \dontrun{
# System-wide feedback
eri_feedback("The onboarding guide's Week 1 felt too fast.")

# Feedback about a specific section
eri_feedback("ODK sync timed out on the big LF form.", area = "odk")

# Scoped to a dataset, with an attachment (see eri_dq_schema_submit() for
# the DA-facing wrapper that packages this automatically for schema edits)
eri_feedback("District list is missing a valid admin name.", area = "dq",
             context = list(country = "sdn", disease = "oncho"),
             attachment = "sdn_oncho_programmatic_treatment.yaml")
} # }
```
