# Summarise the feedback backlog by status

Prints a one-line-per-status count of the tickets in
`_feedback/feedback_log.yaml`, in lifecycle order — the triage-meeting
view of the board. Returns the full backlog tibble (as
[`eri_feedback_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_list.md))
invisibly so it can be piped or inspected.

## Usage

``` r
eri_feedback_board(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, the backlog tibble from
[`eri_feedback_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_list.md).

## See also

[`eri_feedback_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_status.md)
to move a ticket,
[`eri_feedback_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_list.md)
for the rows.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_feedback_board()
} # }
```
