# Data Quality Pipeline

**Deep-dive** · ~15 min · needs: nothing · sandbox-safe: n/a (bundled
schema, offline)

The DQ pipeline is a schema-driven system for cleaning and validating
surveillance data before analysis. A single YAML schema file describes
the expected columns, types, ranges, allowed values, translations, and
cross-field consistency rules for one dataset. The functions
[`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
and
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
then apply those rules automatically, returning a structured `dq_result`
object that distinguishes automated corrections from issues requiring
analyst review.

## Quick start

``` r

library(erifunctions)

# Load the bundled DR malaria case schema (falls back to local if Azure unavailable)
schema <- load_dq_schema("dr", "malaria_case", azcontainer = NULL)

# Run all automated checks
result <- run_dq_checks(raw_data, schema)

# Inspect
result                # calls dq_report() automatically
```

## Schema anatomy

Each schema is a YAML file in `inst/schemas/` (or optionally in Azure
`schemas/`). The key blocks are:

``` yaml
country: dr
disease: malaria_case
version: "1.0"

preprocessing:
  - remove_smart_quotes      # fix curly quotes from Excel
  - strip_column_name_spaces # remove spaces/parens from header row

temporal:
  date_col:  sample_date
  year_col:  year
  cross_check_year_col: year  # flags rows where year != year(sample_date)

columns:
  year:
    required: true
    type: numeric
    aliases: [Year, Año, ano]      # recognised alternative column names
    range: [2000, 2035]

  province:
    required: true
    type: character
    aliases: [Province_Residence, Provincia_residencia]
    allowed_values: [Distrito Nacional, Santo Domingo, ...]
    translations:                  # auto-corrected silently
      "sto. Domingo": "Santo Domingo"
    corrections:                   # also auto-corrected
      "Sto Domingo": "Santo Domingo"

derived:
  imported_flag:
    formula: "as.integer(province %in% c('Haiti', 'Extranjero', 'Otros'))"

consistency:
  epiweek_valid:
    lhs: epiweek
    op: ">="
    rhs_value: 1
    message: "Epiweek below 1"
  positives_le_tested:
    lhs: n_positive
    op: "<="
    rhs: n_tested
    message: "Positives exceed tested"
```

## What `run_dq_checks()` does

The pipeline runs these steps in order:

1.  **Preprocessing**: removes smart quotes, optionally strips column
    name whitespace, drops rows with a missing year value.
2.  **Alias resolution**: renames recognised alternative column headers
    to the canonical name defined in the schema.
3.  **Required-column check**: adds a `NA`-row flag for any column
    marked `required: true` that is completely absent from the data.
4.  **Type coercion**: converts columns to `numeric`, `date`, or
    `character` as declared; flags values that cannot be coerced.
5.  **Range checks**: flags numeric values outside the `[min, max]`
    range. A column can add `range_when` (`column`/`op`/`value`) to only
    apply its range to rows where another column meets a condition –
    rows where the gate column is missing or `NA` are out of scope, not
    flagged.
6.  **Translations and corrections**: applies the lookup maps silently,
    logging each change to `$log`.
7.  **Allowed-values check**: flags values not in the `allowed_values`
    list.
8.  **NA fill**: fills `NA` in `na_fill`-annotated columns with the
    specified default and logs the change.
9.  **Temporal cross-check**: flags rows where
    `year(date_col) != year_col`.
10. **Derived columns**: evaluates each `formula` with `with(data, ...)`
    and adds the result as a new column.
11. **Aggregate consistency**: for any derived column, checks the
    formula against the existing value and flags discrepancies (useful
    for pre-computed totals).

## Inspecting the result

``` r

# Full formatted report
dq_report(result)

# Access components directly
cleaned <- result$data    # tibble with corrections applied + derived columns
log     <- result$log     # what was changed automatically
flags   <- result$flags   # what needs analyst attention
```

The `$log` tibble records every automated correction:

| row | column   | original_value | corrected_value | rule        | action    |
|-----|----------|----------------|-----------------|-------------|-----------|
| 3   | province | sto. Domingo   | Santo Domingo   | translation | corrected |

The `$flags` tibble records everything requiring review:

| row | column  | value | issue                                  |
|-----|---------|-------|----------------------------------------|
| 12  | epiweek | 55    | Value outside expected range \[1, 53\] |
| NA  | species | NA    | Required column is missing             |

## Anomaly detection

After the baseline checks you can chain additional anomaly detectors.
All three accept either a plain tibble or a `dq_result`, and return the
same type, so they compose with `|>`.

### Period-over-period percent change

``` r

# Aggregate first, then check for unusual week-to-week swings
weekly <- dplyr::count(result$data, year, epiweek, province, name = "n_cases")

result <- result |>
  add_anomaly_pct_change(
    value_col  = "n_cases",
    period_col = "epiweek",
    year_col   = "year",
    group_cols = "province",
    threshold  = 0.5   # flag > 50% change
  )
```

Two columns are added to `$data`: `pct_change_n_cases` and
`anomaly_pct_change_n_cases`. Flagged rows are also appended to
`$flags`.

### Structural gaps

``` r

gaps <- result |>
  add_anomaly_gaps(
    period_col  = "epiweek",
    period_type = "week",
    group_cols  = "province",
    year_col    = "year"
  )
```

Returns a tibble of missing epiweek/group combinations, or appends them
to `$flags` when given a `dq_result`.

### Cross-field consistency rules

``` r

result <- result |> add_anomaly_consistency(schema)
```

Evaluates every rule in the schema’s `consistency:` block against the
cleaned data (including derived columns). Use this after
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
so that derived columns are available.

### Spatial admin name validation

``` r

# Requires Azure access and the sf/terra packages
result <- result |> add_anomaly_spatial(schema)
```

Downloads the reference shapefile from Azure and flags province or
commune names that do not appear in the canonical list. Skipped
gracefully when Azure is unavailable.

## Custom checks

Pass a list of functions to
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
for checks that cannot be expressed in YAML:

``` r

check_no_future_dates <- function(data, log, flags) {
  future_rows <- which(data$sample_date > Sys.Date())
  if (length(future_rows) > 0) {
    flags <- dplyr::bind_rows(
      flags,
      tibble::tibble(
        row    = future_rows,
        column = "sample_date",
        value  = as.character(data$sample_date[future_rows]),
        issue  = "sample_date is in the future"
      )
    )
  }
  list(data = data, log = log, flags = flags)
}

result <- run_dq_checks(raw_data, schema, custom_checks = list(check_no_future_dates))
```

## Exporting results

Once satisfied with the cleaned data, export for downstream use:

``` r

# Parquet for analysis pipelines
arrow::write_parquet(result$data, "data/clean/dr_malaria_clean.parquet")

# Excel summary for review meetings
eri_report_excel(
  sheets = list(
    data  = list(data = result$data,  title = "Cleaned data"),
    flags = list(data = result$flags, title = "Flags for review"),
    log   = list(data = result$log,   title = "Automated corrections")
  ),
  path  = "outputs/dq_review.xlsx"
)
```
