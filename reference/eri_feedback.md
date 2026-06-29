# Log a piece of feedback to the shared ticket log

Appends a ticket to `_feedback/feedback_log.yaml` in the `data/` Azure
blob — the team's lightweight internal backlog. Use it to flag anything:
a bug, a rough edge, a wish, or a general comment, either about the
system as a whole (`area = "general"`) or about a specific part of it
(e.g. `area = "odk"`).

## Usage

``` r
eri_feedback(message, area = "general", data_con = NULL)
```

## Arguments

- message:

  `chr` The feedback itself. A single non-empty string.

- area:

  `chr` Which part of the system this is about. `"general"` (default)
  for system-wide feedback, or a specific section — suggested values:
  ingest, dq, catalog, query, odk, cmr, reporting, research, spatial,
  auth, docs, other. Free text is accepted; the value is lower-cased.

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
to read the backlog.

## Examples

``` r
if (FALSE) { # \dontrun{
# System-wide feedback
eri_feedback("The onboarding guide's Week 1 felt too fast.")

# Feedback about a specific section
eri_feedback("ODK sync timed out on the big LF form.", area = "odk")
} # }
```
