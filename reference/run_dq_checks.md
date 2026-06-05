# Run data quality checks on surveillance data

Applies a sequence of automated DQ checks defined by a schema:
preprocessing (smart-quote removal, column-name stripping, empty-row
dropping), column alias resolution, required-column validation, type
coercion, range checks, categorical translations and corrections, NA
filling for count columns, temporal cross-checks, derived column
computation, and aggregate consistency checks. Additional
analyst-supplied checks can be appended via `custom_checks`.

## Usage

``` r
run_dq_checks(data, schema, custom_checks = list())
```

## Arguments

- data:

  `data.frame` or `tibble` of raw surveillance data.

- schema:

  Named list returned by
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md).

- custom_checks:

  `list` of functions, each with signature `function(data, log, flags)`
  returning a named list with those same three elements. Applied in
  order after all automated checks.

## Value

A named list with three elements:

- `$data`: cleaned tibble with corrections applied and derived columns
  added

- `$log`: tibble of automated corrections (columns: `row`, `column`,
  `original_value`, `corrected_value`, `rule`, `action`)

- `$flags`: tibble of issues requiring analyst review (columns: `row`,
  `column`, `value`, `issue`)

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("dominican_republic", "malaria")
result <- run_dq_checks(raw_data, schema)
dq_report(result)
} # }
```
