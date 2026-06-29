# Move a feedback ticket through the triage lifecycle

Updates the `status` of one ticket in `_feedback/feedback_log.yaml` and
records an audit-trail entry of the transition (from, to, who, when, and
an optional note). This is the triage side of the feedback log
(ADR-0014): file a ticket with
[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md),
then move it as you work it — typically `submitted` -\> `planned` -\>
`in_progress` -\> `fixed` (or `declined`).

## Usage

``` r
eri_feedback_status(id, status, note = NULL, data_con = NULL)
```

## Arguments

- id:

  `int` The ticket id (as shown by
  [`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md)
  /
  [`eri_feedback_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_list.md)).

- status:

  `chr` The new status. One of submitted, planned, in_progress, fixed,
  declined.

- note:

  `chr` or `NULL` An optional one-line note recorded with the transition
  (e.g. a PR number or a reason for `declined`).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The updated ticket (invisibly), as a named list (including its
`history`).

## Details

The change records the **verified** signed-in actor (ADR-0003) and is
concurrency-safe (ADR-0002). The status is validated against the
controlled lifecycle; an unknown id aborts without writing.

## See also

[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md)
to file,
[`eri_feedback_board()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_board.md)
to summarise.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_feedback_status(142, "planned")
eri_feedback_status(142, "fixed", note = "shipped in #251")
eri_feedback_status(7, "declined", note = "works as intended")
} # }
```
