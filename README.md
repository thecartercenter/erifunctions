# erifunctions <img src="man/figures/logo.png" align="right" height="120" alt="erifunctions logo" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/thecartercenter/erifunctions/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/thecartercenter/erifunctions/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/thecartercenter/erifunctions/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/thecartercenter/erifunctions/actions/workflows/pkgdown.yaml)
<!-- badges: end -->

Standardized data tools for the Epidemiology, Research and Innovation (ERI) team at The Carter Center's NTD and malaria programs.

### 📖 **Documentation & guides → <https://thecartercenter.github.io/erifunctions>**

**New here, start there.** The documentation site has step-by-step guides, the full function
reference, and the project roadmap. This README is the quick orientation.

**Version:** 0.9.39 · **Status:** Active development

> 🛣️ **Where this is going:** see the
> [V2 roadmap](https://github.com/thecartercenter/erifunctions/blob/main/docs/roadmap.md) and the
> [architecture decision records](https://github.com/thecartercenter/erifunctions/tree/main/docs/adr)
> for the development plan and the reasoning behind key design choices.

---

## Guides

**Bringing in a monthly country report, a surveillance dataset, or ODK submissions? Standing up a
new country or disease?** Run `eri_do()` — a guided console wizard that walks the whole
upload/archive → stage → review → approve pipeline through a few prompts (which country, which
file or ODK form, confirm the period), and scaffolds a brand-new country/disease space when you're
onboarding one. No function names to memorize, no Azure path to type by hand.

These copy-paste, start-to-finish walkthroughs are the fastest way to learn the system. Read them
on the [documentation site](https://thecartercenter.github.io/erifunctions/articles/), which groups
them **Get started → your role → topic deep-dives → contributing**. The
[**Getting started**](https://thecartercenter.github.io/erifunctions/articles/getting-started.html)
article is the front door.

**New Data Analyst?** Start with the **[onboarding path](https://thecartercenter.github.io/erifunctions/articles/onboarding.html)**,
a paced Week-0 → Week-2 track through the guides below, and keep the quick-reference articles open as
you work:

- [What are you trying to do?](https://thecartercenter.github.io/erifunctions/articles/task-index.html):
  a generated index of ~31 common tasks — pick yours, get the call and the guide. Prefer the
  console? `eri_task_map()` prints the same list.
- [Orientation](https://thecartercenter.github.io/erifunctions/articles/orientation.html): the big
  picture: the data system, the pipeline, and where your tasks live
- [DA cheat sheet](https://thecartercenter.github.io/erifunctions/articles/da-cheatsheet.html): the
  ~15 functions you use, the path model, and the "which pipeline?" decision tree
- [Data-model card](https://thecartercenter.github.io/erifunctions/articles/data-model-card.html):
  channel (`data_source`) vs. measure (`data_type`)
- [Troubleshooting card](https://thecartercenter.github.io/erifunctions/articles/troubleshooting.html):
  common errors → fixes + the log-triage loop

**New here? Do these in order** (then dip into the rest as your work needs them). First, run
`eri_data_model()` once, it prints the data-addressing vocabulary (channel vs. measure) every guide
assumes.

- **New Data Analyst:**
  [Connections](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html) →
  [Onboard a space](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.html) →
  [Ingest a dataset](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html) →
  [Triage the log backlog](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.html).
  Then [CMR](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html) and
  [ODK](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.html) when you file those.
- **New Epidemiologist:**
  [Connections](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html) →
  [Research workflow](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.html) →
  [Reconcile localities](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.html) →
  [Catch anomalies](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.html).

The full set (**Sandbox** = runs safely with no real country ever touched — on the built-in
`atlantis` training country, fully offline, or with public/placeholder data under a non-real
country code):

| Guide | For | Time | Needs | Sandbox |
|---|---|---|---|---|
| [Connecting to Azure, ODK, SharePoint & Teams](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html) | Everyone, how to authenticate to each service and confirm it works (start here) | ~20 min | Azure + ODK | No |
| [A complete research workflow for epidemiologists](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.html) | Epidemiologists running a study end-to-end, from a fresh project to a citable, reproducible result | ~40 min | Azure | Yes |
| [Ingesting a surveillance dataset (raw → approved)](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html) | Data analysts taking a dataset through the raw → staged → approved pipeline, with a human approval gate | ~35 min | Azure | Yes |
| [Uploading a monthly country report (CMR)](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html) | Data analysts uploading, staging, parsing, and approving the monthly CMR Excel reports countries file | ~25 min | Azure | No |
| [Triaging DQ flags interactively](https://thecartercenter.github.io/erifunctions/articles/da-dq-review-guide.html) | Data analysts working a CMR's DQ flags through one guided menu (`eri_dq_review()`) instead of the underlying functions, ending in a handback file (`eri_dq_export()`) | ~20 min | Azure | Yes |
| [Working with ODK Central](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.html) | Data analysts connecting to ODK Central to monitor a form, manage collectors, and pull submissions into the pipeline | ~40 min | Azure + ODK | No |
| [Onboarding a new country / disease / data type](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.html) | Data analysts standing up the schema + folders for a new program before any data flows | ~20 min | Azure | Yes |
| [Triaging the error & DQ log backlog](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.html) | Data analysts finding what failed or needs review and closing it out (shared across the team) | ~20 min | Azure | Yes |
| [Answering ad-hoc requests with SQL](https://thecartercenter.github.io/erifunctions/articles/da-adhoc-guide.html) | Data analysts running SQL across approved datasets (roll-ups, joins) with the `eri_query()` DuckDB layer | ~15 min | Azure | No |
| [Branded tables, figures & decks](https://thecartercenter.github.io/erifunctions/articles/da-reporting-guide.html) | Data analysts turning approved data into on-brand tables, plots, Excel workbooks, and PowerPoint decks | ~10 min | Nothing | Yes |
| [QC an extract & give a country feedback](https://thecartercenter.github.io/erifunctions/articles/da-qc-feedback-guide.html) | Data analysts running DQ checks on a submission and turning the flags into clear country feedback | ~10 min | Nothing | No |
| [Final summaries & reports from an ODK survey](https://thecartercenter.github.io/erifunctions/articles/da-survey-report-guide.html) | Data analysts summarising an approved survey (e.g. LF TAS) with the disease helpers and packaging the result | ~10 min | Nothing | Yes |
| [Data quality pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.html) | Running schema-driven DQ checks and anomaly detection on an extract | ~15 min | Nothing | n/a |
| [Epi analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.html) | Incidence, epiweeks, epidemic curves, and disease-specific helpers | ~10 min | n/a | n/a |
| [Reconciling localities to admin units](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.html) | Epidemiologists mapping messy free-text place names to canonical admin units (match → geocode → review) | ~15 min | Nothing | Yes |
| [Catching anomalies in a new extract](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.html) | Epidemiologists QC-ing an extract for spikes, missing weeks, and cross-field/spatial anomalies before analysis | ~15 min | Nothing | Yes |
| [Spatial workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.html) | Admin boundaries, population, and spatial joins/maps | ~15 min | Azure | No |
| [SharePoint workflow](https://thecartercenter.github.io/erifunctions/articles/sharepoint-workflow.html) | Sharing files via SharePoint and posting to Teams | ~15 min | Azure | No |
| [Adding a new program](https://thecartercenter.github.io/erifunctions/articles/adding-a-program.html) | Onboarding a new country, disease, or data type | ~20 min | Nothing | Yes |

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

Azure needs no configuration. The first command that touches Azure opens your browser to sign in with your Carter Center account, and access is validated against your own identity. The tenant, app registration, and storage endpoint are built into the package.

Only a couple of entries go in your project `.Renviron` (`usethis::edit_r_environ(scope = "project")`), and only if you need them:

```
# Your analyst identity, recorded in approval and access logs (recommended)
ERI_ANALYST_ID=firstname.lastname

# ODK Central credentials (only if you sync ODK data)
ODK_USER=your.email@cartercenter.org
ODK_PASS=<ODK password>
```

Restart R after editing `.Renviron`.

Advanced settings, rarely needed:

```
ERIFUNCTIONS_STORAGE_NAME=projects           # only for data-analyst pipeline work against the projects blob
ODK_URL=https://rblf.tccodk.org/             # only if your ODK server is not the default
ERIFUNCTIONS_SP_CLIENT_ID=<SP client ID>     # unattended service-principal auth (automation only)
ERIFUNCTIONS_SP_CLIENT_SECRET=<SP client secret>
# ERIFUNCTIONS_TENANT_ID / ERIFUNCTIONS_APP_ID / ERIFUNCTIONS_RESOURCE_ENDPOINT override the built-in defaults
```

The full connection walkthrough, including the service-principal and Teams paths, is in the
[Connections guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html).

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

All data lives in the `data/` Azure blob under a standard path
([ADR-0012](docs/adr/0012-source-measure-data-model.md)):

```
data/{country}/{disease}/{data_source}/{data_type}/{layer}/
                                                   raw/        <- as-received from source
                                                   staged/     <- DQ-checked, awaiting approval
                                                   processed/  <- analyst-approved, canonical
```

The `data_type` (measure) level is optional, channel-only data lands one level shallower. The two
addressing axes are explained just below. `eri_approve()` is the explicit human gate. Nothing reaches
`processed/` without it.

### How data is addressed (vocabulary)

A path has **five independent axes** ([ADR-0012](docs/adr/0012-source-measure-data-model.md)), the key
is that **how the data arrives (`data_source`) is separate from what it measures (`data_type`)**:

| Axis | What it is | Examples |
|---|---|---|
| `country` | the country | `dr`, `ht`, `uga` |
| `disease` | the disease | `malaria`, `lf`, `oncho` |
| `data_source` | **the channel, how it arrives** | `surveillance`, `programmatic`, `research` |
| `data_type` | **the measure, what it captures** | `case`, `aggregate`, `treatment`, `tas` |
| `layer` | pipeline stage | `raw`, `staged`, `processed` |

```r
path <- eri_data_path("dr", "malaria", "surveillance", "case", "processed")
#>      "dr/malaria/surveillance/case/processed"
```

One source can carry many measures (a CMR yields `treatment` + `mmdp` + `survey`; the same source +
disease is `case` in one country, `aggregate` in another). `data_source` and `data_type` are
**extensible**: `eri_data_model()` lists the known values, and an unregistered one *warns* rather than
errors so new data is never blocked. (The schema set is keyed by `country` / `disease` / `data_source` /
`data_type`; the legacy four-axis path form and schema names are being migrated under #175.)

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
| `eri_data_path(country, disease, data_source, data_type, layer)` | Build a canonical blob path |
| `eri_data_model()` | Show the known `data_source` / `data_type` / `format` values |

### Data pipeline

| Function | What it does |
|---|---|
| `eri_approve(country, disease, data_source, period, data_type)` | Promote staged files to processed (human gate) |
| `eri_stage(pipeline, country, disease)` | Pull pipeline output from projects blob into staged |
| `eri_ingest(path, country, disease, data_source, data_type)` | DQ-check a local file and stage it (sandbox-runnable; opt-in `mirror_pipeline`) |
| `eri_trigger(pipeline, country, disease)` | Dispatch a GitHub Actions pipeline |

### Data quality

| Function | What it does |
|---|---|
| `load_dq_schema(country, disease, data_source, data_type)` | Load a DQ schema (local override → Azure → bundled); tags the result with `schema_source`/`schema_hash` |
| `eri_dq_schema_edit(country, disease, data_source, data_type)` | Fork the active schema into a local, editable override (auto-retired if upstream changes) |
| `eri_dq_schema_path(country, disease, data_source, data_type)` | Resolve the local file path of the currently active schema |
| `eri_dq_schema_status()` | List local schema overrides with age and active/stale state |
| `eri_dq_schema_reset(country, disease, data_source, data_type)` | Delete a local schema override |
| `run_dq_checks(data, schema)` | Run all schema-driven checks; returns a `dq_result` |
| `dq_report(result)` | Print a summary of flags and corrections |
| `add_anomaly_pct_change(data, value_col, period_col)` | Flag period-over-period spikes |
| `add_anomaly_gaps(data, period_col, period_type)` | Detect missing periods in a time series |
| `add_anomaly_consistency(data, schema)` | Validate cross-field rules |
| `add_anomaly_spatial(data, schema)` | Validate admin names against reference shapefiles |

### Logs & triage

| Function | What it does |
|---|---|
| `eri_dq_log(result, country, disease, data_source, data_type)` | Persist `run_dq_checks()` flags to the durable log backlog |
| `eri_logs(country, disease, data_source, data_type)` | Read the operation / DQ-flag triage backlog as one tibble |
| `eri_logs_resolve(log_path, note, forced)` | Close out a whole log entry (auto-summarizes from per-flag decisions if triaged); `forced` marks a bypass, not a genuine resolution |
| `eri_dq_flag_resolve(flag_id, status, note)` | Triage one DQ flag at a time (`not_important`/`fixed`/`noted`) |
| `eri_audit(country, disease, data_source, data_type, period)` | Reconstruct a chronological, event-level audit trail (staged/split/DQ-run/flag-resolved/approved) |

### Feedback

| Function | What it does |
|---|---|
| `eri_feedback(message, area, context, attachment)` | File a ticket to the shared backlog; optional dataset-scoping `context` and file `attachment` |
| `eri_feedback_list(area, status)` | Read the feedback backlog as a tibble |
| `eri_feedback_status(id, status, note)` | Move a ticket through the triage lifecycle |
| `eri_feedback_board()` | Print a one-line-per-status summary of the backlog |
| `eri_feedback_report(file, format)` | Render the weekly feedback report (HTML or Markdown) |
| `eri_dq_schema_submit(country, disease, data_source, data_type)` | Package a local schema override into a `dq`-area ticket, with an auto-drafted diff and the override attached |

### CMR monthly reports

| Function | What it does |
|---|---|
| `eri_ingest_cmr(path, sheet, country)` | Parse a CMR Excel sheet (each row carries its real `excel_row`) |
| `eri_split_cmr(path, country)` | Route each CMR sheet to its disease/measure staged path (opt-in `mirror_pipeline` one-step legacy mirror; opt-in `supersede_staged` cleans up a re-split's superseded files) |
| `load_cmr_schema(country)` | Load a bundled CMR country schema |
| `eri_stage_cmr(country, period)` | Stage CMR files from the projects blob |
| `eri_cmr_last_plan(country, period)` | Recover a past `eri_split_cmr()` run's routing plan from the log, without rerunning |
| `eri_cmr_dq_report(country, period)` | DQ-check every measure a CMR workbook routed to, one combined flags tibble |
| `eri_approve_cmr(country, period, force, justification)` | Approve every measure in one call, but only if none are outstanding (opt-in `force = TRUE` + `justification` to approve anyway) |
| `eri_dq_review(country, period)` | Interactive, menu-driven check → fix → re-check → approve loop over the functions above |
| `eri_dq_export(flags, file, format)` | Render a DQ flags tibble (CMR or plain `run_dq_checks()`) to a self-contained HTML/Markdown handback file |

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
| `eri_catalog_register(path, country, disease, data_source, layer, data_type)` | Register a file in the catalog |
| `eri_catalog_query(country, disease, data_source, data_type, layer, period)` | Query catalog entries |
| `eri_catalog_remove(path)` | Remove a file's catalog entry (e.g. after deleting it) |
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
| `eri_research_scaffold(name, country, disease, description)` | Create a **standalone research-project repository** (ADR-0006) at `dest/name/`, a full repo skeleton that depends on erifunctions |
| `eri_research_init(project_name, country, disease, description)` | Initialise a research project **in the current directory** (local `data/`/`figs/`/`outputs/` + `research.yaml`, registered in Azure) |
| `eri_research_resume()` | Re-read `research.yaml` and print session summary |
| `eri_research_status(check_remote)` | Report what data the project depends on and whether any of it is stale |
| `eri_research_log(note)` | Append a timestamped lab notebook entry to `research.yaml` |
| `eri_research_list()` | List all research projects in Azure |
| `eri_research_pull(country, disease, data_source, data_type)` | Pull canonical or reference data into the project with provenance |
| `eri_research_upload_figure(local_path, caption)` | Upload a figure to Azure outputs and record in manifest |
| `eri_research_upload_output(obj, filename)` | Serialize and upload an R object to Azure outputs |
| `eri_research_snapshot(label)` | Freeze the local `data/` directory to a timestamped Azure snapshot |
| `eri_research_tag(label, description)` | Freeze a reproducible, citable version of the project (tag + optional snapshot) |

`eri_research_scaffold()` vs `eri_research_init()`: **scaffold** stands up a new, separate project
*repository* (the ADR-0006 way, its own git repo); **init** initialises a project in a directory you
are already in. Most new studies start with `eri_research_scaffold()`.

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
