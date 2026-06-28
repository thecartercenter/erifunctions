# Persist data-quality flags to the log backlog

Writes the `$flags` from a
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
result (plus a corrections count) to a YAML log in
`{country}/{disease}/{data_source}[/{data_type}]/logs/` in the `data/`
Azure blob, so the data-quality issues are durable and discoverable by
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md).
Without this,
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
flags exist only in your R session.
[`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
calls this automatically.

## Usage

``` r
eri_dq_log(
  result,
  country,
  disease,
  data_source,
  data_type = NULL,
  period = NULL,
  data_con = NULL
)
```

## Arguments

- result:

  A `dq_result` object returned by
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md).

- country:

  `chr` Country code (e.g. `"uga"`).

- disease:

  `chr` Disease name (e.g. `"oncho"`).

- data_source:

  `chr` The channel (`"surveillance"`, `"programmatic"`, `"research"`).

- data_type:

  `chr` or `NULL` The measure (e.g. `"case"`, `"treatment"`); `NULL`
  (default) writes to the four-axis channel-level `logs/` directory.

- period:

  `chr` or `NULL` Reporting period the data covers (e.g. `"2024-01"`).

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Invisibly, the number of flags logged.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- run_dq_checks(raw, schema)
eri_dq_log(result, "uga", "oncho", "surveillance", period = "2024-01")
} # }
```
