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
      implausible_overcoverage:
        lhs: treated
        op: "<="
        rhs: target_pop
        rhs_scale: 2
        message: "treated is more than 2x target_pop (over 200% raw coverage)"
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
same "not found" skip as a missing `lhs`/`rhs`). A summed side where
only *some* of its columns exist (e.g. a template typo renamed one
month's column) still runs, counting the missing columns as 0, so real
mismatches are still flagged. Because a flag may then come from the
missing column rather than the data (and a pass did not check it), the
rule is also listed in the skipped rules with a `reason` that starts
`"lhs_sum incomplete, ran without"` (or `rhs_sum`) and names the missing
columns, always with `expected = FALSE` (even with `skip_ok`), and each
of its flags ends
`"(checked without <columns>: not found in the data)"`.

Supported operators: `<=`, `>=`, `==`, `<`, `>`, `!=`. Missing values
(`NA`) in either operand skip the check for that row.

`rhs_scale` (optional, one positive number) multiplies a column rhs
(`rhs` or `rhs_sum`) before the comparison, e.g. `rhs_scale: 2` with
`treated <= target_pop` flags only rows where `treated` is more than
twice `target_pop`. It can't be combined with `rhs_value` (write the
scaled constant instead). A rule with an invalid `rhs_scale`, or with a
non-numeric rhs column to scale, is skipped and recorded like any other
skip, with `expected = FALSE`.

Each flag's `issue` is the same for every row of a rule (rule name and
message). Its `value` holds that row's numbers: the lhs value and, when
the rhs is a column, the rhs value from the data (before any
`rhs_scale`), e.g. `"180,617 vs target_pop 150,000 (120%)"`. The
percentage (lhs as a share of rhs) is shown for `<=`, `>=`, `<` and `>`
rules when the rhs is not 0. A summed rhs is named by its column count
(`"vs sum of 48 columns ..."`). A rule against a constant (`rhs_value`)
shows just the lhs value.

Works on a plain tibble (returns a tibble of violations) or a
`dq_result` (appends violations to `$flags`).

A rule that cannot be evaluated at all (a column it needs is missing
from the data) is skipped with a console message **and recorded**, so
"the rule did not run" can be told apart from "the rule ran and found
nothing": on a `dq_result` the skips are appended to `$skipped_rules`
(columns `rule`, `reason`, `expected`); on a plain tibble they are
returned in `attr(<result>, "skipped_rules")` (dplyr verbs such as
[`filter()`](https://rdrr.io/r/stats/filter.html) can drop that
attribute – read it straight off the returned value). A rule written for
one sheet layout can set `skip_ok: true` to say that skipping on another
layout is by design; it is still recorded, with `expected = TRUE`, but
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
reports it as a quiet note rather than a warning.
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
lists the skips after the flags.

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
Skipped rules are reported as described above.

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- load_dq_schema("haiti", "malaria")
run_dq_checks(data, schema) |> add_anomaly_consistency(schema)
} # }
```
