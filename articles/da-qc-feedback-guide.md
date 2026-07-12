# Quality-check an extract and give a country feedback

When a country sends a data extract, quality-checking it is only half
the job, the other half is telling them, **specifically and clearly,
what needs fixing**.
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
does both: it **auto-corrects** the safe, unambiguous things (and
records what it changed) and **flags** the rest for a human. The flags
are your feedback to the country.

## The golden rule

> **Auto-corrections are applied and logged; flags are handed back.** A
> correction is something the schema can fix unambiguously (a known
> spelling, a translation). A flag is something only the country can
> resolve (an impossible age, an unknown locality). Never “fix” a flag
> by guessing, send it back.

This is offline, the DQ engine runs on a plain data frame. For where DQ
sits in the full pipeline see the [ingest
guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md);
for the engine internals and custom checks, the [DQ
pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md).

## The extract

In practice you’d read the submitted file
([`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
/ the raw layer). Here is a small DR malaria surveillance extract with a
few deliberate problems, two values that the schema can normalise, and a
few that it cannot:

``` r

extract <- data.frame(
  Year                   = c(2026, 2026, 2026, 2026, 2026),
  EpiWeek                = c(10, 11, 12, 13, 60),          # 60 is out of range
  Age                    = c(34, 5, 200, 41, 28),          # 200 is impossible
  Sex                    = c("Masculino", "Femenino", "Male", "X", "F"),  # X is invalid
  Province_Residence     = c("SANTIAGO", "Santo Domingo", "Azua", "Distrito Nacional", "Nowhere"),
  Municipality_Residence = c("Santiago", "SD", "Azua", "DN", "X"),
  SampleDate             = c("2026-03-01", "2026-03-08", "2026-03-15", "2026-03-22", "2026-03-29"),
  EpiWeekYear            = c(2026, 2026, 2025, 2026, 2026)  # row 3 mismatches Year
)
```

## Run the checks

Load the schema for this dataset’s four axes (`azcontainer = NULL` uses
the bundled schema, no Azure), then run the checks and print the report:

``` r

schema <- load_dq_schema("dr", "malaria", "surveillance", "aggregate", azcontainer = NULL)
res    <- run_dq_checks(extract, schema)
#> ✔ DQ checks complete: 3 corrections, 5 flags for review.

dq_report(res)
#> ── Data Quality Report ─────────────────────────────────────────────
#> Shape: 5 rows x 8 columns
#>
#> ── Automated Corrections (3 total) ──
#> • "Sex": 2 corrections (translation)
#> • "Province_Residence": 1 correction (correction)
#>
#> ── Flags Requiring Review (5 total) ──
#> ! Value not in allowed_values list: 2 rows [Sex, Province_Residence] (e.g. X (row 4); Nowhere (row 5))
#> ! Value outside expected range [0, 120]: 1 row [Age] (e.g. 200 (row 3))
#> ! Value outside expected range [1, 53]: 1 row [EpiWeek] (e.g. 60 (row 5))
#> ! Year extracted from SampleDate does not match EpiWeekYear: 1 row [SampleDate] (e.g. 2026-03-15 (row 3))
#>
#> ℹ See `result$flags` for the full row-level detail.
```

## What was fixed automatically

`res$log` is the audit trail of every auto-correction, what changed, in
which row, and why. Share it so the country knows what was normalised on
their behalf (it is not an error on their part, but they should see it):

``` r

res$log
#> # A tibble: 3 × 6
#>     row column             original_value corrected_value rule        action
#>   <int> <chr>              <chr>          <chr>           <chr>       <chr>
#> 1     1 Sex                Masculino      Male            translation corrected
#> 2     2 Sex                Femenino       Female          translation corrected
#> 3     1 Province_Residence SANTIAGO       Santiago        correction  corrected
```

## What the country must fix

`res$flags` is the feedback list, the rows the schema could **not**
resolve. This is what you send back:

``` r

res$flags
#> # A tibble: 5 × 4
#>     row column             value      issue
#>   <int> <chr>              <chr>      <chr>
#> 1     5 EpiWeek            60         Value outside expected range [1, 53]
#> 2     3 Age                200        Value outside expected range [0, 120]
#> 3     4 Sex                X          Value not in allowed_values list
#> 4     5 Province_Residence Nowhere    Value not in allowed_values list
#> 5     3 SampleDate         2026-03-15 Year extracted from SampleDate does not match EpiWeekYear
```

Turn it into a self-contained handback file with
[`eri_dq_export()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_export.md),
a self-contained HTML (prints cleanly to PDF from a browser) or markdown
file ready to attach to an email or paste into Teams – one consistent
format instead of an ad hoc table each time:

``` r

eri_dq_export(res$flags, country = "dr")
#> ✔ DQ report (5 flags · 5 open) written to '.../dq-report-dr-2026-07-11.html'.
```

## Notify the team / country

[`eri_notify_dq()`](https://thecartercenter.github.io/erifunctions/reference/eri_notify_dq.md)
posts a one-glance summary (rows, corrections, flags, the most-flagged
columns) to Teams, handy for a shared channel that tracks each country’s
submissions:

``` r

eri_notify_dq(res, country = "dr", disease = "malaria")
#> ℹ Sending Teams message via incoming webhook.
```

It posts a compact, at-a-glance summary to the channel your webhook
points at:

    [DQ Report] DR - MALARIA
    Rows processed : 5
    Corrections    : 3
    Flags          : 5
    Top flagged    : Age, EpiWeek, Province_Residence, SampleDate, Sex

To target a specific Teams channel instead of the default webhook, pass
`team =` / `channel =` with a token (the Graph-API path), see the
[connections
guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html#teams).

## What’s next

- The cleaned data (`res$data`) continues through the pipeline, see the
  [ingest
  guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)
  for stage → **approve**.
- The [DQ
  pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md),
  the check engine, schema rules, and adding `custom_checks`.
- The [epi anomaly
  guide](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.md),
  spikes, gaps, and cross-field/spatial anomalies beyond cell-level
  validity.
- Persist the flags to the shared backlog with
  [`eri_dq_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_log.md),
  the [log-triage
  guide](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md).
- For a CMR workbook specifically,
  [`eri_dq_export()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_export.md)
  also renders the richer, per-sheet flags tibble from
  [`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
  – see the [CMR
  guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md)
  and
  [`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
  for the interactive triage wrapper that calls it automatically. \`\`\`
