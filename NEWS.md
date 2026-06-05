# erifunctions 0.5.0

## Phase 4 -- Research infrastructure

### New functions

**Artifact registry** (`R/artifacts.R`)
- `eri_artifact_upload()` -- upload a non-standard reference file to `artifacts/{type}/{name}/` in Azure and register it in `artifacts/_registry.yaml`
- `eri_artifact_list()` -- return a tibble of registered artifacts, filtered by type; excludes archived entries by default
- `eri_artifact_pull()` -- download an artifact to a local destination; auto-records usage in `research.yaml` if present
- `eri_artifact_archive()` -- soft-delete (sets `archived: true`; file preserved in Azure)

**Research project scaffolding** (`R/research.R`)
- `eri_research_init()` -- scaffold local dirs (`data/`, `figs/`, `outputs/`), write `research.yaml` manifest, create Azure project directory
- `eri_research_resume()` -- re-read `research.yaml` and print session summary (last pull, last log, snapshot count); call at the top of each work session
- `eri_research_log()` -- append a timestamped free-text entry to the `research.yaml` log (lab notebook)
- `eri_research_list()` -- list all research projects under `research/` in Azure
- `eri_research_pull()` -- pull canonical processed data or any Azure path into the local project with provenance tracking
- `eri_research_upload_figure()` -- upload a figure to `research/{project}/outputs/figs/` and record in manifest
- `eri_research_upload_output()` -- serialize an R object via `qs2` and upload to `research/{project}/outputs/`
- `eri_research_snapshot()` -- freeze the full `data/` directory to a timestamped Azure snapshot with a `_manifest.yaml`

**Template management** (`R/templates.R`)
- `eri_template_list()` -- list available templates (bundled + Azure-hosted); falls back to bundled-only on Azure error
- `eri_template_pull()` -- copy a named template (bundled or Azure) to a local destination
- `eri_template_upload()` -- upload a `.qmd` or `.R` template to Azure and register it for team sharing

**Research Quarto template**
- `inst/templates/eri_research_workflow.qmd` -- epidemiologist research workflow template; pull with `eri_template_pull("eri_research_workflow")`

**Smoke tests**
- `tests/testthat/test-smoke.R` -- live integration test suite (skipped in CI); covers data analyst and epidemiologist workflows end-to-end against real Azure and ODK infrastructure; enable with `Sys.setenv(ERI_SMOKE_TESTS = "true")`

### Other changes
- Fixed non-ASCII characters (`--` replacing em dashes) in `R/research.R`
- `eri_research_snapshot()` now validates local `data/` directory before attempting Azure connection

# erifunctions 0.4.0

## Phase 3 — ODK integration, data catalog, and onboarding

### New functions

**ODK form registry**
- `eri_odk_register()` — register an ODK form in the shared Azure registry (`odk/registry.yaml`)
- `eri_odk_deregister()` — soft-delete a registered form (preserves sync history)
- `eri_odk_list_registered()` — list all active forms as a tibble

**ODK sync**
- `eri_odk_sync()` — download new submissions for a registered form and write to Azure as parquet

**Survey health**
- `eri_survey_status()` — fetch live submission counts and recency for one form, all forms in a project, or all projects; S3 class with cli-based print method

**Bulk user management**
- `eri_odk_bulk_users()` — read a CSV of assign/remove/create actions, run pre-flight validation (collects all errors before touching the API), then execute; `dry_run = TRUE` previews without mutating

**Data catalog**
- `eri_catalog_register()` — upsert a processed-layer file entry into `_catalog/data_catalog.yaml`
- `eri_catalog_query()` — filter catalog entries by country, disease, data_type, layer, or period
- `eri_catalog_verify()` — check each entry exists in Azure; updates `last_verified_at`
- `eri_approve()` now automatically registers each promoted file in the catalog

**Onboarding**
- `eri_onboard_country()` — write a surveillance DQ schema YAML template to your working directory and create the three-layer Azure blob directories for a new country/disease
- `eri_onboard_cmr()` — write a CMR schema YAML template locally; optionally create CMR Azure dirs
- `eri_schema_validate()` — validate a local YAML schema file; returns a tidy tibble of structural issues

**Analyst workflow**
- `inst/templates/eri_daily_workflow.qmd` — Quarto template covering the full analyst daily loop (connections, survey health, sync, review, approve); copy to your project with `file.copy(system.file("templates/eri_daily_workflow.qmd", package = "erifunctions"), ".")`

### Other changes
- `eri_approve()` wrapped with catalog registration (fail-silent so a catalog write never blocks an approval)
- ODK connection functions refactored to package standards (`cli`, `@export`, roxygen docs)

# erifunctions 0.3.0

## Phase 2 — CMR pipeline + DQ anomaly suite

### New functions
- `add_anomaly_pct_change()`, `add_anomaly_gaps()`, `add_anomaly_consistency()`,
  `add_anomaly_spatial()` — full anomaly detection suite
- `eri_ingest()` — dual-write surveillance ingestion with DQ checks
- `eri_ingest_cmr()`, `load_cmr_schema()`, `eri_stage_cmr()` — CMR monthly report pipeline
- CMR schemas for 7 countries: `eth`, `nga`, `sdn`, `ssd`, `uga` (English);
  `mad`, `tcd` (French) with slug alias support

### Other changes
- Added `"rb-expansion"` to the pipeline registry
- Added GitHub Actions CI workflow (ubuntu + windows, R release)
- Added `URL` and `BugReports` fields to DESCRIPTION

# erifunctions 0.2.0

## Phase 1 — Azure I/O and pipeline helpers

### New functions
- `eri_data_path()`, `eri_approve()`, `eri_trigger()`, `eri_stage()`
- Session and operation logging to Azure `data/logs/_access/`
