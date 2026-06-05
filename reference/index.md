# Package index

## Connections & authentication

Authenticate to Azure, ODK, SharePoint, and Teams.

- [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)
  : Validate connection to Azure
- [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md)
  : Initialize an ODK Central connection
- [`eri_sharepoint_connect()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_connect.md)
  : Connect to a SharePoint site
- [`get_teams_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_teams_connection.md)
  : Connect to Microsoft Teams via the Graph API

## Reading & writing data

Read, write, list, and manage files in Azure (and locally).

- [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
  **\[experimental\]** : Read a file
- [`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md)
  **\[experimental\]** : Write an object to a file
- [`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md)
  **\[experimental\]** : Upload any local file to Azure
- [`eri_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_list.md)
  **\[experimental\]** : List files in a directory
- [`eri_file_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_file_exists.md)
  **\[experimental\]** : Check whether a file exists
- [`eri_dir_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_exists.md)
  **\[experimental\]** : Check whether a directory exists
- [`eri_dir_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_create.md)
  **\[experimental\]** : Create a directory
- [`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md)
  **\[experimental\]** : Delete a file
- [`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md)
  **\[experimental\]** : Delete a directory
- [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md)
  **\[experimental\]** : Build a canonical blob path in the data/
  container
- [`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
  **\[experimental\]** : erifunctions i/o handler
- [`azure_io()`](https://thecartercenter.github.io/erifunctions/reference/azure_io.md)
  : Helper function to read and write key data to the Azure environment

## Data pipeline

Ingest, stage, approve, and trigger surveillance and CMR pipelines.

- [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
  **\[experimental\]** : Ingest a local surveillance file and write
  cleaned output to both blob targets
- [`eri_stage()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage.md)
  **\[experimental\]** : Stage intermediate pipeline output into the
  data/ blob
- [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  **\[experimental\]** : Approve staged data and promote it to processed
- [`eri_trigger()`](https://thecartercenter.github.io/erifunctions/reference/eri_trigger.md)
  **\[experimental\]** : Trigger a registered GitHub Actions pipeline
- [`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md)
  **\[experimental\]** : Read and parse a CMR monthly report Excel file
- [`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
  **\[experimental\]** : Stage CMR monthly report files into the data/
  blob
- [`load_cmr_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_cmr_schema.md)
  **\[experimental\]** : Load a CMR country schema

## Data quality

Schema-driven DQ checks and anomaly detection.

- [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
  : Load a DQ schema
- [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
  : Run data quality checks on surveillance data
- [`print(`*`<dq_result>`*`)`](https://thecartercenter.github.io/erifunctions/reference/dq_result-methods.md)
  [`summary(`*`<dq_result>`*`)`](https://thecartercenter.github.io/erifunctions/reference/dq_result-methods.md)
  : S3 methods for dq_result objects
- [`dq_report()`](https://thecartercenter.github.io/erifunctions/reference/dq_report.md)
  : Print a formatted DQ summary report
- [`add_anomaly_pct_change()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_pct_change.md)
  **\[experimental\]** : Flag rows with unusual period-over-period
  percent change
- [`add_anomaly_gaps()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_gaps.md)
  **\[experimental\]** : Flag missing time periods in surveillance data
- [`add_anomaly_consistency()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_consistency.md)
  **\[experimental\]** : Flag cross-field consistency violations defined
  in a schema
- [`add_anomaly_spatial()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_spatial.md)
  **\[experimental\]** : Validate admin unit names against a spatial
  reference

## Data catalog

Register, query, and verify processed-layer data.

- [`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md)
  : Register a processed-layer file in the data catalog
- [`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md)
  : Query the data catalog
- [`eri_catalog_verify()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_verify.md)
  : Verify that catalog entries still exist in Azure

## ODK

Register forms, sync submissions, monitor surveys, and manage users.

- [`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md)
  : Register an ODK form in the shared Azure registry
- [`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md)
  : Deregister an ODK form from the shared Azure registry
- [`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md)
  : List all actively registered ODK forms
- [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
  : Sync an ODK form's submissions to Azure
- [`eri_survey_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_survey_status.md)
  : ODK form submission metrics
- [`print(`*`<survey_status>`*`)`](https://thecartercenter.github.io/erifunctions/reference/print.survey_status.md)
  : Print method for survey_status objects
- [`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md)
  : Manage ODK app users in bulk from a validated CSV
- [`list_odk_projects()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_projects.md)
  : List ODK projects
- [`list_odk_forms()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_forms.md)
  : List ODK forms within a project
- [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
  : Download all submissions from an ODK form
- [`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md)
  : Download all media attachments from an ODK form
- [`list_all_odk_app_users()`](https://thecartercenter.github.io/erifunctions/reference/list_all_odk_app_users.md)
  : List all app users in an ODK project
- [`list_odk_form_users()`](https://thecartercenter.github.io/erifunctions/reference/list_odk_form_users.md)
  : List users assigned to an ODK form
- [`update_odk_app_user_role()`](https://thecartercenter.github.io/erifunctions/reference/update_odk_app_user_role.md)
  : Create, delete, assign, or revoke an ODK app user role

## Spatial

Admin boundaries, LandScan population, and spatial joins.

- [`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)
  : Load admin boundary from Azure
- [`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
  : Upload an admin boundary shapefile to Azure
- [`eri_spatial_join()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_join.md)
  : Join point data to admin boundaries
- [`eri_spatial_pop()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_pop.md)
  : Extract population from LandScan into spatial polygons
- [`eri_bbox_expand()`](https://thecartercenter.github.io/erifunctions/reference/eri_bbox_expand.md)
  : Expand a bounding box by a distance in metres
- [`eri_landscan_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_upload.md)
  : Upload a LandScan population raster to Azure
- [`eri_landscan_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_list.md)
  : List LandScan rasters available in Azure

## Epi analytics

Incidence, epiweeks, epidemic curves, and disease-specific functions.

- [`eri_incidence_rate()`](https://thecartercenter.github.io/erifunctions/reference/eri_incidence_rate.md)
  : Compute incidence rate per population
- [`eri_case_summary()`](https://thecartercenter.github.io/erifunctions/reference/eri_case_summary.md)
  : Summarise case data by grouping columns
- [`eri_epidemic_curve()`](https://thecartercenter.github.io/erifunctions/reference/eri_epidemic_curve.md)
  : Standard epidemic curve
- [`eri_epiweek_date()`](https://thecartercenter.github.io/erifunctions/reference/eri_epiweek_date.md)
  : Convert CDC epiweek and year to a Date
- [`eri_study_week()`](https://thecartercenter.github.io/erifunctions/reference/eri_study_week.md)
  : Calculate study week relative to an index date
- [`eri_date_to_epiweek()`](https://thecartercenter.github.io/erifunctions/reference/eri_date_to_epiweek.md)
  : Convert a Date to a CDC epiweek number
- [`eri_epiweek_range()`](https://thecartercenter.github.io/erifunctions/reference/eri_epiweek_range.md)
  : Filter data to an epiweek range
- [`eri_lf_pooled_prev()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_pooled_prev.md)
  : Pooled prevalence estimator for LF antigen surveys
- [`eri_lf_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_program_levels.md)
  : Standard LF programme status levels
- [`eri_lf_tas_summary()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_tas_summary.md)
  : Summarise LF TAS antigen test results
- [`eri_lf_status_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_status_map.md)
  : LF programme status choropleth map
- [`eri_oncho_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_program_levels.md)
  : OEPA onchocerciasis program status levels
- [`eri_oncho_status_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_status_map.md)
  : Choropleth map of OEPA oncho program status by focus

## Reporting & visual style

Branded tables, themes, maps, and Excel/HTML/PowerPoint reports.

- [`eri_brand_colors()`](https://thecartercenter.github.io/erifunctions/reference/eri_brand_colors.md)
  : Carter Center brand colour palette
- [`eri_brand_ggplot_theme()`](https://thecartercenter.github.io/erifunctions/reference/eri_brand_ggplot_theme.md)
  : ERI-branded ggplot2 theme
- [`eri_color_scheme()`](https://thecartercenter.github.io/erifunctions/reference/eri_color_scheme.md)
  : ERI standard colour schemes
- [`eri_plot_theme()`](https://thecartercenter.github.io/erifunctions/reference/eri_plot_theme.md)
  : ERI standard ggplot2 themes
- [`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
  : ERI-branded formatted table
- [`eri_map_choropleth()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_choropleth.md)
  : Choropleth map from a shapefile and data frame
- [`eri_map_incidence()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_incidence.md)
  : Incidence choropleth map
- [`eri_map_points()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_points.md)
  : Point overlay map
- [`eri_map_inset()`](https://thecartercenter.github.io/erifunctions/reference/eri_map_inset.md)
  : Add an inset reference map to a main map
- [`eri_report_excel()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_excel.md)
  : Write a multi-sheet ERI-branded Excel report
- [`eri_wb_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_create.md)
  : Create an ERI-branded Excel workbook
- [`eri_wb_add_sheet()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_add_sheet.md)
  : Add a styled data sheet to an ERI workbook
- [`eri_wb_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_save.md)
  : Save an ERI workbook to disk
- [`eri_report_html()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_html.md)
  : Render an ERI-branded self-contained HTML report
- [`eri_report_qmd_template()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_qmd_template.md)
  : Copy the bundled ERI report Quarto template
- [`eri_pptx_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_create.md)
  : Create an ERI-branded PowerPoint presentation
- [`eri_pptx_add_title()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_title.md)
  : Add a title slide to an ERI PowerPoint
- [`eri_pptx_add_section()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_section.md)
  : Add a section divider slide to an ERI PowerPoint
- [`eri_pptx_add_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_table.md)
  : Add a data table slide to an ERI PowerPoint
- [`eri_pptx_add_plot()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_add_plot.md)
  : Add a ggplot figure slide to an ERI PowerPoint
- [`eri_pptx_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_save.md)
  : Save an ERI PowerPoint to disk

## Research projects

Scaffold studies, track provenance, manage artifacts, and snapshot data.

- [`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md)
  : Initialise a new research project
- [`eri_research_scaffold()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_scaffold.md)
  : Scaffold a new research-project repository
- [`eri_research_resume()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_resume.md)
  : Resume a research project session
- [`eri_research_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_log.md)
  : Add an entry to the research lab notebook
- [`eri_research_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_list.md)
  : List all research projects in Azure
- [`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
  : Pull data from Azure into a research project
- [`eri_research_upload_figure()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_upload_figure.md)
  : Upload a figure to the research project outputs in Azure
- [`eri_research_upload_output()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_upload_output.md)
  : Upload an R object to the research project outputs in Azure
- [`eri_research_snapshot()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_snapshot.md)
  : Snapshot the full research project data directory to Azure
- [`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md)
  : Tag a reproducible, citable version of a research project
- [`eri_artifact_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_upload.md)
  : Upload a non-standard reference file to the artifact registry
- [`eri_artifact_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_list.md)
  : List registered artifacts
- [`eri_artifact_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_pull.md)
  : Download an artifact from the registry to a local destination
- [`eri_artifact_archive()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_archive.md)
  : Archive an artifact (soft-delete)
- [`eri_template_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_list.md)
  : List available Quarto and R templates
- [`eri_template_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_pull.md)
  : Copy a template to a local destination
- [`eri_template_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_upload.md)
  : Upload a custom template to Azure

## SharePoint & Teams

Share files via SharePoint and post notifications to Teams.

- [`eri_sharepoint_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_list.md)
  : List files in a SharePoint document library folder
- [`eri_sharepoint_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_read.md)
  : Read a file from SharePoint into R
- [`eri_sharepoint_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_upload.md)
  : Upload a local file to a SharePoint document library
- [`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md)
  : Send a message to Microsoft Teams
- [`eri_notify_dq()`](https://thecartercenter.github.io/erifunctions/reference/eri_notify_dq.md)
  : Send a DQ result summary to Microsoft Teams

## Onboarding new programs

Scaffold schemas and Azure directories for a new country, disease, or
CMR.

- [`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md)
  : Scaffold a new country/disease surveillance setup
- [`eri_onboard_disease()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_disease.md)
  : Scaffold DQ schema YAML files for a new disease program
- [`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)
  : Scaffold a new country CMR schema
- [`eri_schema_validate()`](https://thecartercenter.github.io/erifunctions/reference/eri_schema_validate.md)
  : Validate a local DQ schema YAML file
