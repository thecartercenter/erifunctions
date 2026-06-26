# Changelog

## erifunctions (development version)

### Documentation: an Epidemiologist locality-reconciliation guide

- **New article — “Reconciling free-text localities to admin units”**
  (`vignettes/epi-reconcile-guide.Rmd`). A run-it-live walkthrough of
  [`eri_spatial_reconcile()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_reconcile.md)
  for epidemiologists: match messy place names to canonical admin units
  offline, geocode the residual (keyless OpenStreetMap), and interpret
  the trust-guarded `reconcile_status` (`matched` / `geocoded` /
  `geocoded_review` / `unresolved`). Fills the gap that
  `spatial-workflow.Rmd` left — that vignette never covered
  reconciliation.

### Error & data-quality log triage (Phase 5)

- **[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
  – new.** Reads the structured operation logs (written by
  [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md),
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
  [`eri_stage()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage.md),
  [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
  …) and the new data-quality logs across
  `{country}/{disease}/{data_type}/logs/` in the `data/` blob, and
  returns them as a triage backlog tibble. Filter by `status`
  (`"error"`, `"needs_review"`, …), `operation`, `analyst`, or `since`;
  scope to one dataset or scan the whole system. Because the logs live
  in Azure, the backlog is shared — a teammate can see exactly what
  failed and pick up where you left off.
- **[`eri_dq_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_log.md)
  – new.** Persists
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)’s
  `$flags` to the log backlog so data-quality issues are durable and
  discoverable, not just in-session.
  [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
  now calls it automatically after its DQ checks.
- **[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
  – new.** Marks a log entry handled (records who/when/note in a
  `triage` block) so it drops off the open backlog without deleting the
  record.
- **New article — “Triaging the error & data-quality log backlog”**
  (`vignettes/da-logs-guide.Rmd`) walks the workflow on the `atlantis`
  sandbox. Closes the last open Data Analyst row in `docs/guides.md`
  (previously blocked on the
  [`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
  function gap).

### Documentation: an onboarding guide for data analysts

- **New article — “Onboarding a new country, disease, or data type”**
  (`vignettes/da-onboard-guide.Rmd`). The prequel to the ingest and ODK
  guides: how a Data Analyst stands up the DQ schema +
  `raw/staged/processed` folders for a new program before any data
  flows. Covers all three scaffolding paths —
  [`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md)
  (surveillance),
  [`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)
  (CMR), and
  [`eri_onboard_disease()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_disease.md)
  (NTD MDA + prevalence) — plus the `dry_run` preview and
  [`eri_schema_validate()`](https://thecartercenter.github.io/erifunctions/reference/eri_schema_validate.md)
  (valid + a broken→fixed example), on the `atlantis` sandbox.
  Complements the existing “Adding a new program” vignette (which covers
  contributing a finished schema to the package).

### Documentation: a connections & authentication guide

- **New article — “Connecting to Azure, ODK Central, SharePoint, and
  Teams”** (`vignettes/connections-guide.Rmd`). The single reference for
  every external connection `erifunctions` makes: how to authenticate to
  each service, a “confirm it works” check per service, one consolidated
  `.Renviron` template, brief automation/CI (service-principal / token /
  webhook) callouts, and a troubleshooting table. The role guides now
  point here instead of each re-explaining auth.

### Documentation: a worked ODK Central guide for data analysts

- **New article — “Working with ODK Central”**
  (`vignettes/da-odk-guide.Rmd`). A hands-on, run-it-live walkthrough of
  the full ODK loop for a Data Analyst: connect with
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md),
  stand up a practice form, monitor it with
  [`eri_survey_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_survey_status.md),
  manage collectors with
  [`update_odk_app_user_role()`](https://thecartercenter.github.io/erifunctions/reference/update_odk_app_user_role.md)
  /
  [`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md),
  register it, and
  [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
  its submissions into the governed `raw → staged → approved` pipeline —
  then clean up. The package now ships a small practice XLSForm
  (`inst/extdata/odk-test-form.xlsx`) the reader uploads to a sandbox
  `test` project.
- **[`eri_survey_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_survey_status.md)
  fix.** The form-metadata request now sends the
  `X-Extended-Metadata: true` header, so `total_submissions` and
  `last_submission_at` are populated. Previously these fields were
  omitted by ODK Central and `total_submissions` was always `0`.

### Documentation: a worked ingest guide for data analysts

- **New article — “Ingesting a surveillance dataset: raw to approved”**
  (`vignettes/da-ingest-guide.Rmd`). A copy-paste, hands-on walkthrough
  of the core Data Analyst job: take a dataset through the `raw/` →
  `staged/` → `processed/` pipeline, with
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  as the human gate. The reader stands up a make-believe country
  (*Atlantis*) as a private sandbox, invents a small malaria line-list,
  **authors its DQ schema**, runs
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
  stages and approves it — then handles a **second extract seeded with
  errors** (an impossible age and an unknown district) to learn the
  difference between auto-corrections and review flags, before deleting
  the whole sandbox. Runs live on any laptop and leaves no trace. Flips
  the matching row in `docs/guides.md` to shipped.
- **[`eri_catalog_remove()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_remove.md)
  – new.** Deletes a file’s entry from the data catalog
  (`_catalog/data_catalog.yaml`) by path — the inverse of
  [`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md),
  for when a processed file has been deleted or superseded. (Used by the
  new guide’s clean-up step.)

### Documentation: a worked research guide for epidemiologists

- **New article — “A complete research workflow for epidemiologists”**
  (`vignettes/epi-research-guide.Rmd`). A copy-paste, start-to-finish
  walkthrough of the whole research lifecycle — scaffold a project, put
  it under version control with the reproducibility check, add data with
  metadata, source it, analyse, save outputs and figures, tag a citable
  version, pause and resume weeks later, take in an updated dataset, and
  tidy up. It uses the public `mtcars` dataset (initial `am == 0` subset
  → expanded to the full dataset to simulate new data arriving), so any
  epidemiologist can run it live on their laptop and delete every
  resource at the end. Supersedes the older, partly-stale
  `research-workflow` vignette.
- **New `docs/guides.md`** — an index of task guides (one per user role
  × task) tracking what exists and what is still missing, seeding the
  framework the epi guide is the first of.

### Console output: clearer, calmer, and tunable

For non-developer users a stack of anonymous progress bars looks like
the package has hung. The console output is overhauled package-wide:

- **One informative progress bar instead of many.** Multi-file transfers
  (e.g. [`eri_research_snapshot()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_snapshot.md)
  uploading 17 files,
  [`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md))
  now show a single bar that names the current file and its position
  (`3/17`), rather than a stack of AzureStor’s anonymous `|====| 100%`
  bars. The native per-transfer bar is suppressed everywhere and
  replaced with `cli` output; it is kept only for a genuinely large
  single file (e.g. the ~100 MB LandScan raster) so a long download
  still shows life.
- **Summary end-caps.** Multi-step operations
  ([`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md),
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
  [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md))
  finish with a tidy `✔`-titled key/value summary of what happened.
- **[`eri_verbosity()`](https://thecartercenter.github.io/erifunctions/reference/eri_verbosity.md)
  – new.** Controls how chatty the console is: `"full"` (default –
  step-by-step confirmations and summaries) or `"quiet"` (headline
  results, warnings, and errors only). Set it for a whole project via
  `options(erifunctions.verbosity = "quiet")` in `.Rprofile`, per
  session with `eri_verbosity("quiet")`, or via the
  `ERIFUNCTIONS_VERBOSITY` environment variable.

### Fixes

- [`eri_research_scaffold()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_scaffold.md):
  the generated reproducibility-check workflow now installs the
  geospatial/Azure system libraries (`gdal`/`proj`/`geos`/`udunits`,
  `curl`/`openssl`) and uses Posit Public Package Manager binaries
  (`use-public-rspm: true`). Previously
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  on the Ubuntu runner tried to build `curl` (and the `sf` geospatial
  stack) from source with no `-dev` libraries present and failed, so the
  check was red for any real research project. Validated on the
  `dr_irs_2026` reference repo.

### Research data lifecycle (issue [\#148](https://github.com/thecartercenter/erifunctions/issues/148), ADR-0009)

- [`eri_spatial_promote()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_promote.md)
  – **new**: the explicit gate for pushing a boundary cleaned in a
  research project up to the shared canonical `spatial/` store,
  recording the promotion (who, what, when, whether it replaced an
  existing boundary, and where the prior version was archived) in
  `research.yaml`. Replacing an existing canonical boundary requires
  `overwrite = TRUE`.
- [`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
  is now **overwrite-safe**: it refuses to clobber an existing canonical
  boundary (shared cleaned data many users pull for figures) unless
  `overwrite = TRUE`, and points to
  [`eri_spatial_promote()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_promote.md)
  for deliberate replacement. Reads of the canonical/cached `.rds`
  format are now supported alongside shapefiles.
- **Canonical overwrites are archived.** A deliberate `overwrite = TRUE`
  (via either
  [`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
  or
  [`eri_spatial_promote()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_promote.md))
  first copies the prior canonical boundary to
  `spatial/_archive/<timestamp>/`, so replacing shared reference data is
  reversible (ADR-0009).
- [`eri_research_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_status.md)
  now also reports boundary **promotions** the project has made to
  canonical (summarised separately from the inbound input table).
- [`eri_research_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_status.md)
  – **new**: a manifest of every input a project depends on (source,
  `pulled_at`, update count, whether a prior version was archived) plus
  output/snapshot/tag counts. `check_remote = TRUE` flags inputs whose
  Azure source is newer than the local copy.
- [`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
  now does **update-with-archival**: a re-pull moves the prior local
  version into `data/_archive/<timestamp>/` and records it, and
  **dedups** `pulled_data` (a re-pull of the same source replaces its
  record instead of appending a duplicate, and collapses any
  pre-existing duplicates). `eri_spatial_load(cache = TRUE)` inherits
  this.
- [`eri_spatial_pop()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_pop.md)
  now **caches the LandScan raster in the project and reuses it** rather
  than re-downloading ~100 MB on every call; records provenance when run
  inside a research project.
- [`eri_landscan_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_list.md)
  no longer warns when the LandScan directory simply does not exist yet
  (returns an empty tibble quietly).
- **ADLS-safe directory creation is now centralized.** The
  trailing-slash trim + missing-parent creation previously local to
  `R/research.R` (`.eri_ensure_azure_dir()`) is promoted into the DAL as
  [`.eri_create_azure_dir()`](https://thecartercenter.github.io/erifunctions/reference/dot-eri_create_azure_dir.md);
  `azure_io("create")` and every nested-path write site (`artifacts.R`,
  `catalog.R`, `odk_registry.R`, `onboarding.R`, `cmr.R`, `templates.R`,
  `research.R`) now route through it instead of calling
  [`AzureStor::create_storage_dir()`](https://rdrr.io/pkg/AzureStor/man/generics.html)
  directly. Robustness/ consistency fix from the PR
  [\#147](https://github.com/thecartercenter/erifunctions/issues/147)
  review.

### Azure access: zero-config interactive auth + ADLS Gen2 fixes

- [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)
  ships working defaults for interactive (browser) auth, so analysts and
  epidemiologists configure nothing: `app_id` defaults to Microsoft’s
  first-party Azure CLI public client and `tenant_id` /
  `resource_endpoint` to the team’s Entra tenant and the `eridev` ADLS
  endpoint. All remain overridable via the existing `ERIFUNCTIONS_*` env
  vars; the service-principal secret stays env-only. One Microsoft
  sign-in covers Azure Storage (and, later, Microsoft Graph).
- Fixed research-project directory creation on **ADLS Gen2**: paths with
  a trailing slash returned `HTTP 400 (request URI is invalid)` and
  intermediate parents were not created. New internal
  `.eri_ensure_azure_dir()` trims trailing slashes and creates each
  missing parent level; all `R/research.R` directory sites use it.
- [`eri_research_scaffold()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_scaffold.md)
  normalizes a trailing slash in `dest`, and its partial-failure message
  now explains how to recover (finish
  [`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md)
  in place, or [`unlink()`](https://rdrr.io/r/base/unlink.html) +
  re-scaffold).

### V2 Phase 1 – dr_irs vertical slice (in progress)

- [`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md)
  – bind a frozen data snapshot, the analysis git commit, the input
  provenance, and the output manifest into an immutable, citable tag in
  Azure, recorded in `research.yaml`. Makes a tagged analysis
  reproducible from a citation, including across data updates. Tags are
  immutable and auto-create a snapshot if none exists.
  ([\#135](https://github.com/thecartercenter/erifunctions/issues/135))
- `eri_spatial_load(cache = TRUE)` – cache an admin boundary into the
  research project and record its provenance (delegating to
  [`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)),
  then read the local copy, so a study’s spatial inputs are reproducible
  and frozen by
  [`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md).
  See ADR-0007.
  ([\#133](https://github.com/thecartercenter/erifunctions/issues/133))
- [`eri_research_scaffold()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_scaffold.md)
  – create a standalone research-project repo skeleton (README,
  `analysis/` seeded from the workflow template, data-safe `.gitignore`,
  minimal reproducibility
  101. plus the standard research scaffold via
       [`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md).
       Implements ADR-0006.
       ([\#136](https://github.com/thecartercenter/erifunctions/issues/136))
- [`eri_spatial_reconcile()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_reconcile.md)
  – thin, opt-in data-sourcing helper that maps free-text locality names
  to canonical admin units: normalized exact/fuzzy match against the
  boundary `sf` first, then geocodes only the unmatched (via
  `tidygeocoder`, `method = NULL` to disable) and assigns admin units by
  point-in-polygon through
  [`eri_spatial_join()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_join.md).
  Returns the data with names reconciled in place plus coordinates and a
  `reconcile_status` column. Only place-name strings are sent to the
  geocoder.
  ([\#134](https://github.com/thecartercenter/erifunctions/issues/134))
  - When a keyed method (e.g. `method = "google"`) is selected without
    its API key set,
    [`eri_spatial_reconcile()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_reconcile.md)
    now aborts up front with guidance to store the key once in the user
    `.Renviron` (e.g. `GOOGLEGEOCODE_API_KEY`), rather than surfacing a
    lower-level geocoder error.
    ([\#143](https://github.com/thecartercenter/erifunctions/issues/143))
  - Geocodes are now trusted (status `"geocoded"`, names assigned) only
    when the service did not flag a partial/low-confidence match *and*
    the assigned coarser admin units agree with the parent levels
    supplied. Otherwise the row is flagged `"geocoded_review"`:
    coordinates are kept for inspection but the analyst’s names are left
    untouched. Guards against geocoders that best-guess a fabricated or
    unmatched locality into a plausible point.
    ([\#145](https://github.com/thecartercenter/erifunctions/issues/145))

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
