# What are you trying to do?

**Desk reference** · ~2 min to scan · needs: nothing · sandbox-safe: yes
(reads a bundled file, nothing runs)

Every task below is a real one, generated from the same registry
(`inst/registry/task_map.yaml`) that backs
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md).
Find your task, then follow its **Run** call or its **Guide**. New to
the package? [Getting
started](https://thecartercenter.github.io/erifunctions/articles/getting-started.md)
is a better front door; this page is for when you already know what
you’re trying to do and just need the entry point.

| Category | I want to… | Run | Guide |
|:---|:---|:---|:---|
| Get set up | Install the package and connect to Azure, ODK, SharePoint, and Teams | [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md) | [guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md) |
| Get set up | Learn the data-addressing vocabulary (channel vs. measure) | [`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md) | [guide](https://thecartercenter.github.io/erifunctions/articles/data-model-card.md) |
| Get set up | Follow the paced new-analyst onboarding path | [`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md) | [guide](https://thecartercenter.github.io/erifunctions/articles/onboarding.md) |
| Bring data into the system | A monthly country report (CMR Excel workbook) | `eri_stage_cmr(country, period)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md) |
| Bring data into the system | A surveillance dataset (csv/xlsx from a country) | `eri_ingest(path, country, disease, data_source, data_type)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md) |
| Bring data into the system | ODK Central survey submissions | `eri_odk_sync(project_id, form_id)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.md) |
| Bring data into the system | Manage ODK Central users and roles | `eri_odk_bulk_users(csv_path)` |  |
| Bring data into the system | Admin boundaries or population rasters | `eri_spatial_load(country, level)` | [guide](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md) |
| Bring data into the system | Compare a new pipeline’s output against a legacy one before trusting it | `eri_compare(new, old, by)` |  |
| Check data quality and approve | Review and approve a CMR workbook, interactively | `eri_dq_review(country, period)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-dq-review-guide.md) |
| Check data quality and approve | QC a submission and give a country feedback | `run_dq_checks(data, schema)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-qc-feedback-guide.md) |
| Check data quality and approve | Catch epidemiological anomalies (spikes, gaps) before analysis | `add_anomaly_pct_change(data, value_col, period_col, group_cols, year_col)` | [guide](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.md) |
| Check data quality and approve | Fix or extend a DQ schema (allowed values, ranges) | `eri_dq_schema_edit(country, disease, data_source, data_type)` | [guide](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md) |
| Work the backlog | Find and close out failed or DQ log entries | `eri_logs(country, disease, data_source, data_type)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md) |
| Work the backlog | Reconstruct what happened to a dataset | `eri_audit(country, disease, data_source, data_type)` |  |
| Work the backlog | File or triage internal feedback tickets | `eri_feedback(message, area)` |  |
| Work the backlog | Share files via SharePoint or post to Teams | `eri_sharepoint_upload(local_path, site, folder_path)` | [guide](https://thecartercenter.github.io/erifunctions/articles/sharepoint-workflow.md) |
| Use approved data: query, analyse, report | Answer an ad-hoc request with SQL | `eri_query(sql)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-adhoc-guide.md) |
| Use approved data: query, analyse, report | See what’s in the catalog, or rebuild it | `eri_catalog_query(country, disease)` |  |
| Use approved data: query, analyse, report | Turn approved data into on-brand tables, plots, or decks | `eri_table(data, title)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-reporting-guide.md) |
| Use approved data: query, analyse, report | Summarise an approved survey (e.g. LF TAS) | `eri_lf_tas_summary(data, fts_col, rdt_col)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-survey-report-guide.md) |
| Use approved data: query, analyse, report | Incidence, epiweeks, and epidemic curves | `eri_incidence_rate(cases, pop)` | [guide](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md) |
| Run a research study | Start or resume a research project | `eri_research_init(project_name, country, disease, description)` | [guide](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.md) |
| Run a research study | Log progress and manage artifacts as you go | `eri_research_log(note)` |  |
| Run a research study | Snapshot data and tag a citable, reproducible version | `eri_research_tag(label)` |  |
| Run a research study | Pull or contribute a reusable research template | [`eri_template_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_list.md) |  |
| Places and maps | Reconcile free-text localities to admin units | `eri_spatial_reconcile(data, loc_cols, shapefile, admin_cols)` | [guide](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.md) |
| Places and maps | Join points to admin units and map them | `eri_spatial_join(data, lat_col, lon_col, shapefile)` | [guide](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md) |
| Places and maps | Get population totals for an area | `eri_spatial_pop(shapefile)` |  |
| Add a new country, disease, or data type | Onboard a new surveillance country or disease | `eri_onboard_country(country_code, country_name, disease)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md) |
| Add a new country, disease, or data type | Onboard a new CMR-reporting country | `eri_onboard_cmr(country_code, country_name)` | [guide](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md) |
| Add a new country, disease, or data type | Contribute a schema or disease analytics to the package | `eri_schema_validate(schema_path)` | [guide](https://thecartercenter.github.io/erifunctions/articles/adding-a-program.md) |

Prefer the console?
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
prints this same tree interactively, grouped by category, with every
reference function each task touches:

``` r

eri_task_map()
```
