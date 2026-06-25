# erifunctions <img src="man/figures/logo.png" align="right" height="120" alt="erifunctions logo" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/thecartercenter/erifunctions/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/thecartercenter/erifunctions/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/thecartercenter/erifunctions/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/thecartercenter/erifunctions/actions/workflows/pkgdown.yaml)
<!-- badges: end -->

Standardized data tools for the Epidemiology, Research and Innovation (ERI) team at The Carter Center's NTD and malaria programs.

### 📖 **Documentation & guides → <https://thecartercenter.github.io/erifunctions>**

**New here, start there.** The documentation site has step-by-step guides, the full function
reference, and the project roadmap. This README is the quick orientation.

**Version:** 0.9.0 · **Status:** Active development

> 🛣️ **Where this is going:** see the
> [V2 roadmap](https://github.com/thecartercenter/erifunctions/blob/main/docs/roadmap.md) and the
> [architecture decision records](https://github.com/thecartercenter/erifunctions/tree/main/docs/adr)
> for the development plan and the reasoning behind key design choices.

---

## Guides

These copy-paste, start-to-finish walkthroughs are the fastest way to learn the system. Read them
on the [documentation site](https://thecartercenter.github.io/erifunctions/articles/):

| Guide | For |
|---|---|
| [A complete research workflow for epidemiologists](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.html) | Epidemiologists running a study end-to-end — from a fresh project to a citable, reproducible result |
| [Ingesting a surveillance dataset (raw → approved)](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html) | Data analysts taking a dataset through the raw → staged → approved pipeline, with a human approval gate |
| [Data quality pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.html) | Running schema-driven DQ checks and anomaly detection on an extract |
| [Epi analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.html) | Incidence, epiweeks, epidemic curves, and disease-specific helpers |
| [Spatial workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.html) | Admin boundaries, population, and spatial joins/maps |
| [SharePoint workflow](https://thecartercenter.github.io/erifunctions/articles/sharepoint-workflow.html) | Sharing files via SharePoint and posting to Teams |
| [Adding a new program](https://thecartercenter.github.io/erifunctions/articles/adding-a-program.html) | Onboarding a new country, disease, or data type |

The full, grouped **function reference** lives at
<https://thecartercenter.github.io/erifunctions/reference/>.

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

Two templates ship with the package. Pull either one with `eri_template_pull()`:

```r
# Data analyst daily workflow (connections, ODK sync, DQ, approve)
eri_template_pull("eri_daily_workflow")

# Epidemiologist research workflow (init/resume, pull data, analysis, snapshot)
eri_template_pull("eri_research_workflow")
```

Open the `.qmd` file in RStudio and knit it.

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

### Artifact registry

| Function | What it does |
|---|---|
| `eri_artifact_upload(local_path, name, type, description)` | Upload a non-standard reference file to Azure and register it |
| `eri_artifact_list(type, include_archived)` | List registered artifacts; excludes archived by default |
| `eri_artifact_pull(name, dest)` | Download an artifact locally; records usage in `research.yaml` if present |
| `eri_artifact_archive(name)` | Soft-delete an artifact (file preserved, hidden from list/pull) |

### Research projects

| Function | What it does |
|---|---|
| `eri_research_init(project_name, country, disease, description)` | Scaffold a new research project locally and in Azure |
| `eri_research_resume()` | Re-read `research.yaml` and print session summary |
| `eri_research_log(note)` | Append a timestamped lab notebook entry to `research.yaml` |
| `eri_research_list()` | List all research projects in Azure |
| `eri_research_pull(country, disease, data_type)` | Pull canonical or reference data into the project with provenance |
| `eri_research_upload_figure(local_path, caption)` | Upload a figure to Azure outputs and record in manifest |
| `eri_research_upload_output(obj, filename)` | Serialize and upload an R object to Azure outputs |
| `eri_research_snapshot(label)` | Freeze the local `data/` directory to a timestamped Azure snapshot |

### Template management

| Function | What it does |
|---|---|
| `eri_template_list()` | List bundled and Azure-hosted templates |
| `eri_template_pull(name, dest)` | Copy a template to a local directory |
| `eri_template_upload(local_path, name, description)` | Upload a custom template to Azure for team sharing |

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
- For developer contribution guidelines, see
  [CONTRIBUTING](https://github.com/thecartercenter/erifunctions/blob/main/CONTRIBUTING.md)
- For the development roadmap and design decisions, see the
  [roadmap](https://github.com/thecartercenter/erifunctions/blob/main/docs/roadmap.md)
  and [architecture decision records](https://github.com/thecartercenter/erifunctions/tree/main/docs/adr);
  the [project conventions](https://github.com/thecartercenter/erifunctions/blob/main/CLAUDE.md)
  and [founding vision](https://github.com/thecartercenter/erifunctions/blob/main/docs/vision.md)
  document the working practices and intent
