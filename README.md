# erifunctions

R package providing standardized data infrastructure for the Epidemiology, Research and Innovation (ERI) team at The Carter Center's River Blindness, Lymphatic Filariasis, Schistosomiasis and Malaria (RBLFSM) program.

**Version:** 0.3.0 · **Status:** Active development — Phase 2 complete

---

## What it does

`erifunctions` is the connective tissue between raw data sources and the team's analytical workflows. It handles:

- **Azure blob I/O** — standardized read/write/list operations against the team's `data/` and `projects/` storage containers
- **Data quality (DQ)** — schema-driven checks for surveillance and CMR data; anomaly detection for spikes, gaps, consistency violations, and admin name errors
- **CMR ingestion** — parse monthly report Excel files, load country schemas, stage files from the projects blob
- **ODK** — connect to ODK Central, list projects/forms, download submissions, manage app users
- **Pipeline helpers** — trigger GitHub Actions pipelines, stage intermediate output, approve data to processed layer

---

## Installation

### From GitHub (recommended for analysts)

```r
# Install devtools if needed
install.packages("devtools")

# Install erifunctions
devtools::install_github("thecartercenter/erifunctions")
```

### With renv (recommended for projects)

```r
renv::install("thecartercenter/erifunctions")
renv::snapshot()
```

---

## Setup

Set the following environment variables (add to `.Renviron` via `usethis::edit_r_environ()`):

```
ERIFUNCTIONS_TENANT_ID=<Azure tenant ID>
ERIFUNCTIONS_APP_ID=<Azure app ID>
ERIFUNCTIONS_RESOURCE_ENDPOINT=<storage endpoint URL>
ERIFUNCTIONS_STORAGE_NAME=projects
ERIFUNCTIONS_DATA_STORAGE_NAME=data

# Service principal (for automated/scripted use)
ERIFUNCTIONS_SP_CLIENT_ID=<SP client ID>
ERIFUNCTIONS_SP_CLIENT_SECRET=<SP client secret>

# Analyst identity (appears in approval logs)
ERI_ANALYST_ID=firstname.lastname
```

---

## Quick start

### Connect to Azure

```r
library(erifunctions)

# Interactive browser login
con <- get_azure_storage_connection()

# Service principal (scripted)
con <- get_azure_storage_connection(auth = "client_credentials")
```

### Run DQ checks on a surveillance file

```r
# Load the schema for your country/disease
schema <- load_dq_schema("dominican_republic", "malaria")

# Read the raw file
df <- eri_read("dr/malaria/surveillance/raw/2024_W01.parquet")

# Run all checks and print a report
result <- run_dq_checks(df, schema)
dq_report(result)

# Review flags before approving
result$flags

# Promote staged files to processed
eri_approve("dr", "malaria", "surveillance", period = "2024-W01")
```

### Ingest and stage a CMR monthly report

```r
# Parse a CMR Excel file (English template)
df <- eri_ingest_cmr("path/to/uga_202603.xlsx", sheet = "RB Treatment", country = "uga")

# Parse a French template using a canonical slug
df <- eri_ingest_cmr("path/to/tcd_202603.xlsx", sheet = "rb_treatment", country = "tcd")

# Stage CMR files from the projects blob into data/staged
eri_stage_cmr("uga", period = "202603")   # specific period
eri_stage_cmr("nga")                       # auto-selects most recent
```

---

## Function reference

### Azure I/O

| Function | Description |
|---|---|
| `get_azure_storage_connection()` | Authenticate and return an Azure container object |
| `eri_read(file_loc)` | Read a file from Azure (parquet, csv, xlsx, rds) |
| `eri_write(obj, file_loc)` | Write an object to Azure |
| `eri_upload(local_path, file_loc)` | Upload any local file to Azure |
| `eri_list(file_loc)` | List files in an Azure directory |
| `eri_file_exists(file_loc)` | Check whether a file exists |
| `eri_dir_exists(file_loc)` | Check whether a directory exists |
| `eri_dir_create(file_loc)` | Create a directory |
| `eri_delete(file_loc)` | Delete a file |
| `eri_dir_delete(file_loc)` | Delete a directory |

### Pipeline helpers

| Function | Description |
|---|---|
| `eri_data_path(country, disease, data_type, layer)` | Build a canonical `data/` blob path |
| `eri_stage(pipeline, country, disease)` | Pull intermediate pipeline output into `data/staged/` |
| `eri_stage_cmr(country, period)` | Pull CMR files from projects blob into `data/rblf/cmr/staged/` |
| `eri_ingest(path, country, disease)` | DQ-check a local surveillance file and dual-write to both blobs |
| `eri_approve(country, disease, data_type, period)` | Promote staged files to processed (human gate) |
| `eri_trigger(pipeline, country, disease)` | Dispatch a GitHub Actions pipeline |

### Data quality

| Function | Description |
|---|---|
| `load_dq_schema(country, disease)` | Load a bundled YAML DQ schema |
| `run_dq_checks(data, schema)` | Run all schema-driven checks; returns a `dq_result` |
| `dq_report(result)` | Print a summary of flags and corrections |
| `add_anomaly_pct_change(data, value_col, period_col)` | Flag period-over-period spikes |
| `add_anomaly_gaps(data, period_col, period_type)` | Detect missing periods in a time series |
| `add_anomaly_consistency(data, schema)` | Validate cross-field rules from schema |
| `add_anomaly_spatial(data, schema)` | Validate admin names against reference shapefiles |

### CMR monthly reports

| Function | Description |
|---|---|
| `eri_ingest_cmr(path, sheet, country)` | Parse a CMR Excel sheet using field code row |
| `load_cmr_schema(country)` | Load a bundled CMR country schema |
| `eri_stage_cmr(country, period)` | Stage CMR files from projects blob |

### ODK

| Function | Description |
|---|---|
| `init_odk_connection(url, user, pass)` | Authenticate with ODK Central |
| `list_odk_projects()` | List all ODK projects |
| `list_odk_forms(project_id)` | List forms within a project |
| `download_odk_form(project_id, form_id)` | Download all submissions from a form |
| `update_odk_app_user_role(action, project_id, ...)` | Create/delete/assign app users |

### Teams notifications

| Function | Description |
|---|---|
| `get_teams_connection(webhook_url)` | Create a Teams connection object |
| `eri_teams_send(con, message)` | Send a message to a Teams channel |
| `eri_notify_dq(con, result)` | Post a DQ summary to Teams |

---

## Data model

```
data/{country}/{disease}/{data_type}/{layer}/
                                     raw/        ← as-received
                                     staged/     ← DQ checked, awaiting approval
                                     processed/  ← analyst-approved canonical
```

`eri_approve()` is the explicit human gate before anything reaches `processed/`.

---

## Supported countries and diseases

| Country | Code | Programs |
|---|---|---|
| Dominican Republic | `dr` | malaria |
| Haiti | `ht` | malaria |
| Ethiopia | `eth` | oncho, LF |
| Nigeria | `nga` | oncho, LF, SCH, STH |
| Sudan | `sdn` | oncho, LF |
| South Sudan | `ssd` | oncho, LF |
| Uganda | `uga` | oncho, SCH |
| Madagascar | `mad` | LF |
| Chad | `tcd` | oncho, LF |

---

## Contributing

See the development workflow in the repository wiki. Briefly:
- Open a GitHub issue before writing code
- Branch from `dev` as `{issue-number}-{slug}`
- PRs target `dev`; `main` receives only version-bumped phase releases
- `devtools::check()` must be 0 errors, 0 warnings before merging

Report bugs at <https://github.com/thecartercenter/erifunctions/issues>.
