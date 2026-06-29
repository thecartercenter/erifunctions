# List logged feedback

Reads the team's feedback backlog from `_feedback/feedback_log.yaml` in
the `data/` Azure blob into a tibble, in the order tickets were filed.
Optional filters narrow by `area` or `status`.

## Usage

``` r
eri_feedback_list(area = NULL, status = NULL, data_con = NULL)
```

## Arguments

- area:

  `chr` or `NULL` Filter to one section (e.g. `"odk"`). `NULL` = all.

- status:

  `chr` or `NULL` Filter by status (e.g. `"submitted"`). `NULL` = all.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

A tibble with columns `id`, `submitted_at`, `submitted_by`, `area`,
`status`, `message`.

## See also

[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md)
to file a ticket.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_feedback_list()
eri_feedback_list(area = "odk")
eri_feedback_list(status = "submitted")
} # }
```
