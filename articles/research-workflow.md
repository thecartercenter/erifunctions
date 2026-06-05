# Research Project Workflow

The research workflow functions scaffold a reproducible project
structure that ties a local working directory to a corresponding folder
in Azure blob storage. This ensures data lineage, reproducibility across
analysts, and clean separation of raw, cleaned, and output data.

## Starting a new project

Call
[`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md)
once at the beginning of a study. It creates the local scaffold and the
corresponding Azure directory:

``` r

library(erifunctions)

eri_research_init(
  project_name = "dr_irs_2024",
  country      = "dr",
  disease      = "malaria",
  description  = "Interrupted time-series analysis of IRS impact on malaria incidence"
)
```

This creates:

    <project_root>/
    ├── data/          # raw data downloads go here
    ├── figs/          # all figures
    ├── outputs/       # cleaned data, model results, reports
    └── research.yaml  # project manifest (auto-managed)

And in Azure: `research/dr_irs_2024/`

Use `dry_run = TRUE` to preview what will be created without writing
anything.

## Resuming a session

At the top of every subsequent work session, call
[`eri_research_resume()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_resume.md)
to reconnect and see a brief project summary:

``` r

eri_research_resume()
# ✔ Project: 'dr_irs_2024' (dr / malaria)
#   Azure:      research/dr_irs_2024/
#   Last pull:  2024-03-10T14:32:00Z
#   Last log:   [2024-03-10T15:01:00Z] Ran ITS model — negative binomial converged.
#   Snapshots:  2
```

## Pulling data

Use
[`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
to download a specific dataset from Azure into `data/`. The pull is
recorded in `research.yaml` for reproducibility:

``` r

eri_research_pull(
  blob_path  = "clean/dr_malaria_clean.parquet",
  local_name = "dr_malaria_clean.parquet"
)
# Downloads to data/dr_malaria_clean.parquet
# Records: blob_path, local_name, file hash, timestamp in research.yaml
```

## Logging decisions

Record analytical decisions in the project lab notebook with
[`eri_research_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_log.md):

``` r

eri_research_log("Excluded 2020 data due to COVID-19 disruptions to surveillance.")
eri_research_log("Chose negative binomial GLM over Poisson — overdispersion confirmed (dispersion test p < 0.001).")
eri_research_log("Index date set to 2023-06-15 based on IRS deployment records from DIGEPI.")
```

Entries are stored with a UTC timestamp in `research.yaml` and can be
reviewed any time by calling
[`eri_research_resume()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_resume.md).

## Snapshotting outputs

Before a major analysis step (model run, sensitivity analysis), save a
snapshot of your output files to Azure for rollback if needed:

``` r

eri_research_snapshot(
  files = c("outputs/its_results.csv", "outputs/coef_table.csv"),
  note  = "Baseline ITS model before adding province fixed effects"
)
```

Snapshots are stored at `research/dr_irs_2024/snapshots/<timestamp>/`.

## Uploading outputs

When your analysis is complete, push cleaned data and final outputs back
to Azure:

``` r

eri_research_push(
  local_path = "outputs/dr_malaria_clean.parquet",
  blob_path  = "clean/dr_malaria_clean_v2.parquet"
)
```

## Typical session structure

A typical analysis session follows this pattern:

``` r

# ── 1. Resume ───────────────────────────────────────────────────────────────
eri_research_resume()

# ── 2. Pull data ────────────────────────────────────────────────────────────
eri_research_pull("clean/dr_malaria_clean.parquet", "dr_malaria_clean.parquet")
df <- arrow::read_parquet("data/dr_malaria_clean.parquet")

# ── 3. Analyse ──────────────────────────────────────────────────────────────
schema <- load_dq_schema("dr", "malaria_case", azcontainer = NULL)
result <- run_dq_checks(df, schema) |>
  add_anomaly_pct_change("n_cases", "epiweek", year_col = "year",
                          group_cols = "province")

eri_research_log("DQ checks complete — 12 out-of-range epiweek values flagged.")

# ── 4. Snapshot before modelling ────────────────────────────────────────────
arrow::write_parquet(result$data, "outputs/dr_malaria_dq.parquet")
eri_research_snapshot("outputs/dr_malaria_dq.parquet", note = "Post-DQ data")

# ── 5. Report ────────────────────────────────────────────────────────────────
eri_report_excel(
  sheets = list(
    data  = list(data = result$data,  title = "Cleaned data"),
    flags = list(data = result$flags, title = "Flags for review")
  ),
  path = "outputs/dq_review.xlsx"
)

# ── 6. Push outputs ──────────────────────────────────────────────────────────
eri_research_push("outputs/dq_review.xlsx", "research/dr_irs_2024/dq_review.xlsx")

eri_research_log("Session complete. DQ review shared with DIGEPI counterparts.")
```

## Azure data access

All Azure connectivity goes through two environment variables:

| Variable                         | Default  | Purpose                  |
|----------------------------------|----------|--------------------------|
| `ERIFUNCTIONS_DATA_STORAGE_NAME` | `"data"` | Main data blob container |
| `ERIFUNCTIONS_LOGS_STORAGE_NAME` | `"logs"` | Access log container     |

Set these in your `.Renviron` (or in the project `.Renviron.local`)
using `usethis::edit_r_environ()`. Authentication uses your Azure AD
credentials via `AzureAuth` — run
[`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)
interactively once to cache the token.

``` r

# In .Renviron:
# ERIFUNCTIONS_DATA_STORAGE_NAME=data
# ERIFUNCTIONS_LOGS_STORAGE_NAME=logs
# ERI_ANALYST_ID=nkishore
```

## Data policy

Raw and cleaned surveillance data must never leave Azure or this
machine. Only aggregate summaries, model coefficients, and formatted
reports should be shared externally. See the team data handling policy
for details.
