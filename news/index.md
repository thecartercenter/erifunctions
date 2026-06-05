# Changelog

## erifunctions (development version)

### V2 Phase 1 – dr_irs vertical slice (in progress)

- [`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md)
  – bind a frozen data snapshot, the analysis git commit, the input
  provenance, and the output manifest into an immutable, citable tag in
  Azure, recorded in `research.yaml`. Makes a tagged analysis
  reproducible from a citation, including across data updates. Tags are
  immutable and auto-create a snapshot if none exists.
  ([\#135](https://github.com/thecartercenter/erifunctions/issues/135))

## erifunctions 0.9.0

### V2 Phase 0 – Governance & shared-memory scaffolding

Documentation and project-infrastructure only; no changes to package
functions. Marks the start of the V2 effort.

- `docs/roadmap.md` – version-controlled V2 development roadmap (Phases
  0-5)
- `docs/adr/` – architecture decision records (single-package vs split,
  concurrency-safe metadata, token-derived identity, DuckDB query layer,
  pull-then-process, research-as-repos)
- `docs/vision.md` – the founding vision brief, moved out of the
  gitignored `sandbox/`
- `CLAUDE.md` – working memory and conventions for contributors (human
  and AI)
- `_pkgdown.yml` + `.github/workflows/pkgdown.yaml` – grouped-reference
  documentation site, published to
  <https://thecartercenter.github.io/erifunctions/>
- README version banner and CI status badges (R-CMD-check, pkgdown)
- Cleared the pre-existing `R CMD check` warning and notes (non-ASCII
  source, [`utils::tail`](https://rdrr.io/r/utils/head.html) import,
  `CONTRIBUTING.md` in `.Rbuildignore`); bumped CI actions to
  `checkout@v5`
- `main` branch protection requiring the R-CMD-check and pkgdown gates

## erifunctions 0.8.0

### Phase 7 – SharePoint integration and multi-program expansion

#### New functions

**SharePoint** (`R/sharepoint.R`) -
[`eri_sharepoint_connect()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_connect.md)
– interactive browser auth via `Microsoft365R`; token cached by
`AzureAuth` -
[`eri_sharepoint_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_list.md)
– tibble of files/folders at a document library path (`name`, `size`,
`modified`, `is_folder`, `path`) -
[`eri_sharepoint_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_read.md)
– download and read a SharePoint file by extension (xlsx/xls, csv,
parquet, rds; returns temp path for unknown types) -
[`eri_sharepoint_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_upload.md)
– upload a local file to SharePoint; auto-creates destination folder;
`overwrite = FALSE` guard; returns item URL invisibly

**Onboarding** (`R/onboarding.R`) -
[`eri_onboard_disease()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_disease.md)
– generate MDA and/or prevalence skeleton YAML schemas for a new disease
program

#### New bundled schemas (`inst/schemas/`)

- `ug_rb_mda.yaml` / `ug_rb_prevalence.yaml` – Uganda river blindness
  (APOC community-directed treatment; nodule palpation / skin snip)
- `schisto_mda.yaml` / `schisto_prevalence.yaml` – Schistosomiasis
  (praziquantel MDA; Kato-Katz egg count by species)
- `sth_mda.yaml` / `sth_prevalence.yaml` – STH (albendazole/mebendazole
  MDA; Kato-Katz species breakdown)

#### New vignettes

- `vignettes/sharepoint-workflow.Rmd` – full connect/list/read/upload
  cycle with combined pull-DQ-report-push workflow
- `vignettes/adding-a-program.Rmd` – step-by-step guide: scaffold, edit,
  validate, test, PR checklist, epi functions pattern

------------------------------------------------------------------------

## erifunctions 0.7.0

### Phase 6 – Reporting and documentation

#### New functions

**Reporting core** (`R/reports.R`) -
[`eri_brand_colors()`](https://thecartercenter.github.io/erifunctions/reference/eri_brand_colors.md)
– named vector of Carter Center brand colours (navy, blue, orange, gold,
green, light_blue, gray) -
[`eri_brand_ggplot_theme()`](https://thecartercenter.github.io/erifunctions/reference/eri_brand_ggplot_theme.md)
– Carter Center ggplot2 theme built on
[`theme_bw()`](https://ggplot2.tidyverse.org/reference/ggtheme.html);
applies brand fonts, colours, and strip formatting -
[`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
– branded `flextable` with navy header, alternating row shading, Calibri
font, optional title and footnote; renders in Excel, HTML, and
PowerPoint

**Excel reports** (`R/reports_excel.R`) -
[`eri_wb_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_create.md)
– create a blank `openxlsx2` workbook with Carter Center metadata -
[`eri_wb_add_sheet()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_add_sheet.md)
– add a styled data sheet (navy header, alternating shading, frozen
first row, optional title) -
[`eri_wb_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_save.md)
– save a workbook to disk, auto-creating parent directories -
[`eri_report_excel()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_excel.md)
– convenience wrapper: create → add multiple sheets → save in one call

**HTML reports** (`R/reports_html.R`) -
[`eri_report_html()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_html.md)
– render a self-contained HTML report from a structured section list via
Quarto -
[`eri_report_qmd_template()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_qmd_template.md)
– copy the bundled Quarto template to a local path for customisation -
Internal: `.eri_serialise_sections()` – converts section tables to HTML
fragments and figures to base64 PNGs

**PowerPoint reports** (`R/reports_pptx.R`) -
[`eri_pptx_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_create.md)
– load the bundled Carter Center `.pptx` template (or a custom template)
as an `officer` object -
[`eri_pptx_add_title()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_title.md)
– add a title slide with optional subtitle -
[`eri_pptx_add_section()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_section.md)
– add a section divider slide -
[`eri_pptx_add_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_table.md)
– add a
[`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
flextable on a new slide -
[`eri_pptx_add_plot()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_plot.md)
– add a ggplot figure (saved as PNG) on a new slide -
[`eri_pptx_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_save.md)
– write the presentation to disk, auto-creating parent directories

#### New templates

- `inst/templates/eri_template.pptx` – default Carter Center PowerPoint
  template
- `inst/templates/eri_report.qmd` – Quarto self-contained HTML report
  template
- `inst/templates/eri_report.css` – Carter Center HTML report stylesheet

#### New vignettes

- `vignettes/dq-pipeline.Rmd` – DQ pipeline walkthrough: schema anatomy,
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
  anomaly detection, custom checks, and export
- `vignettes/spatial-workflow.Rmd` – loading and uploading admin
  boundaries, spatial joins, bbox expansion, choropleth maps
- `vignettes/epi-analytics.Rmd` – incidence rates, epiweek utilities, LF
  pooled prevalence, oncho status maps, branded tables
- `vignettes/research-workflow.Rmd` – project init, session management,
  lab notebook, snapshots, and full session walkthrough

## erifunctions 0.6.0

### Phase 5 — Spatial, epi analytics, and disease-specific functions

#### New functions

**Spatial data management** (`R/spatial.R`) -
[`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)
— read an admin boundary RDS from Azure
(`data/spatial/{country}/adm{level}.rds`) -
[`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
— validate (CRS, required name column, no empty geometries) and push a
local shapefile to Azure -
[`eri_bbox_expand()`](https://thecartercenter.github.io/erifunctions/reference/eri_bbox_expand.md)
— expand a bounding box by metres in each direction (port of
`sirfunctions::f.expand.bbox()`) -
[`eri_spatial_join()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_join.md)
— point-in-polygon join; drops rows with NA coordinates with a warning -
[`eri_landscan_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_upload.md)
— upload a LandScan raster to Azure; validates year and exact filename
convention -
[`eri_landscan_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_list.md)
— list available LandScan years from Azure; returns a tibble sorted
descending -
[`eri_spatial_pop()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_pop.md)
— extract population totals for a shapefile from LandScan via
`exactextractr`; auto-selects latest year if none given

**Visual style system** (`R/style.R`) -
[`eri_color_scheme()`](https://thecartercenter.github.io/erifunctions/reference/eri_color_scheme.md)
— return a named colour vector for `malaria.incidence`, `lf.status`,
`oncho.status`, `activities`, or `dq.flag` -
[`eri_plot_theme()`](https://thecartercenter.github.io/erifunctions/reference/eri_plot_theme.md)
— return a ggplot2 theme preset for `map`, `epicurve`, or `map.inset`

**Standard maps** (`R/maps.R`) -
[`eri_map_choropleth()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_choropleth.md)
— fill choropleth with optional scale bar and north arrow -
[`eri_map_incidence()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_incidence.md)
— malaria incidence rate map with automatic `0 / <1 / 1-10 / >=10`
binning -
[`eri_map_points()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_points.md)
— overlay point data on a shapefile base map -
[`eri_map_inset()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_inset.md)
— compose a main map with a country-context inset via `cowplot`

**Epi core analytics** (`R/epi.R`) -
[`eri_incidence_rate()`](https://thecartercenter.github.io/erifunctions/reference/eri_incidence_rate.md)
— vectorised cases / population × multiplier; returns `NA` for
zero/missing populations -
[`eri_epiweek_date()`](https://thecartercenter.github.io/erifunctions/reference/eri_epiweek_date.md)
— convert year + epiweek to a `Date`; supports CDC Sunday-start and ISO
Monday-start -
[`eri_study_week()`](https://thecartercenter.github.io/erifunctions/reference/eri_study_week.md)
— integer study week relative to an index date -
[`eri_epidemic_curve()`](https://thecartercenter.github.io/erifunctions/reference/eri_epidemic_curve.md)
— ggplot2 epidemic curve by day/week/month/year with optional grouping
and faceting -
[`eri_case_summary()`](https://thecartercenter.github.io/erifunctions/reference/eri_case_summary.md)
— grouped case counts from line-list or aggregate data with optional
date filtering

**LF programme functions** (`R/epi_lf.R`) -
[`eri_lf_pooled_prev()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_pooled_prev.md)
— pooled prevalence from pool-screening data:
`1 - ((1 - npos/npool)^(1/pool_size))` -
[`eri_lf_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_program_levels.md)
— ordered 5-level WHO/GPELF programme status vector -
[`eri_lf_tas_summary()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_tas_summary.md)
— group-level TAS positivity table (n and %) from individual result
data -
[`eri_lf_status_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_status_map.md)
— choropleth coloured by LF programme status

**OEPA oncho functions** (`R/epi_oncho.R`) -
[`eri_oncho_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_program_levels.md)
— ordered 5-level OEPA programme status vector -
[`eri_oncho_status_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_status_map.md)
— choropleth coloured by OEPA oncho programme status

#### New DQ schemas (`inst/schemas/`)

**LF (Hispaniola)** - `dr_lf_tas.yaml`, `ht_lf_tas.yaml` — individual
antigen test results; `discordant_fts_rdt` derived flag; consistency
check for FTS-Neg/RDT-Pos discordance requiring clinical review -
`dr_lf_mda.yaml`, `ht_lf_mda.yaml` — MDA coverage per EU per round;
`implied_coverage` derived; overcoverage consistency check

**Malaria case (Hispaniola)** - `dr_malaria_case.yaml` — DR individual
case record; `imported_flag` derived from non-DR province values
(Extranjero, Africa, Haiti, Venezuela, Otros) - `ht_malaria_case.yaml` —
Haiti aggregated commune-level; `admin_match` block validates department
(adm1) and commune (adm2) names against spatial boundaries

**OEPA oncho** - `oepa_oncho_mda.yaml` — MDA coverage per focus per
round; `overcoverage_flag` derived (treated \> 1.3× target); consistency
check for implausible overcoverage - `oepa_oncho_prevalence.yaml` —
prevalence survey (one row per person); lat/lon range checks for OEPA
region

#### Other changes

- [`add_anomaly_spatial()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_spatial.md)
  extended to support `admin_match` schema blocks — validates column
  values against canonical admin names loaded from Azure via
  [`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)
- `ggspatial` and `sf` added to `Imports`; `cowplot`, `exactextractr`,
  `ggnewscale` added to `Suggests`

## erifunctions 0.5.0

### Phase 4 – Research infrastructure

#### New functions

**Artifact registry** (`R/artifacts.R`) -
[`eri_artifact_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_upload.md)
– upload a non-standard reference file to `artifacts/{type}/{name}/` in
Azure and register it in `artifacts/_registry.yaml` -
[`eri_artifact_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_list.md)
– return a tibble of registered artifacts, filtered by type; excludes
archived entries by default -
[`eri_artifact_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_pull.md)
– download an artifact to a local destination; auto-records usage in
`research.yaml` if present -
[`eri_artifact_archive()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_archive.md)
– soft-delete (sets `archived: true`; file preserved in Azure)

**Research project scaffolding** (`R/research.R`) -
[`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md)
– scaffold local dirs (`data/`, `figs/`, `outputs/`), write
`research.yaml` manifest, create Azure project directory -
[`eri_research_resume()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_resume.md)
– re-read `research.yaml` and print session summary (last pull, last
log, snapshot count); call at the top of each work session -
[`eri_research_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_log.md)
– append a timestamped free-text entry to the `research.yaml` log (lab
notebook) -
[`eri_research_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_list.md)
– list all research projects under `research/` in Azure -
[`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
– pull canonical processed data or any Azure path into the local project
with provenance tracking -
[`eri_research_upload_figure()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_upload_figure.md)
– upload a figure to `research/{project}/outputs/figs/` and record in
manifest -
[`eri_research_upload_output()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_upload_output.md)
– serialize an R object via `qs2` and upload to
`research/{project}/outputs/` -
[`eri_research_snapshot()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_snapshot.md)
– freeze the full `data/` directory to a timestamped Azure snapshot with
a `_manifest.yaml`

**Template management** (`R/templates.R`) -
[`eri_template_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_list.md)
– list available templates (bundled + Azure-hosted); falls back to
bundled-only on Azure error -
[`eri_template_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_pull.md)
– copy a named template (bundled or Azure) to a local destination -
[`eri_template_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_upload.md)
– upload a `.qmd` or `.R` template to Azure and register it for team
sharing

**Research Quarto template** -
`inst/templates/eri_research_workflow.qmd` – epidemiologist research
workflow template; pull with
`eri_template_pull("eri_research_workflow")`

**Smoke tests** - `tests/testthat/test-smoke.R` – live integration test
suite (skipped in CI); covers data analyst and epidemiologist workflows
end-to-end against real Azure and ODK infrastructure; enable with
`Sys.setenv(ERI_SMOKE_TESTS = "true")`

#### Other changes

- Fixed non-ASCII characters (`--` replacing em dashes) in
  `R/research.R`
- [`eri_research_snapshot()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_snapshot.md)
  now validates local `data/` directory before attempting Azure
  connection

## erifunctions 0.4.0

### Phase 3 — ODK integration, data catalog, and onboarding

#### New functions

**ODK form registry** -
[`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md)
— register an ODK form in the shared Azure registry
(`odk/registry.yaml`) -
[`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md)
— soft-delete a registered form (preserves sync history) -
[`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md)
— list all active forms as a tibble

**ODK sync** -
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
— download new submissions for a registered form and write to Azure as
parquet

**Survey health** -
[`eri_survey_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_survey_status.md)
— fetch live submission counts and recency for one form, all forms in a
project, or all projects; S3 class with cli-based print method

**Bulk user management** -
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md)
— read a CSV of assign/remove/create actions, run pre-flight validation
(collects all errors before touching the API), then execute;
`dry_run = TRUE` previews without mutating

**Data catalog** -
[`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md)
— upsert a processed-layer file entry into
`_catalog/data_catalog.yaml` -
[`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md)
— filter catalog entries by country, disease, data_type, layer, or
period -
[`eri_catalog_verify()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_verify.md)
— check each entry exists in Azure; updates `last_verified_at` -
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
now automatically registers each promoted file in the catalog

**Onboarding** -
[`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md)
— write a surveillance DQ schema YAML template to your working directory
and create the three-layer Azure blob directories for a new
country/disease -
[`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)
— write a CMR schema YAML template locally; optionally create CMR Azure
dirs -
[`eri_schema_validate()`](https://thecartercenter.github.io/erifunctions/reference/eri_schema_validate.md)
— validate a local YAML schema file; returns a tidy tibble of structural
issues

**Analyst workflow** - `inst/templates/eri_daily_workflow.qmd` — Quarto
template covering the full analyst daily loop (connections, survey
health, sync, review, approve); copy to your project with
`file.copy(system.file("templates/eri_daily_workflow.qmd", package = "erifunctions"), ".")`

#### Other changes

- [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  wrapped with catalog registration (fail-silent so a catalog write
  never blocks an approval)
- ODK connection functions refactored to package standards (`cli`,
  `@export`, roxygen docs)

## erifunctions 0.3.0

### Phase 2 — CMR pipeline + DQ anomaly suite

#### New functions

- [`add_anomaly_pct_change()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_pct_change.md),
  [`add_anomaly_gaps()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_gaps.md),
  [`add_anomaly_consistency()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_consistency.md),
  [`add_anomaly_spatial()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_spatial.md)
  — full anomaly detection suite
- [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
  — dual-write surveillance ingestion with DQ checks
- [`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md),
  [`load_cmr_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_cmr_schema.md),
  [`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
  — CMR monthly report pipeline
- CMR schemas for 7 countries: `eth`, `nga`, `sdn`, `ssd`, `uga`
  (English); `mad`, `tcd` (French) with slug alias support

#### Other changes

- Added `"rb-expansion"` to the pipeline registry
- Added GitHub Actions CI workflow (ubuntu + windows, R release)
- Added `URL` and `BugReports` fields to DESCRIPTION

## erifunctions 0.2.0

### Phase 1 — Azure I/O and pipeline helpers

#### New functions

- [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md),
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
  [`eri_trigger()`](https://thecartercenter.github.io/erifunctions/reference/eri_trigger.md),
  [`eri_stage()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage.md)
- Session and operation logging to Azure `data/logs/_access/`
