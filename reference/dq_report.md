# Print a formatted DQ summary report

Prints an analyst-readable summary of a `dq_result` object, including
data shape, corrections applied by column, and flagged issues grouped by
type. Called automatically when a `dq_result` is printed.

## Usage

``` r
dq_report(result)
```

## Arguments

- result:

  A `dq_result` object returned by
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md).

## Value

Invisibly returns `result`.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- run_dq_checks(raw_data, schema)
result          # print method calls dq_report automatically
dq_report(result)
} # }
```
