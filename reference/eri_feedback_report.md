# Write a weekly feedback report (HTML or markdown)

Renders the feedback backlog from `_feedback/feedback_log.yaml` to a
self-contained file: a status **board**, then a weekly digest — **new**
tickets filed within `since_days`, tickets **closed** (fixed/declined)
within `since_days` with their closing note, and the **open** backlog in
lifecycle order. Built for a quick standing review so the team stays
current (ADR-0014).

## Usage

``` r
eri_feedback_report(
  file = NULL,
  format = c("html", "md"),
  since_days = 7,
  data_con = NULL
)
```

## Arguments

- file:

  `chr` or `NULL` Output path. If `NULL`, writes
  `feedback-report-<date>.<ext>` in the working directory (a same-day
  re-run overwrites it).

- format:

  `chr` `"html"` (default, self-contained, open in a browser) or `"md"`
  (GitHub-flavoured markdown).

- since_days:

  `num` The digest window in days. Default `7` (a weekly report).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The output file path (invisibly).

## See also

[`eri_feedback_board()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_board.md)
for the console summary,
[`eri_feedback_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_status.md)
to triage.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_feedback_report()                       # feedback-report-<today>.html
eri_feedback_report(format = "md", since_days = 14)
} # }
```
