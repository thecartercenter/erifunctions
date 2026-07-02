# Catching anomalies in a new surveillance extract (for epidemiologists)

A fresh surveillance extract can be **valid cell-by-cell and still wrong
epidemiologically**, a week that suddenly triples, a reporting week that
never arrived, a count that exceeds what was tested. This guide, for
**epidemiologists**, is about that second layer: after the basic
[data-quality
checks](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md),
run the **anomaly detectors** to catch the patterns only a domain eye
would question, *before* the numbers reach a curve or a map.

It runs **fully offline** on a small synthetic extract, no Azure, no
real data. For the schema mechanics and the full anomaly reference, see
the [data-quality
pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md)
vignette; this guide is about **what the flags mean and what you do
about them**.

flowchart TD A\["New extract"\] --\> B\["run_dq_checks(): cell-level
QC"\] B --\> C\["Aggregate to weekly counts"\] C --\>
D\["add_anomaly_pct_change(): spikes"\] C --\> E\["add_anomaly_gaps():
missing weeks"\] B --\> F\["add_anomaly_consistency(): cross-field
rules"\] B --\> G\["add_anomaly_spatial(): admin names"\] D --\>
H\["Investigate before analysing"\] E --\> H F --\> H G --\> H

## Before you start

`remotes::install_github("thecartercenter/erifunctions")`. Everything
here is offline.

``` r

library(erifunctions)
library(dplyr)
```

## 1. The extract

We use a bundled case-level malaria schema (no Azure needed,
`azcontainer = NULL` loads the copy that ships with the package) and a
small synthetic line-list: two provinces over six epiweeks, one row per
case. It has three planted problems, a species typo, a **case spike**,
and a **missing week**, the kinds of thing a real extract hides:

``` r

# Load by the four-part identity (ADR-0012): country, disease, data_source (the
# channel, surveillance/programmatic/research), data_type (the measure, here
# "case", the case-level line-list). The legacy compound key still works too:
# load_dq_schema("dr", "malaria_case") resolves via an alias during the migration.
schema <- load_dq_schema("dr", "malaria", "surveillance", "case", azcontainer = NULL)

# A tiny helper to make `n` identical case rows for a province/week.
mk <- function(province, week, n, species = "P. vivax") {
  tibble::tibble(year = 2024, epiweek = week, province = province,
                 municipality = paste0(province, " City"),
                 sample_date = as.character(as.Date("2024-01-01") + (week - 1) * 7),
                 species = species)[rep(1, n), ]
}

cases <- dplyr::bind_rows(
  mk("Azua", 1, 3), mk("Azua", 1, 1, species = "P.vivax"),   # 1 species typo
  mk("Azua", 2, 3), mk("Azua", 3, 4), mk("Azua", 4, 3),
  mk("Azua", 5, 15), mk("Azua", 6, 4),                        # week 5 SPIKE
  mk("San Juan", 1, 3), mk("San Juan", 2, 3), mk("San Juan", 3, 3),
  mk("San Juan", 5, 3), mk("San Juan", 6, 3)                  # week 4 MISSING
)
nrow(cases)   # 48 cases across 2 provinces, epiweeks 1-6
```

## 2. Baseline: the cell-level checks

Start with
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
the same engine the [ingest
guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)
covers. It catches *cell* problems (bad types, out-of-range values,
values off the allowed list):

``` r

result <- run_dq_checks(cases, schema)
result
#> ✔ DQ checks complete: 0 corrections, 1 flag for review.
#> ── Data Quality Report ──────────────────────────────────────────────
#> Shape: 48 rows x 7 columns
#>
#> ── Automated Corrections (0 total) ──
#> ✔ No corrections applied.
#>
#> ── Flags Requiring Review (1 total) ──
#> ! Value not in allowed_values list: 1 row [species] (e.g. P.vivax (row 4))
#>
#> ℹ See `result$flags` for the full row-level detail.
```

One flag, a mistyped species. Useful, but it tells you nothing about
whether the *epidemiology* makes sense. For that, chain on the anomaly
detectors.

## 3. Spikes, `add_anomaly_pct_change()`

Epidemic data moves week to week; a sudden jump is either a real
outbreak or a data error, and you need to know which. Aggregate to
weekly counts per province, then flag period-over-period changes above a
threshold:

``` r

weekly <- count(result$data, year, epiweek, province, name = "n_cases")

flagged <- add_anomaly_pct_change(
  weekly,
  value_col  = "n_cases",
  period_col = "epiweek",
  group_cols = "province",   # compare each province against itself
  year_col   = "year",       # so weeks order correctly across years
  threshold  = 0.5           # flag changes greater than 50%
)
#> ! 2 rows flagged for % change anomaly in "n_cases" (threshold: 50%).

flagged[flagged$anomaly_pct_change_n_cases, c("epiweek", "province", "n_cases", "pct_change_n_cases")]
#> # A tibble: 2 × 4
#>   epiweek province n_cases pct_change_n_cases
#>     <dbl> <chr>      <int>              <dbl>
#> 1       5 Azua          15              4
#> 2       6 Azua           4             -0.733
```

Azua jumped from 3 cases to **15 in week 5**, a five-fold rise (the
detector reports `pct_change = 4`, i.e. +400%), then fell back in week 6
(`-73%`). Both are flagged, because a spike produces *two* large changes
(up, then down). The week-5 row is the one to investigate: **is this a
genuine cluster the field should respond to, or did a batch of cases get
entered twice?** The detector doesn’t decide, it points you at the week
worth a phone call.

(We aggregated `result$data` as-is, so the one still-flagged species row
is rolled in, harmless for these per-week counts, but on a real extract
you’d resolve the cell flags from §2 before rolling anything up.)

## 4. Missing weeks, `add_anomaly_gaps()`

A week with **no rows at all** never shows up as a bad value, it’s
simply absent, and easy to miss.
[`add_anomaly_gaps()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_gaps.md)
infers the expected run of weeks and returns the ones that aren’t there:

``` r

gaps <- add_anomaly_gaps(
  weekly,
  period_col  = "epiweek",
  period_type = "week",
  group_cols  = "province",
  year_col    = "year"
)
#> ! 1 missing period detected in "epiweek".

gaps
#> # A tibble: 1 × 4
#>   province year  epiweek issue
#>   <chr>    <dbl>   <dbl> <chr>
#> 1 San Juan 2024      4   structural_gap
```

San Juan reported weeks 1, 2, 3, 5, and 6, but **not week 4**. That is
not zero cases; it is *no report*. Before you draw an epidemic curve,
you need to know whether the clinic didn’t report that week (chase it)
or the data were dropped in transfer (fix it). A silent gap becomes a
fake “dip” in the curve if you don’t.

## 5. Cross-field rules, `add_anomaly_consistency()`

Some errors only show up when two columns are read together. The
schema’s `consistency` block defines named rules; the detector checks
each one and appends violations to the flags. Chain it onto the result:

``` r

result <- result |> add_anomaly_consistency(schema)
#> ✔ All consistency checks passed.
```

Here the schema’s epiweek rules all hold, so it passes. The real power
is **cross-field** rules, e.g. `positives <= tested`, or
`treated <= target_population`, which catch the impossible combinations
that range checks can’t see. The [data-quality
pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md)
vignette shows how to write them.

## 6. Geographic names, `add_anomaly_spatial()`

The last detector flags admin-unit names in the data that don’t appear
in the official boundary (a common symptom of a typo or an un-reconciled
locality). It needs an `admin` block in the schema and the reference
boundaries from Azure; our bundled case schema has neither, so it skips
cleanly rather than erroring:

``` r

result <- result |> add_anomaly_spatial(schema, azcontainer = NULL)
#> ℹ No admin block in schema; skipping spatial name check.
```

With a schema that defines admin boundaries (and Azure access), this
flags province or district names that aren’t on the official list. The
upstream fix, mapping messy place names to canonical units in the first
place, is the [locality reconciliation
guide](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.md).

## 7. What to do with the flags

The detectors don’t clean anything, they hand you a short list of
**questions to answer before you analyse**:

| Detector | Flag | The epi question |
|----|----|----|
| `pct_change` | a spike (or its rebound) | Real cluster → field response? Or double-entry → fix the data? |
| `gaps` | a missing reporting week | Clinic didn’t report → chase it? Or lost in transfer → recover it? |
| `consistency` | a cross-field violation | Which field is wrong? |
| `spatial` | an unrecognized admin name | Typo, or a locality that needs reconciling? |

Resolve those, and the curve, incidence, and maps you build next rest on
numbers you’ve actually interrogated.

## What’s next

- [Data-quality
  pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md):
  the schema reference and how to author consistency rules.
- [Reconciling
  localities](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.md):
  fixing the geographic names the spatial check flags.
- [Epi
  analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md):
  incidence, epiweeks, and epidemic curves, *after* the extract is
  clean.

See the [guide
index](https://github.com/thecartercenter/erifunctions/blob/main/docs/guides.md)
for the full set, and the
[reference](https://thecartercenter.github.io/erifunctions/reference/index.md)
for the anomaly-detector help pages.
