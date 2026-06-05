# Flag cross-field consistency violations defined in a schema

**\[experimental\]**

Evaluates named consistency rules from the schema's `consistency` block
and flags rows where a rule is violated. Each rule specifies a `lhs`
column, a comparison `op`, and either a `rhs` column or a `rhs_value`
constant.

Schema format (add a `consistency:` block to any YAML schema):

    consistency:
      positives_le_tested:
        lhs: NumMicroPos
        op: "<="
        rhs: NumTestedMicro
        message: "Positive cases exceed tested"
      age_non_negative:
        lhs: Age
        op: ">="
        rhs_value: 0
        message: "Age is negative"

Supported operators: `<=`, `>=`, `==`, `<`, `>`, `!=`. Missing values
(`NA`) in either operand skip the check for that row.

Works on a plain tibble (returns a tibble of violations) or a
`dq_result` (appends violations to `$flags`).

## Usage

``` r
add_anomaly_consistency(data, schema)
```

## Arguments

- data:

  A tibble or `dq_result` object.

- schema:

  Named list from
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md).

## Value

A tibble of violations with columns `row`, `column`, `value`, and
`issue` (includes the rule name and message). If the input is a
`dq_result`, violations are appended to `$flags` and the updated
`dq_result` is returned. Returns an empty tibble when all rules pass.

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("haiti", "malaria")
run_dq_checks(data, schema) |> add_anomaly_consistency(schema)
} # }
```
