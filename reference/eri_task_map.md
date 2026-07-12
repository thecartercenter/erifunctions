# Show the task registry: what are you trying to do?

**\[experimental\]**

Prints (and returns invisibly) the task registry: a tree of common
DA/Epi tasks grouped by intent, each naming a representative call, the
guide that walks it end to end (if any), and the reference functions it
touches. This is the shared source the generated [task index
article](https://thecartercenter.github.io/erifunctions/articles/task-index.md)
reads from (`inst/registry/task_map.yaml`).

## Usage

``` r
eri_task_map()
```

## Value

Invisibly, a data frame with one row per task: `branch`, `id`, `title`,
`role`, `call`, `guide`, `reference` (list-column), `next_ids`
(list-column).

## Examples

``` r
eri_task_map()
#> 
#> ── Task registry: what are you trying to do? ───────────────────────────────────
#> 
#> ── Get set up ──
#> 
#> • Install the package and connect to Azure, ODK, SharePoint, and Teams --
#>   `get_azure_storage_connection()` (guide: "connections-guide")
#> • Learn the data-addressing vocabulary (channel vs. measure) --
#>   `eri_data_model()` (guide: "data-model-card")
#> • Follow the paced new-analyst onboarding path -- `eri_data_model()` (guide:
#>   "onboarding")
#> 
#> ── Bring data into the system ──
#> 
#> • A monthly country report (CMR Excel workbook) -- `eri_stage_cmr(country,
#>   period)` (guide: "da-cmr-guide")
#> • A surveillance dataset (csv/xlsx from a country) -- `eri_ingest(path,
#>   country, disease, data_source, data_type)` (guide: "da-ingest-guide")
#> • ODK Central survey submissions -- `eri_odk_sync(project_id, form_id)` (guide:
#>   "da-odk-guide")
#> • Manage ODK Central users and roles -- `eri_odk_bulk_users(csv_path)`
#> • Admin boundaries or population rasters -- `eri_spatial_load(country, level)`
#>   (guide: "spatial-workflow")
#> • Compare a new pipeline's output against a legacy one before trusting it --
#>   `eri_compare(new, old, by)`
#> 
#> ── Check data quality and approve ──
#> 
#> • Review and approve a CMR workbook, interactively -- `eri_dq_review(country,
#>   period)` (guide: "da-dq-review-guide")
#> • QC a submission and give a country feedback -- `run_dq_checks(data, schema)`
#>   (guide: "da-qc-feedback-guide")
#> • Catch epidemiological anomalies (spikes, gaps) before analysis --
#>   `add_anomaly_pct_change(data, value_col, period_col, group_cols, year_col)`
#>   (guide: "epi-dq-guide")
#> • Fix or extend a DQ schema (allowed values, ranges) --
#>   `eri_dq_schema_edit(country, disease, data_source, data_type)` (guide:
#>   "dq-pipeline")
#> 
#> ── Work the backlog ──
#> 
#> • Find and close out failed or DQ log entries -- `eri_logs(country, disease,
#>   data_source, data_type)` (guide: "da-logs-guide")
#> • Reconstruct what happened to a dataset -- `eri_audit(country, disease,
#>   data_source, data_type)`
#> • File or triage internal feedback tickets -- `eri_feedback(message, area)`
#> • Share files via SharePoint or post to Teams --
#>   `eri_sharepoint_upload(local_path, site, folder_path)` (guide:
#>   "sharepoint-workflow")
#> 
#> ── Use approved data: query, analyse, report ──
#> 
#> • Answer an ad-hoc request with SQL -- `eri_query(sql)` (guide:
#>   "da-adhoc-guide")
#> • See what's in the catalog, or rebuild it -- `eri_catalog_query(country,
#>   disease)`
#> • Turn approved data into on-brand tables, plots, or decks -- `eri_table(data,
#>   title)` (guide: "da-reporting-guide")
#> • Summarise an approved survey (e.g. LF TAS) -- `eri_lf_tas_summary(data,
#>   fts_col, rdt_col)` (guide: "da-survey-report-guide")
#> • Incidence, epiweeks, and epidemic curves -- `eri_incidence_rate(cases, pop)`
#>   (guide: "epi-analytics")
#> 
#> ── Run a research study ──
#> 
#> • Start or resume a research project -- `eri_research_init(project_name)`
#>   (guide: "epi-research-guide")
#> • Log progress and manage artifacts as you go -- `eri_research_log(note)`
#> • Snapshot data and tag a citable, reproducible version --
#>   `eri_research_tag(label)`
#> • Pull or contribute a reusable research template -- `eri_template_list()`
#> 
#> ── Places and maps ──
#> 
#> • Reconcile free-text localities to admin units -- `eri_spatial_reconcile(data,
#>   loc_cols, shapefile, admin_cols)` (guide: "epi-reconcile-guide")
#> • Join points to admin units and map them -- `eri_spatial_join(data, lat_col,
#>   lon_col, shapefile)` (guide: "spatial-workflow")
#> • Get population totals for an area -- `eri_spatial_pop(boundaries)`
#> 
#> ── Add a new country, disease, or data type ──
#> 
#> • Onboard a new surveillance country or disease --
#>   `eri_onboard_country(country_code, country_name, disease)` (guide:
#>   "da-onboard-guide")
#> • Onboard a new CMR-reporting country -- `eri_onboard_cmr(country_code,
#>   country_name)` (guide: "da-onboard-guide")
#> • Contribute a schema or disease analytics to the package --
#>   `eri_schema_validate(schema_path)` (guide: "adding-a-program")
```
