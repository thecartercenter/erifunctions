# erifunctions (development version)

## Feature: `eri_research_pull()` speaks the five-axis model (ADR-0012, #175 phase 4b)

- `eri_research_pull()` — the Epi sourcing entry point — now takes `data_source` (the channel) plus an
  optional `data_type` (the measure), matching the coordinates [eri_catalog_query()] reports, so a study
  pulls canonical processed data with the same tokens a discovery query returns:
  `eri_research_pull("dr", "malaria", "surveillance", "case")`. Path construction delegates to
  `eri_data_path()`, so the four-axis (channel-only) form works too. **Back-compat:** the pre-ADR-0012
  form where the channel was passed as `data_type` (`data_type = "surveillance"`) still resolves to the
  same processed path. Surfaced by a fresh-Epi red-team run as the one un-migrated step on the sourcing path.

## Feature: the measure (`data_type`) reaches the human gate and the catalog (ADR-0012, #175 phase 4b)

- `eri_approve()` gains an optional `data_type` (the measure) argument:
  `eri_approve(country, disease, data_source, period, data_type = NULL, …)`. When supplied it promotes
  the full five-axis path `{country}/{disease}/{data_source}/{data_type}/staged → processed/` and records
  the measure in the approval log, the operation log, and the catalog. The third positional argument is
  now named `data_source` (it always carried the channel); `data_type` defaults to `NULL`, so existing
  four-axis calls — `eri_approve("dr", "malaria", "surveillance", "2024-W01")` — are unchanged.
- The data catalog carries a `data_source` column alongside `data_type`, and `eri_catalog_register()` /
  `eri_catalog_query()` gain a `data_source` argument (`eri_catalog_register(... , data_source, ... ,
  data_type = NULL)`; `eri_catalog_query(... , data_source = NULL, data_type = NULL, ...)`). Four-axis
  entries leave `data_type` as `NA`. Legacy positional `eri_catalog_register()` calls that passed the
  channel as `data_type` now pass it as `data_source`.
- The log triage reader follows the writer: `eri_logs()` scans both the four-axis channel-level
  `…/{data_source}/logs/` and the five-axis measure-level `…/{data_source}/{data_type}/logs/` layouts, and
  its backlog tibble gains a `data_source` column with `data_type` now meaning the measure.
  `eri_logs(country, disease, data_source, data_type = NULL, …)` and
  `eri_dq_log(result, country, disease, data_source, data_type = NULL, …)` rename the old third/fourth
  argument to `data_source` (it always held the channel) and add the optional measure. Positional callers
  passing the channel third are unchanged.

## Feature: onboarding scaffolders emit the 4-part schema identity (ADR-0012, #175 phase 4a)

- `eri_onboard_disease()` and `eri_onboard_country()` now write schema skeletons named to the ADR-0012
  identity `{country}_{disease}_{data_source}_{data_type}.yaml` with `data_source` / `data_type` header
  fields: `mda` → `programmatic` / `treatment`, `prevalence` → `research` / `prevalence`, and
  surveillance → `surveillance` / `{data_type}` (new `eri_onboard_country(data_type = "aggregate")`
  argument). So a freshly onboarded program is consistent with the migrated bundled schemas and loads
  via the 4-arg `load_dq_schema()`. The DA onboarding guide is updated to match.

## Feature: `eri_ingest()` is a general, sandbox-runnable ingest core (ADR-0012, #175 phase 3a)

- `eri_ingest()` no longer requires the `hsp-mal` pipeline registry or a registered country, and no
  longer *forces* a write to the legacy `projects` blob. It reads, DQ-checks, and stages to
  `data/{country}/{disease}/{data_source}/staged/` on **any** data — so the guides can finally teach it
  on a throwaway sandbox. Signature: `eri_ingest(path, country, disease, data_source = "surveillance",
  data_type = "aggregate", …)`.
- The legacy `projects`-blob dual-write is now the **opt-in `mirror_pipeline`** argument (default
  `NULL`); legacy callers pass `mirror_pipeline = "hsp-mal"`. The `.eri_schema_country_map` hack is
  retired (schemas are code-prefixed now). These mirror bits are transitional and removed at the
  Phase-3 hsp-mal cutover.

## Feature: DQ schemas keyed by `(country, disease, data_source, data_type)` (ADR-0012, #175 phase 2)

- Bundled schemas are renamed to `{country}_{disease}_{data_source}_{data_type}.yaml` and carry
  `data_source` / `format` fields. `data_source` is `surveillance` / `programmatic` / `research`; **ODK
  is a research `format`** and **CMR a programmatic `format`** (the channel, not the lane). Country codes
  are normalised (`ug` → `uga`) and disease names too (`rb` → `oncho`).
- `load_dq_schema()` gains the four-argument identity form
  `load_dq_schema(country, disease, data_source, data_type)` (the measure is optional for `research`).
  The legacy two-argument form — where the second argument held a combined key like `"malaria_case"` or
  `"lf_tas"` — **still resolves** via an alias to the new name, so existing callers keep working.
- DR and HT malaria each keep **both** a `case` and an `aggregate` surveillance schema (they are distinct,
  not duplicates). Part of the #175 migration (ADR-0012).
- *Deferred to phase 4:* the `eri_onboard_*` scaffolders and the `adding-a-program` / `epi-analytics` /
  `da-ingest` guides still emit/teach the old `{country}_{disease}_{type}` names; they keep working via
  the alias shim and are swept to the four-part identity with the rest of the docs/onboarding pass.

## Feature: five-axis data addressing — `data_source` vs `data_type` (ADR-0012, #175 phase 1)

- The canonical path gains a measure axis:
  `data/{country}/{disease}/{data_source}/{data_type}/{layer}/`. `data_source` is the **channel**
  (`surveillance`, `programmatic`, `odk`); `data_type` is the **measure** (`case`, `aggregate`,
  `treatment`, `tas`, …). See [ADR-0012](docs/adr/0012-source-measure-data-model.md).
- `eri_data_path()` now takes `(country, disease, data_source, data_type, layer, filename)`. The legacy
  four-axis form `eri_data_path(country, disease, data_source, layer)` still resolves during the
  migration (detected because its fourth argument is a `layer` keyword), so existing callers keep
  working.
- New `eri_data_model()` shows the registry of known `data_source` / `data_type` / `format` values. The
  axes are **extensible**: an unregistered value *warns* rather than errors, so onboarding a new
  source/measure never blocks data — first step of the ADR-0012 migration that will close #175.

## Docs: one vocabulary for addressing data and schemas

- A new README section ("How data is addressed") names the four path axes — `country` / `disease` /
  `data_type` / `layer` — and clarifies that a DQ **schema key** (e.g. `malaria_case`, passed to
  `load_dq_schema()`) is *not* a `data_type`. `eri_data_path()`'s error now says so explicitly when a
  schema key is passed where a `data_type` belongs. This is Phase 1 of
  [ADR-0011](docs/adr/0011-unified-schema-naming.md); the bundled schema names will be unified to one
  convention in a follow-up (#175). Fixes the user-facing half of a fresh-user red-team finding.

## Improvement: `eri_spatial_reconcile()` surfaces the geocoded admin unit for review

- The function now returns one `geocoded_<admin_col>` column per admin level, holding the admin units
  the geocoded point fell into (point-in-polygon). They are filled for every geocoded row that landed
  inside a polygon — **including `geocoded_review` rows** — so a flagged row shows *exactly* what its
  geocoded location disagreed with, and you can resolve it without re-running a spatial join by hand.
  (`NA` for `matched`, `unresolved`, and outside-polygon rows.) Fixes a fresh-user red-team finding
  (#174).

## Improvement: a one-time warning when `ERI_ANALYST_ID` is unset

- Governed actions (approve, ingest, ODK sync, catalog/registry writes, research operations, log
  resolution) stamp the **shared audit trail** with the analyst's identity. When `ERI_ANALYST_ID` is
  unset **or empty**, erifunctions still falls back to the OS username — but now **warns once per
  session** so you know approvals and logs will be attributed to that fallback rather than your
  analyst id. (Previously an explicitly-empty `ERI_ANALYST_ID` would have stamped an empty actor;
  it now falls back too.) Identity resolution is centralised in a single internal helper. Fixes a
  fresh-user red-team finding (#171).

## Docs: flag the steps you can't rehearse on a sandbox

- The ODK guide now says up front that creating the project, uploading the form, and submitting
  practice entries happen in the ODK Central **web interface**, not in R.
- The CMR guide spells out that there is **no throwaway-sandbox path** for `eri_stage_cmr()` /
  approve (they require a registered RB-expansion country); only the parsing step is hands-on.
- The connections guide notes that `eri_list()`'s `name` column holds the **full path** and that
  `full_names = FALSE` returns just the leaf filenames. Fresh-user findings (#177).

## Fix: friendlier schema discovery and an accurate research-function reference

- `load_dq_schema()` now **lists the available bundled schema keys** when it cannot find the one you
  asked for — so `load_dq_schema("dr", "malaria")` points you to `dr_malaria_case` instead of a bare
  "No schema found." error.
- The README's research-projects reference now includes `eri_research_scaffold()`,
  `eri_research_status()`, and `eri_research_tag()` (previously omitted) and clarifies
  `eri_research_scaffold()` (a new standalone project *repository*, ADR-0006) vs `eri_research_init()`
  (initialise a project in the current directory).
- The DQ guide names the `disease` argument in `load_dq_schema()` examples and notes that the schema
  key (e.g. `malaria_case`) is distinct from the layer-path `data_type`. Fresh-user findings (#176).
  (The deeper `data_type`-vs-schema-key vocabulary unification is tracked in #175.)

## Improvement: `dq_report()` shows the offending values, not just counts

- The "Flags Requiring Review" section now prints up to three example offending values with their row
  numbers for each issue — e.g. `not in allowed_values: 2 rows [species] (e.g. P.vivax (row 4);
  P.ovale (row 2))` — with a `+N more` suffix when there are more, and a closing pointer to
  `result$flags` for the full row-level detail. Previously it printed only a count and column, so an
  analyst had to open `result$flags` to see *what* to fix. Fixes a fresh-user red-team finding (#178).

## Fix: `eri_catalog_query()` no longer says "Catalog is empty" for a no-match filter

- A filtered `eri_catalog_query()` that matches nothing now reports *"No catalog entries match the
  specified filters"* — even when the catalog itself happens to have no entries — instead of the old
  *"Catalog is empty."*, which could make a filtered lookup look like it had wiped the shared catalog.
  An unfiltered query on a truly empty catalog now reads *"The data catalog has no entries yet."*
  Fixes a fresh-user red-team finding (#173).

## Fix: cleaner console output from `eri_read()` and the file-writing helpers

- `eri_read()` no longer prints `readr`'s column-specification block when reading a CSV (it now reads
  with `show_col_types = FALSE` / suppresses the message on both the local and Azure paths), so a read
  no longer erupts with engine noise in the middle of a pipeline.
- The side-effecting helpers (`eri_write()`, `eri_upload()`, `eri_dir_create()`, `eri_delete()`,
  `eri_dir_delete()`) now return **invisibly**, so scripted / `Rscript` runs no longer print stray
  `NULL` lines between steps. Both fixes come from the fresh-user red-team (#172).

## Docs: guides clean up with `eri_dir_delete()`/`eri_delete()`, not raw AzureStor

- Every guide's "Clean up" section now tears down its sandbox with the exported `eri_dir_delete()` /
  `eri_delete()` instead of `AzureStor::delete_storage_dir()` / `delete_storage_file()`. This keeps an
  analyst inside `erifunctions` for the one operation most likely to send them to Azure Storage
  Explorer, rather than dropping to raw blob calls. Fixes the fresh-user red-team's top finding (#170).

## Feature: ODK forms with repeat groups are now captured in full

- ODK Central exports a form with **repeat groups** as multiple tables — a parent table (one row per
  submission) plus one child table per repeat group, linked by `PARENT_KEY` → the parent's `KEY`.
  Previously `download_odk_form()` read only the parent CSV and `eri_odk_sync()` wrote a single
  Parquet, so **repeat data was silently dropped**.
- `download_odk_form()` gains a `tables` argument. The default (`tables = FALSE`) is unchanged — it
  returns the parent table as a single tibble. With `tables = TRUE` it returns a **named list of every
  table** in the export (parent first, named by each table's CSV).
- `eri_odk_sync()` now writes **one Parquet per table** to `{country}/{disease}/odk/raw/` — single-
  table forms are unchanged (still exactly one Parquet); repeat forms produce
  `{form_id}.parquet` plus `{form_id}-{repeat}.parquet` for each repeat group.
- **New bundled XLSForm** `inst/extdata/odk-test-form-repeat.xlsx` (a river-prospection form with a
  repeated `larva_sample` group) and a new **"Forms with repeat groups"** section in the ODK guide
  (`vignettes/da-odk-guide.Rmd`) showing the parent/child tables, the `PARENT_KEY` join, and the
  one-Parquet-per-table sync.

## Fix: `eri_onboard_cmr()` creates the canonical `rblf/cmr/` directories

- `eri_onboard_cmr()` now creates CMR Azure directories at `{country}/rblf/cmr/{raw,staged,processed}/`
  — the location `eri_stage_cmr()` and `eri_approve()` actually use — instead of per-disease folders
  like `{country}/{disease}/cmr/`, which never matched the pipeline. The `diseases` argument is
  replaced by `create_dirs` (logical): CMR for the RB-expansion programmes is filed under the combined
  `rblf` code (RB + LF), not split by disease.

## Documentation: a monthly CMR upload guide for data analysts

- **New article — "Uploading and processing a monthly country report (CMR)"**
  (`vignettes/da-cmr-guide.Rmd`). The Data Analyst monthly job: upload a filed CMR Excel to the
  `projects` blob, `eri_stage_cmr()` it into `staged/`, parse each sheet with `eri_ingest_cmr()` (by
  its machine-readable `#field-code` row — language-neutral, so it parses English and French templates
  alike), and `eri_approve()` it into `processed/`. The parsing step is run live on a new bundled
  synthetic example report (`inst/extdata/cmr-example.xlsx`); the Azure steps are shown as
  representative output. **Completes the `docs/guides.md` role × task matrix.**

## Documentation: an Epidemiologist anomaly-detection guide

- **New article — "Catching anomalies in a new surveillance extract"** (`vignettes/epi-dq-guide.Rmd`).
  A run-it-live, offline walkthrough of the anomaly detectors for epidemiologists: after
  `run_dq_checks()`, chain `add_anomaly_pct_change()` (case spikes), `add_anomaly_gaps()` (missing
  reporting weeks), `add_anomaly_consistency()` (cross-field rules), and `add_anomaly_spatial()`
  (unrecognized admin names) on a synthetic multi-period extract, and interpret each flag. Complements
  the `dq-pipeline.Rmd` reference (which documents the schema + detector mechanics).

## Documentation: an Epidemiologist locality-reconciliation guide

- **New article — "Reconciling free-text localities to admin units"**
  (`vignettes/epi-reconcile-guide.Rmd`). A run-it-live walkthrough of `eri_spatial_reconcile()` for
  epidemiologists: match messy place names to canonical admin units offline, geocode the residual
  (keyless OpenStreetMap), and interpret the trust-guarded `reconcile_status`
  (`matched` / `geocoded` / `geocoded_review` / `unresolved`). Fills the gap that `spatial-workflow.Rmd`
  left — that vignette never covered reconciliation.

## Error & data-quality log triage (Phase 5)

- **`eri_logs()` -- new.** Reads the structured operation logs (written by `eri_ingest()`,
  `eri_approve()`, `eri_stage()`, `eri_odk_sync()`, …) and the new data-quality logs across
  `{country}/{disease}/{data_type}/logs/` in the `data/` blob, and returns them as a triage backlog
  tibble. Filter by `status` (`"error"`, `"needs_review"`, …), `operation`, `analyst`, or `since`;
  scope to one dataset or scan the whole system. Because the logs live in Azure, the backlog is shared
  — a teammate can see exactly what failed and pick up where you left off.
- **`eri_dq_log()` -- new.** Persists `run_dq_checks()`'s `$flags` to the log backlog so data-quality
  issues are durable and discoverable, not just in-session. `eri_ingest()` now calls it automatically
  after its DQ checks.
- **`eri_logs_resolve()` -- new.** Marks a log entry handled (records who/when/note in a `triage`
  block) so it drops off the open backlog without deleting the record.
- **New article — "Triaging the error & data-quality log backlog"** (`vignettes/da-logs-guide.Rmd`)
  walks the workflow on the `atlantis` sandbox. Closes the last open Data Analyst row in
  `docs/guides.md` (previously blocked on the `eri_logs()` function gap).

## Documentation: an onboarding guide for data analysts

- **New article — "Onboarding a new country, disease, or data type"**
  (`vignettes/da-onboard-guide.Rmd`). The prequel to the ingest and ODK guides: how a Data Analyst
  stands up the DQ schema + `raw/staged/processed` folders for a new program before any data flows.
  Covers all three scaffolding paths — `eri_onboard_country()` (surveillance), `eri_onboard_cmr()`
  (CMR), and `eri_onboard_disease()` (NTD MDA + prevalence) — plus the `dry_run` preview and
  `eri_schema_validate()` (valid + a broken→fixed example), on the `atlantis` sandbox. Complements the
  existing "Adding a new program" vignette (which covers contributing a finished schema to the package).

## Documentation: a connections & authentication guide

- **New article — "Connecting to Azure, ODK Central, SharePoint, and Teams"**
  (`vignettes/connections-guide.Rmd`). The single reference for every external connection
  `erifunctions` makes: how to authenticate to each service, a "confirm it works" check per service,
  one consolidated `.Renviron` template, brief automation/CI (service-principal / token / webhook)
  callouts, and a troubleshooting table. The role guides now point here instead of each re-explaining
  auth.

## Documentation: a worked ODK Central guide for data analysts

- **New article — "Working with ODK Central"** (`vignettes/da-odk-guide.Rmd`). A hands-on, run-it-live
  walkthrough of the full ODK loop for a Data Analyst: connect with `init_odk_connection()`, stand up
  a practice form, monitor it with `eri_survey_status()`, manage collectors with
  `update_odk_app_user_role()` / `eri_odk_bulk_users()`, register it, and `eri_odk_sync()` its
  submissions into the governed `raw → staged → approved` pipeline — then clean up. The package now
  ships a small practice XLSForm (`inst/extdata/odk-test-form.xlsx`) the reader uploads to a sandbox
  `test` project.
- **`eri_survey_status()` fix.** The form-metadata request now sends the `X-Extended-Metadata: true`
  header, so `total_submissions` and `last_submission_at` are populated. Previously these fields were
  omitted by ODK Central and `total_submissions` was always `0`.

## Documentation: a worked ingest guide for data analysts

- **New article — "Ingesting a surveillance dataset: raw to approved"**
  (`vignettes/da-ingest-guide.Rmd`). A copy-paste, hands-on walkthrough of the core Data Analyst
  job: take a dataset through the `raw/` → `staged/` → `processed/` pipeline, with `eri_approve()`
  as the human gate. The reader stands up a make-believe country (*Atlantis*) as a private sandbox,
  invents a small malaria line-list, **authors its DQ schema**, runs `run_dq_checks()`, stages and
  approves it — then handles a **second extract seeded with errors** (an impossible age and an
  unknown district) to learn the difference between auto-corrections and review flags, before
  deleting the whole sandbox. Runs live on any laptop and leaves no trace. Flips the matching row in
  `docs/guides.md` to shipped.
- **`eri_catalog_remove()` -- new.** Deletes a file's entry from the data catalog
  (`_catalog/data_catalog.yaml`) by path — the inverse of `eri_catalog_register()`, for when a
  processed file has been deleted or superseded. (Used by the new guide's clean-up step.)

## Documentation: a worked research guide for epidemiologists

- **New article — "A complete research workflow for epidemiologists"**
  (`vignettes/epi-research-guide.Rmd`). A copy-paste, start-to-finish walkthrough of the whole
  research lifecycle — scaffold a project, put it under version control with the reproducibility
  check, add data with metadata, source it, analyse, save outputs and figures, tag a citable
  version, pause and resume weeks later, take in an updated dataset, and tidy up. It uses the
  public `mtcars` dataset (initial `am == 0` subset → expanded to the full dataset to simulate
  new data arriving), so any epidemiologist can run it live on their laptop and delete every
  resource at the end. Supersedes the older, partly-stale `research-workflow` vignette.
- **New `docs/guides.md`** — an index of task guides (one per user role × task) tracking what
  exists and what is still missing, seeding the framework the epi guide is the first of.

## Console output: clearer, calmer, and tunable

For non-developer users a stack of anonymous progress bars looks like the package has hung. The
console output is overhauled package-wide:

- **One informative progress bar instead of many.** Multi-file transfers (e.g. `eri_research_snapshot()`
  uploading 17 files, `eri_research_pull()`) now show a single bar that names the current file and
  its position (`3/17`), rather than a stack of AzureStor's anonymous `|====| 100%` bars. The native
  per-transfer bar is suppressed everywhere and replaced with `cli` output; it is kept only for a
  genuinely large single file (e.g. the ~100 MB LandScan raster) so a long download still shows life.
- **Summary end-caps.** Multi-step operations (`eri_research_tag()`, `eri_approve()`, `eri_ingest()`)
  finish with a tidy `✔`-titled key/value summary of what happened.
- **`eri_verbosity()` -- new.** Controls how chatty the console is: `"full"` (default -- step-by-step
  confirmations and summaries) or `"quiet"` (headline results, warnings, and errors only). Set it for
  a whole project via `options(erifunctions.verbosity = "quiet")` in `.Rprofile`, per session with
  `eri_verbosity("quiet")`, or via the `ERIFUNCTIONS_VERBOSITY` environment variable.

## Fixes

- `eri_research_scaffold()`: the generated reproducibility-check workflow now installs the
  geospatial/Azure system libraries (`gdal`/`proj`/`geos`/`udunits`, `curl`/`openssl`) and uses
  Posit Public Package Manager binaries (`use-public-rspm: true`). Previously `renv::restore()` on
  the Ubuntu runner tried to build `curl` (and the `sf` geospatial stack) from source with no
  `-dev` libraries present and failed, so the check was red for any real research project.
  Validated on the `dr_irs_2026` reference repo.

## Research data lifecycle (issue #148, ADR-0009)

- `eri_spatial_promote()` -- **new**: the explicit gate for pushing a boundary cleaned in a
  research project up to the shared canonical `spatial/` store, recording the promotion (who,
  what, when, whether it replaced an existing boundary, and where the prior version was archived)
  in `research.yaml`. Replacing an existing canonical boundary requires `overwrite = TRUE`.
- `eri_spatial_upload()` is now **overwrite-safe**: it refuses to clobber an existing canonical
  boundary (shared cleaned data many users pull for figures) unless `overwrite = TRUE`, and points
  to `eri_spatial_promote()` for deliberate replacement. Reads of the canonical/cached `.rds`
  format are now supported alongside shapefiles.
- **Canonical overwrites are archived.** A deliberate `overwrite = TRUE` (via either
  `eri_spatial_upload()` or `eri_spatial_promote()`) first copies the prior canonical boundary to
  `spatial/_archive/<timestamp>/`, so replacing shared reference data is reversible (ADR-0009).
- `eri_research_status()` now also reports boundary **promotions** the project has made to canonical
  (summarised separately from the inbound input table).
- `eri_research_status()` -- **new**: a manifest of every input a project depends on (source,
  `pulled_at`, update count, whether a prior version was archived) plus output/snapshot/tag counts.
  `check_remote = TRUE` flags inputs whose Azure source is newer than the local copy.
- `eri_research_pull()` now does **update-with-archival**: a re-pull moves the prior local version
  into `data/_archive/<timestamp>/` and records it, and **dedups** `pulled_data` (a re-pull of the
  same source replaces its record instead of appending a duplicate, and collapses any pre-existing
  duplicates). `eri_spatial_load(cache = TRUE)` inherits this.
- `eri_spatial_pop()` now **caches the LandScan raster in the project and reuses it** rather than
  re-downloading ~100 MB on every call; records provenance when run inside a research project.
- `eri_landscan_list()` no longer warns when the LandScan directory simply does not exist yet
  (returns an empty tibble quietly).
- **ADLS-safe directory creation is now centralized.** The trailing-slash trim + missing-parent
  creation previously local to `R/research.R` (`.eri_ensure_azure_dir()`) is promoted into the DAL
  as `.eri_create_azure_dir()`; `azure_io("create")` and every nested-path write site
  (`artifacts.R`, `catalog.R`, `odk_registry.R`, `onboarding.R`, `cmr.R`, `templates.R`, `research.R`)
  now route through it instead of calling `AzureStor::create_storage_dir()` directly. Robustness/
  consistency fix from the PR #147 review.

## Azure access: zero-config interactive auth + ADLS Gen2 fixes

- `get_azure_storage_connection()` ships working defaults for interactive (browser) auth, so analysts
  and epidemiologists configure nothing: `app_id` defaults to Microsoft's first-party Azure CLI public
  client and `tenant_id` / `resource_endpoint` to the team's Entra tenant and the `eridev` ADLS
  endpoint. All remain overridable via the existing `ERIFUNCTIONS_*` env vars; the service-principal
  secret stays env-only. One Microsoft sign-in covers Azure Storage (and, later, Microsoft Graph).
- Fixed research-project directory creation on **ADLS Gen2**: paths with a trailing slash returned
  `HTTP 400 (request URI is invalid)` and intermediate parents were not created. New internal
  `.eri_ensure_azure_dir()` trims trailing slashes and creates each missing parent level; all
  `R/research.R` directory sites use it.
- `eri_research_scaffold()` normalizes a trailing slash in `dest`, and its partial-failure message now
  explains how to recover (finish `eri_research_init()` in place, or `unlink()` + re-scaffold).

## V2 Phase 1 -- dr_irs vertical slice (in progress)

- `eri_research_tag()` -- bind a frozen data snapshot, the analysis git commit, the input
  provenance, and the output manifest into an immutable, citable tag in Azure, recorded in
  `research.yaml`. Makes a tagged analysis reproducible from a citation, including across data
  updates. Tags are immutable and auto-create a snapshot if none exists. (#135)
- `eri_spatial_load(cache = TRUE)` -- cache an admin boundary into the research project and
  record its provenance (delegating to `eri_research_pull()`), then read the local copy, so a
  study's spatial inputs are reproducible and frozen by `eri_research_tag()`. See ADR-0007. (#133)
- `eri_research_scaffold()` -- create a standalone research-project repo skeleton (README,
  `analysis/` seeded from the workflow template, data-safe `.gitignore`, minimal reproducibility
  CI) plus the standard research scaffold via `eri_research_init()`. Implements ADR-0006. (#136)
- `eri_spatial_reconcile()` -- thin, opt-in data-sourcing helper that maps free-text locality
  names to canonical admin units: normalized exact/fuzzy match against the boundary `sf` first,
  then geocodes only the unmatched (via `tidygeocoder`, `method = NULL` to disable) and assigns
  admin units by point-in-polygon through `eri_spatial_join()`. Returns the data with names
  reconciled in place plus coordinates and a `reconcile_status` column. Only place-name strings
  are sent to the geocoder. (#134)
  - When a keyed method (e.g. `method = "google"`) is selected without its API key set,
    `eri_spatial_reconcile()` now aborts up front with guidance to store the key once in the
    user `.Renviron` (e.g. `GOOGLEGEOCODE_API_KEY`), rather than surfacing a lower-level
    geocoder error. (#143)
  - Geocodes are now trusted (status `"geocoded"`, names assigned) only when the service did
    not flag a partial/low-confidence match *and* the assigned coarser admin units agree with
    the parent levels supplied. Otherwise the row is flagged `"geocoded_review"`: coordinates
    are kept for inspection but the analyst's names are left untouched. Guards against geocoders
    that best-guess a fabricated or unmatched locality into a plausible point. (#145)

# erifunctions 0.9.0

## V2 Phase 0 -- Governance & shared-memory scaffolding

Documentation and project-infrastructure only; no changes to package functions. Marks the
start of the V2 effort.

- `docs/roadmap.md` -- version-controlled V2 development roadmap (Phases 0-5)
- `docs/adr/` -- architecture decision records (single-package vs split, concurrency-safe
  metadata, token-derived identity, DuckDB query layer, pull-then-process, research-as-repos)
- `docs/vision.md` -- the founding vision brief, moved out of the gitignored `sandbox/`
- `CLAUDE.md` -- working memory and conventions for contributors (human and AI)
- `_pkgdown.yml` + `.github/workflows/pkgdown.yaml` -- grouped-reference documentation site,
  published to <https://thecartercenter.github.io/erifunctions/>
- README version banner and CI status badges (R-CMD-check, pkgdown)
- Cleared the pre-existing `R CMD check` warning and notes (non-ASCII source, `utils::tail`
  import, `CONTRIBUTING.md` in `.Rbuildignore`); bumped CI actions to `checkout@v5`
- `main` branch protection requiring the R-CMD-check and pkgdown gates

# erifunctions 0.8.0

## Phase 7 -- SharePoint integration and multi-program expansion

### New functions

**SharePoint** (`R/sharepoint.R`)
- `eri_sharepoint_connect()` -- interactive browser auth via `Microsoft365R`; token cached by `AzureAuth`
- `eri_sharepoint_list()` -- tibble of files/folders at a document library path (`name`, `size`, `modified`, `is_folder`, `path`)
- `eri_sharepoint_read()` -- download and read a SharePoint file by extension (xlsx/xls, csv, parquet, rds; returns temp path for unknown types)
- `eri_sharepoint_upload()` -- upload a local file to SharePoint; auto-creates destination folder; `overwrite = FALSE` guard; returns item URL invisibly

**Onboarding** (`R/onboarding.R`)
- `eri_onboard_disease()` -- generate MDA and/or prevalence skeleton YAML schemas for a new disease program

### New bundled schemas (`inst/schemas/`)

- `ug_rb_mda.yaml` / `ug_rb_prevalence.yaml` -- Uganda river blindness (APOC community-directed treatment; nodule palpation / skin snip)
- `schisto_mda.yaml` / `schisto_prevalence.yaml` -- Schistosomiasis (praziquantel MDA; Kato-Katz egg count by species)
- `sth_mda.yaml` / `sth_prevalence.yaml` -- STH (albendazole/mebendazole MDA; Kato-Katz species breakdown)

### New vignettes

- `vignettes/sharepoint-workflow.Rmd` -- full connect/list/read/upload cycle with combined pull-DQ-report-push workflow
- `vignettes/adding-a-program.Rmd` -- step-by-step guide: scaffold, edit, validate, test, PR checklist, epi functions pattern

---

# erifunctions 0.7.0

## Phase 6 -- Reporting and documentation

### New functions

**Reporting core** (`R/reports.R`)
- `eri_brand_colors()` -- named vector of Carter Center brand colours (navy, blue, orange, gold, green, light_blue, gray)
- `eri_brand_ggplot_theme()` -- Carter Center ggplot2 theme built on `theme_bw()`; applies brand fonts, colours, and strip formatting
- `eri_table()` -- branded `flextable` with navy header, alternating row shading, Calibri font, optional title and footnote; renders in Excel, HTML, and PowerPoint

**Excel reports** (`R/reports_excel.R`)
- `eri_wb_create()` -- create a blank `openxlsx2` workbook with Carter Center metadata
- `eri_wb_add_sheet()` -- add a styled data sheet (navy header, alternating shading, frozen first row, optional title)
- `eri_wb_save()` -- save a workbook to disk, auto-creating parent directories
- `eri_report_excel()` -- convenience wrapper: create → add multiple sheets → save in one call

**HTML reports** (`R/reports_html.R`)
- `eri_report_html()` -- render a self-contained HTML report from a structured section list via Quarto
- `eri_report_qmd_template()` -- copy the bundled Quarto template to a local path for customisation
- Internal: `.eri_serialise_sections()` -- converts section tables to HTML fragments and figures to base64 PNGs

**PowerPoint reports** (`R/reports_pptx.R`)
- `eri_pptx_create()` -- load the bundled Carter Center `.pptx` template (or a custom template) as an `officer` object
- `eri_pptx_add_title()` -- add a title slide with optional subtitle
- `eri_pptx_add_section()` -- add a section divider slide
- `eri_pptx_add_table()` -- add a `eri_table()` flextable on a new slide
- `eri_pptx_add_plot()` -- add a ggplot figure (saved as PNG) on a new slide
- `eri_pptx_save()` -- write the presentation to disk, auto-creating parent directories

### New templates

- `inst/templates/eri_template.pptx` -- default Carter Center PowerPoint template
- `inst/templates/eri_report.qmd` -- Quarto self-contained HTML report template
- `inst/templates/eri_report.css` -- Carter Center HTML report stylesheet

### New vignettes

- `vignettes/dq-pipeline.Rmd` -- DQ pipeline walkthrough: schema anatomy, `run_dq_checks()`, anomaly detection, custom checks, and export
- `vignettes/spatial-workflow.Rmd` -- loading and uploading admin boundaries, spatial joins, bbox expansion, choropleth maps
- `vignettes/epi-analytics.Rmd` -- incidence rates, epiweek utilities, LF pooled prevalence, oncho status maps, branded tables
- `vignettes/research-workflow.Rmd` -- project init, session management, lab notebook, snapshots, and full session walkthrough

# erifunctions 0.6.0

## Phase 5 — Spatial, epi analytics, and disease-specific functions

### New functions

**Spatial data management** (`R/spatial.R`)
- `eri_spatial_load()` — read an admin boundary RDS from Azure (`data/spatial/{country}/adm{level}.rds`)
- `eri_spatial_upload()` — validate (CRS, required name column, no empty geometries) and push a local shapefile to Azure
- `eri_bbox_expand()` — expand a bounding box by metres in each direction (port of `sirfunctions::f.expand.bbox()`)
- `eri_spatial_join()` — point-in-polygon join; drops rows with NA coordinates with a warning
- `eri_landscan_upload()` — upload a LandScan raster to Azure; validates year and exact filename convention
- `eri_landscan_list()` — list available LandScan years from Azure; returns a tibble sorted descending
- `eri_spatial_pop()` — extract population totals for a shapefile from LandScan via `exactextractr`; auto-selects latest year if none given

**Visual style system** (`R/style.R`)
- `eri_color_scheme()` — return a named colour vector for `malaria.incidence`, `lf.status`, `oncho.status`, `activities`, or `dq.flag`
- `eri_plot_theme()` — return a ggplot2 theme preset for `map`, `epicurve`, or `map.inset`

**Standard maps** (`R/maps.R`)
- `eri_map_choropleth()` — fill choropleth with optional scale bar and north arrow
- `eri_map_incidence()` — malaria incidence rate map with automatic `0 / <1 / 1-10 / >=10` binning
- `eri_map_points()` — overlay point data on a shapefile base map
- `eri_map_inset()` — compose a main map with a country-context inset via `cowplot`

**Epi core analytics** (`R/epi.R`)
- `eri_incidence_rate()` — vectorised cases / population × multiplier; returns `NA` for zero/missing populations
- `eri_epiweek_date()` — convert year + epiweek to a `Date`; supports CDC Sunday-start and ISO Monday-start
- `eri_study_week()` — integer study week relative to an index date
- `eri_epidemic_curve()` — ggplot2 epidemic curve by day/week/month/year with optional grouping and faceting
- `eri_case_summary()` — grouped case counts from line-list or aggregate data with optional date filtering

**LF programme functions** (`R/epi_lf.R`)
- `eri_lf_pooled_prev()` — pooled prevalence from pool-screening data: `1 - ((1 - npos/npool)^(1/pool_size))`
- `eri_lf_program_levels()` — ordered 5-level WHO/GPELF programme status vector
- `eri_lf_tas_summary()` — group-level TAS positivity table (n and %) from individual result data
- `eri_lf_status_map()` — choropleth coloured by LF programme status

**OEPA oncho functions** (`R/epi_oncho.R`)
- `eri_oncho_program_levels()` — ordered 5-level OEPA programme status vector
- `eri_oncho_status_map()` — choropleth coloured by OEPA oncho programme status

### New DQ schemas (`inst/schemas/`)

**LF (Hispaniola)**
- `dr_lf_tas.yaml`, `ht_lf_tas.yaml` — individual antigen test results; `discordant_fts_rdt` derived flag; consistency check for FTS-Neg/RDT-Pos discordance requiring clinical review
- `dr_lf_mda.yaml`, `ht_lf_mda.yaml` — MDA coverage per EU per round; `implied_coverage` derived; overcoverage consistency check

**Malaria case (Hispaniola)**
- `dr_malaria_case.yaml` — DR individual case record; `imported_flag` derived from non-DR province values (Extranjero, Africa, Haiti, Venezuela, Otros)
- `ht_malaria_case.yaml` — Haiti aggregated commune-level; `admin_match` block validates department (adm1) and commune (adm2) names against spatial boundaries

**OEPA oncho**
- `oepa_oncho_mda.yaml` — MDA coverage per focus per round; `overcoverage_flag` derived (treated > 1.3× target); consistency check for implausible overcoverage
- `oepa_oncho_prevalence.yaml` — prevalence survey (one row per person); lat/lon range checks for OEPA region

### Other changes
- `add_anomaly_spatial()` extended to support `admin_match` schema blocks — validates column values against canonical admin names loaded from Azure via `eri_spatial_load()`
- `ggspatial` and `sf` added to `Imports`; `cowplot`, `exactextractr`, `ggnewscale` added to `Suggests`

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
