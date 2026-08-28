# Flag cross-field consistency violations defined in a schema

**\[experimental\]**

Evaluates named consistency rules from the schema's `consistency` block
and flags rows where a rule is violated. Each rule specifies a `lhs`
side, a comparison `op`, and a `rhs` side.

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
      gender_sum_matches_type_sum:
        lhs_sum: [male_trained, female_trained]
        op: "=="
        rhs_sum: [new_male_jan, new_fem_jan, refresh_male_jan, refresh_fem_jan, "..."]
        message: "Sum of male+female trained does not equal sum of new+refresher trained"

Each side is exactly one of: a single column (`lhs`/`rhs`), a constant
(`rhs_value`), or a list of columns summed row-wise with `na.rm = TRUE`
(`lhs_sum`/`rhs_sum`) – for a measure with no single annual roll-up
column to compare against another single column, e.g. a monthly-wide
sheet where the total-by-gender columns should equal the sum of many
monthly new/refresher columns. A row where *every* column on a summed
side is `NA` stays `NA` (genuinely no data that side can speak to, not a
fabricated 0) and is skipped like any other `NA` operand; a row where
*some* columns are present and others `NA` treats the missing ones as 0
(a month with nothing reported legitimately contributes 0 to the sum,
same reasoning as `.dq_na_fill()` for a single count column). A summed
side where none of its columns exist in the data at all skips the whole
rule for that side (e.g. a schema shared across several sheet shapes,
where only one prefix's columns are ever populated on a given ingest –
same "not found" skip as a missing `lhs`/`rhs`).

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
