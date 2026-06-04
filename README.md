# erifunctions

Standardized data tools for the Epidemiology, Research and Innovation (ERI) team at The Carter Center's NTD and malaria programs.

**Version:** 0.4.0 · **Status:** Active development

---

## Installation

```r
# Install from GitHub
devtools::install_github("thecartercenter/erifunctions")

# Pin the version in your analysis project (recommended)
renv::install("thecartercenter/erifunctions")
renv::snapshot()
```

---

## Setup

Add the following to your project `.Renviron` (`usethis::edit_r_environ(scope = "project")`):

```
# Azure storage
ERIFUNCTIONS_TENANT_ID=<Azure tenant ID>
ERIFUNCTIONS_APP_ID=<Azure app registration ID>
ERIFUNCTIONS_RESOURCE_ENDPOINT=<storage account endpoint URL>
ERIFUNCTIONS_STORAGE_NAME=projects
ERIFUNCTIONS_DATA_STORAGE_NAME=data

# Service principal — for scripted/automated use only
ERIFUNCTIONS_SP_CLIENT_ID=<SP client ID>
ERIFUNCTIONS_SP_CLIENT_SECRET=<SP client secret>

# Your analyst identity (appears in approval and access logs)
ERI_ANALYST_ID=firstname.lastname

# ODK Central
ODK_URL=https://rblf.tccodk.org/
ODK_USER=your.email@cartercenter.org
ODK_PASS=<ODK password>
```

Restart R after editing `.Renviron`.

---

## Daily workflow

The fastest way to get started is to copy the daily workflow template into your analysis project:

```r
file.copy(
  system.file("templates/eri_daily_workflow.qmd", package = "erifunctions"),
  "."
)
```

Open `eri_daily_workflow.qmd` in RStudio and knit it. The template walks through:
1. Connecting to Azure and ODK Central
2. Checking survey submission health
3. Syncing new ODK data to Azure
4. Reviewing and approving staged data

---

## Core concepts

### Data layers

All data lives in the `data/` Azure blob under a standard path:

```
data/{country}/{disease}/{data_type}/{layer}/
                                     raw/        <- as-received from source
                                     staged/     <- DQ-checked, awaiting approval
                                     processed/  <- analyst-approved, canonical
```

`eri_approve()` is the explicit human gate. Nothing reaches `processed/` without it.

### Data catalog

Every file promoted by `eri_approve()` is automatically registered in `_catalog/data_catalog.yaml`. Query it to see what data exists on the system:

```r
# What processed Uganda oncho data do we have?
eri_catalog_query(country = "uga", disease = "oncho", layer = "processed")

# Is everything in the catalog still in Azure?
eri_catalog_verify()
```

---

## Function reference

### Connections

| Function | What it does |
|---|---|
| `get_azure_storage_connection()` | Authenticate with Azure (browser or service principal) |
| `init_odk_connection()` | Authenticate with ODK Central |

### Reading and writing data

| Function | What it does |
|---|---|
| `eri_read(file_loc)` | Read a file from Azure (parquet, csv, xlsx, rds) |
| `eri_write(obj, file_loc)` | Write an object to Azure |
| `eri_upload(local_path, file_loc)` | Upload any local file to Azure |
| `eri_list(file_loc)` | List files in an Azure directory |
| `eri_file_exists(file_loc)` | Check whether a file exists |
| `eri_data_path(country, disease, data_type, layer)` | Build a canonical blob path |

### Data pipeline

| Function | What it does |
|---|---|
| `eri_approve(country, disease, data_type, period)` | Promote staged files to processed (human gate) |
| `eri_stage(pipeline, country, disease)` | Pull pipeline output from projects blob into staged |
| `eri_ingest(path, country, disease)` | DQ-check a local file and dual-write to both blobs |
| `eri_trigger(pipeline, country, disease)` | Dispatch a GitHub Actions pipeline |

### Data quality

| Function | What it does |
|---|---|
| `load_dq_schema(country, disease)` | Load a bundled YAML DQ schema |
| `run_dq_checks(data, schema)` | Run all schema-driven checks; returns a `dq_result` |
| `dq_report(result)` | Print a summary of flags and corrections |
| `add_anomaly_pct_change(data, value_col, period_col)` | Flag period-over-period spikes |
| `add_anomaly_gaps(data, period_col, period_type)` | Detect missing periods in a time series |
| `add_anomaly_consistency(data, schema)` | Validate cross-field rules |
| `add_anomaly_spatial(data, schema)` | Validate admin names against reference shapefiles |

### CMR monthly reports

| Function | What it does |
|---|---|
| `eri_ingest_cmr(path, sheet, country)` | Parse a CMR Excel sheet |
| `load_cmr_schema(country)` | Load a bundled CMR country schema |
| `eri_stage_cmr(country, period)` | Stage CMR files from the projects blob |

### ODK

| Function | What it does |
|---|---|
| `eri_odk_register(project_id, form_id, country, disease, server_url)` | Register a form in the Azure registry |
| `eri_odk_deregister(project_id, form_id)` | Soft-delete a registered form |
| `eri_odk_list_registered()` | List all active registered forms |
| `eri_odk_sync(project_id, form_id)` | Download new submissions to Azure as parquet |
| `eri_survey_status(project_id, form_id)` | Check submission counts and recency |
| `eri_odk_bulk_users(csv_path)` | Assign/remove/create app users from a CSV |
| `list_odk_projects()` | List all ODK projects |
| `list_odk_forms(project_id)` | List forms in a project |
| `download_odk_form(project_id, form_id)` | Download all submissions from a form |

### Data catalog

| Function | What it does |
|---|---|
| `eri_catalog_register(path, country, disease, data_type, layer)` | Register a file in the catalog |
| `eri_catalog_query(country, disease, data_type, layer, period)` | Query catalog entries |
| `eri_catalog_verify()` | Check catalog entries exist in Azure; update verification timestamps |

### Onboarding a new country or disease

| Function | What it does |
|---|---|
| `eri_onboard_country(country_code, country_name, disease)` | Scaffold a surveillance schema and create Azure directories |
| `eri_onboard_cmr(country_code, country_name)` | Scaffold a CMR schema |
| `eri_schema_validate(schema_path)` | Validate a local schema YAML for structural issues |

### Teams notifications

| Function | What it does |
|---|---|
| `get_teams_connection(webhook_url)` | Create a Teams connection object |
| `eri_teams_send(con, message)` | Send a message to a Teams channel |
| `eri_notify_dq(con, result)` | Post a DQ summary to Teams |

---

## Supported countries

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

To add a new country, run `eri_onboard_country()` and follow the checklist it prints.

---

## Getting help

- Open an issue: <https://github.com/thecartercenter/erifunctions/issues>
- For developer contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md)
