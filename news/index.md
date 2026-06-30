# Changelog

## erifunctions (development version)

### Feature: `eri_simulate_check()` — confirm the cutover gate catches divergence

- **New `eri_simulate_check(reference, by, types, n, seed)`** ties the
  Phase-3 simulation harness together: it injects known anomalies into a
  clean dataset (in the value columns, off the join keys) and confirms
  \[[`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)\]
  — run with the cutover standard — flags the result as **not
  equivalent**. Returns `detected`, the injected-anomaly log, and the
  comparison so you can see which deltas were caught — a one-call way to
  build confidence that the cutover gate would catch a real divergence
  before relying on it.

### Fixes: CMR ingest/stage hardening (Phase 3)

- **`eri_stage_cmr(period = NULL)`** now auto-selects the most recent
  period with a robust lexical
  [`max()`](https://rdrr.io/r/base/Extremes.html) over the `YYYYMM`
  directory labels, instead of
  [`which.max()`](https://rspatial.github.io/terra/reference/summarize-generics.html)
  on those character labels — which coerced them to numeric (a warning,
  and `integer(0)` for any non-numeric label, so a future ISO/underscore
  period format would have silently selected nothing).
- **[`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md)**
  fails with a helpful, named error listing the available sheets when
  the (alias-resolved) `sheet` isn’t in the workbook, instead of an
  opaque `readxl` error.

### Feature: cutover ledger — `eri_cutover_check()` / `eri_cutover_status()` (ADR-0015)

- **New
  `eri_cutover_check(new, old, country, disease, data_source, period, by, …)`**
  runs the cutover-standard comparison
  (`eri_compare(…, strict_schema = FALSE)`) for one stream’s period and
  records the outcome — stream, period, `equivalent`, delta counts, the
  `by`/`tolerance` used, and the verified actor — to
  `_cutover/cutover_log.yaml` in the `data/` blob. **New
  `eri_cutover_status(country, disease, data_source, …, n = 3)`** reads
  the ledger and reports the **streak** of consecutive most-recent
  equivalent periods and whether the stream is *eligible* for cutover
  (streak ≥ `n`). Together they make the Phase-3 cutover gate (ADR-0015)
  runnable period-over-period; the equivalence standard is encoded so it
  can’t drift from the policy.

### Feature: `eri_inject_anomalies()` — dirty clean data for the Phase 3 simulation

- **New `eri_inject_anomalies(data, types, n, cols, seed)`** perturbs a
  clean data frame with controllable, reproducible anomalies —
  `missing`, `outlier`, `negative`, `typo`, `duplicate`, `drop` — so the
  parallel-run simulation actually exercises the DQ pipeline and
  [`eri_compare()`](https://thecartercenter.github.io/erifunctions/reference/eri_compare.md)
  (existing staged data is largely already clean). The result carries an
  `"eri_anomalies"` attribute logging every injection (type, row,
  column, original, new) as ground truth for checking detection. The
  injection counterpart to the `add_anomaly_*` detectors.

### Feature: `eri_compare()` — reconcile two datasets (Phase 3 cutover validation)

- **New `eri_compare(new, old, by, ...)`** diffs a candidate dataset
  against a reference and reports the differences — the linchpin of the
  Phase 3 parallel run: prove
  [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)’s
  `data/staged` output matches the legacy `projects/intermediate`
  (hsp-mal) output before any cutover. `new`/`old` are data frames or
  Azure blob paths (read via
  [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)).
  With key columns (`by`) it reconciles row-for-row — which keys were
  **added**/**dropped** and exactly which **cells** differ (numeric
  `tolerance`- and NA-aware); without keys it reports the **schema**
  diff and set-based row membership. Returns an `eri_comparison` object
  (`equivalent`, `summary`, `schema`, `rows`, `values`) with a
  [`print()`](https://rdrr.io/r/base/print.html) method.

### Feature: `eri_feedback_report()` — weekly feedback digest

- **New `eri_feedback_report(file, format, since_days = 7)`** renders
  the feedback backlog to a self-contained **HTML** (default) or
  **markdown** file: a status board, then **new this week**, **closed
  this week** (with each ticket’s closing note), and the **open
  backlog** in lifecycle order. Built as a quick standing review so the
  team stays current on the tickets (ADR-0014).

### Feature: `eri_feedback_status()` — triage the feedback backlog

- **New `eri_feedback_status(id, status, note = NULL)`** moves a ticket
  through the lifecycle (`submitted` → `planned` → `in_progress` →
  `fixed`, or `declined`) and records an audit-trail entry of the
  transition (from, to, who, when, optional note) on the ticket’s
  `history`. The actor is the **verified** signed-in identity (ADR-0003)
  and the update is concurrency-safe (ADR-0002); an unknown id aborts
  without writing and `status` is validated against the lifecycle. **New
  [`eri_feedback_board()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback_board.md)**
  prints a one-line-per-status count of the backlog (the triage-meeting
  view) and returns the rows. This is the triage half of the feedback
  log (ADR-0014); capture is
  \[[`eri_feedback()`](https://thecartercenter.github.io/erifunctions/reference/eri_feedback.md)\].

### Feature: `eri_feedback()` — in-package feedback / ticket log

- **New `eri_feedback(message, area = "general")`** lets any DA or Epi
  file feedback straight from R — a bug, a rough edge, a wish, or a
  general comment — into a durable backlog at
  `_feedback/feedback_log.yaml` in the `data/` blob. Each ticket records
  the **verified** signed-in author (ADR-0003), a UTC timestamp, an
  auto-incrementing id, the `area` (`"general"` or a section like
  `"odk"`/`"ingest"`/`"reporting"`), and `status = "submitted"`. Writes
  are concurrency-safe (ADR-0002), so the id is unique even when two
  people file at once. **New `eri_feedback_list(area, status)`** reads
  the backlog into a tibble. Updating a ticket’s status through triage
  is a separate workflow built on this log.

### Feature: concurrency-safe + rebuildable metadata stores (ADR-0002, Phase 2)

- **The shared YAML metadata stores are now race-safe.** The data
  catalog (`_catalog/data_catalog.yaml`), the ODK registry
  (`odk/registry.yaml`), and the artifact registry
  (`artifacts/_registry.yaml`) were each updated by a full
  read-modify-write, so two analysts editing at once would both read the
  old version and the slower writer would silently clobber the other’s
  entry. Writes now go through a new internal `.eri_yaml_update()` that
  reads the blob **with its ETag** and writes back **conditionally**
  (`If-Match` for an update, `If-None-Match: *` for a first create); on
  a `412` conflict it re-reads, re-applies the change to the fresh
  version, and retries — so no entry is lost. Routed:
  [`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md)
  /
  [`eri_catalog_remove()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_remove.md),
  [`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md)
  /
  [`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md)
  /
  [`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md)
  / the sync `last_synced` update, and
  [`eri_artifact_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_upload.md)
  /
  [`eri_artifact_archive()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_archive.md).
- **New
  [`eri_catalog_rebuild()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_rebuild.md)**
  reconstructs the catalog by scanning the `*/processed/*.parquet` files
  in the `data/` blob, making the catalog a **derivable cache** rather
  than an irreplaceable record: recover from a lost or corrupted
  catalog, or pick up files written outside
  [`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md).
  Entries are derived from the five-axis (or legacy four-axis) path;
  `registered_by` is `"rebuilt"` and `row_count` is left `NA`.

### Feature: token-derived approver identity (ADR-0003, Phase 2)

- **Governed actions now record the *verified* signed-in identity.**
  When an analyst connects interactively with their own Azure AD
  account,
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)’s
  `approved_by`, the catalog’s `registered_by`, and the operation logs
  (ingest, stage, CMR, ODK register/sync/upload, DQ logs, artifacts) are
  stamped with the identity from the **auth token** — a new internal
  [`.eri_token_identity()`](https://thecartercenter.github.io/erifunctions/reference/dot-eri_token_identity.md)
  extracts the verified `upn` / `preferred_username` — rather than the
  self-declared `ERI_ANALYST_ID`. This closes the spoofable-approver gap
  so the approval gate is a real control, not a convention.
  `ERI_ANALYST_ID` is retained as the fallback for service-principal /
  non-interactive runs (which carry no user claim). Backward compatible
  — nothing changes for callers without a connection.

### Docs: `da-survey-report-guide` — final summaries and reports from an ODK survey ([\#231](https://github.com/thecartercenter/erifunctions/issues/231))

- **New `da-survey-report-guide` article** (DA task: create/assist final
  summaries/tables/reports after ODK surveys) takes an approved LF TAS
  extract to a summary with
  [`eri_lf_tas_summary()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_tas_summary.md)
  and packages it with the reporting toolkit
  ([`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md),
  `eri_pptx_*`), pointing to the disease helpers and the spatial map
  wrapper. Offline; real summary output captured. **Completes the
  Data-Analyst guide set.**

### Docs: `da-qc-feedback-guide` — quality-check an extract and give a country feedback ([\#229](https://github.com/thecartercenter/erifunctions/issues/229))

- **New `da-qc-feedback-guide` article** (DA tasks: QC data + provide
  feedback to countries) walks a real
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
  →
  [`dq_report()`](https://thecartercenter.github.io/erifunctions/reference/dq_report.md)
  run on a seeded DR malaria extract: the auto-corrections (`res$log`)
  vs the review flags (`res$flags`), turning the flags into a
  country-feedback table with
  [`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
  and posting a summary with
  [`eri_notify_dq()`](https://thecartercenter.github.io/erifunctions/reference/eri_notify_dq.md).
  Runs offline on a plain data frame.

### Docs: `da-reporting-guide` — branded tables, figures, and decks ([\#227](https://github.com/thecartercenter/erifunctions/issues/227))

- **New `da-reporting-guide` article** walks the reporting toolkit on
  safe data:
  [`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
  (branded flextable),
  [`eri_brand_ggplot_theme()`](https://thecartercenter.github.io/erifunctions/reference/eri_brand_ggplot_theme.md),
  [`eri_report_excel()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_excel.md)
  (styled workbook), and the `eri_pptx_*` deck builder, with pointers to
  the spatial/epi-analytics guides for maps and curves. Every chunk runs
  on a plain data frame (verified end-to-end).

### Feature: `eri_query()` — serverless SQL across processed data (ADR-0004, roadmap Phase 2)

- **New `eri_query(sql, …)`** runs SQL across **processed** parquet
  without a database server, by attaching the files into an in-process
  **DuckDB** session (the Azure blob stays the system of record). Two
  composable ways to put data in scope: **catalog-driven** — pass
  `country`/`disease`/`data_type`/… and it looks up the matching
  processed files, stamps each row with its provenance, and unions them
  into one table
  (`SELECT country, SUM(total_cases) FROM data GROUP BY country`); and
  **explicit** — `tables = list(name = df_or_path)` to register
  data.frames / parquet paths for joins (e.g. cases ⨝ population).
  Returns a tibble. `duckdb` + `DBI` are **Suggests** (install once;
  `install.packages(c("duckdb", "DBI"))`) — analysts who never query
  don’t pay for them. Closes the ad-hoc-data-request gap (DA task 10).
- **New `da-adhoc-guide` article** — a run-it-live walkthrough of
  [`eri_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_query.md)
  (catalog roll-ups, joins, window functions) for answering ad-hoc
  requests; the in-memory examples run with no Azure.

### Docs: Data Analyst training bundle now lives on the documentation site ([\#219](https://github.com/thecartercenter/erifunctions/issues/219), [\#225](https://github.com/thecartercenter/erifunctions/issues/225))

The reference/training materials for a “still learning R” analyst are
now **pkgdown articles** (one source of truth on the site, in a new
**Quick reference & onboarding** navbar group), rather than loose files
under `docs/`:

- **Orientation** — the big picture (data system, pipeline, where each
  task lives).
- **Onboarding** — a paced Week-0 → Week-2 path with checkpoints and a
  competency checklist, built on the existing sandbox namespaces
  (`atlantis`, `uga/demo`, the `eri_test_*` ODK forms).
- **DA cheat sheet** — the ~15 functions a DA uses, the 5-axis path, and
  a “which pipeline?” decision tree.
- **Data-model card** (channel vs. measure) and a **Troubleshooting
  card** (errors → fixes + the `eri_logs` triage loop).

Linked from the README, the guide index, and the getting-started
article. (The standalone connections *card* was folded into the existing
connections *guide* to avoid duplication.)

### Feature: `eri_odk_upload()` — bulk-create ODK submissions from a table (ADR-0013, [\#211](https://github.com/thecartercenter/erifunctions/issues/211))

- **New `eri_odk_upload(data, project_id, form_id, …)`** — the inverse
  of
  [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
  /
  [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md):
  take a CSV/Excel table of already-collected records (a paper backfill,
  a legacy export, or a `download_odk_form(tables = TRUE)` result) and
  **create them as submissions** on an existing **published** ODK
  Central form, one POST per row. Columns map to form fields **by name**
  using the same flattening
  [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
  emits (groups as `group-field`; repeat groups as separate
  `"{form_id}-{repeat}"` child tables linked by `PARENT_KEY` → parent
  `KEY`, per ADR-0010), so a download round-trips back to an upload.
- **Idempotent by construction.** Each submission’s `meta/instanceID` is
  derived **deterministically** from `key_col` (or the whole row), so
  re-running the same extract re-derives the same ids and ODK Central
  rejects duplicates with HTTP 409 — reported as `skipped`, never
  double-loaded.
- **Validate first, report per row.** A `dry_run = TRUE` pass checks
  column reconciliation, required fields, type/format (dates, geopoints,
  numbers), and — best-effort — select-value choice lists (parsed from
  the form XML; skipped for external/dataset choices), and POSTs
  nothing. A real run returns a per-row outcome tibble (`created` /
  `skipped` / `failed`) and continues past a bad row rather than
  aborting the batch. Attachments at creation are out of scope (an ODK
  API limitation). Adds a dependency on `xml2`. See
  [ADR-0013](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0013-odk-submission-backfill.md).
- **`mapping` argument**
  ([\#213](https://github.com/thecartercenter/erifunctions/issues/213))
  — for extracts whose headers don’t already match the form, pass
  `mapping = c(input_header = "field-column", …)` to rename columns to
  field names before validation (e.g. a paper CSV with `village` →
  `site_name`); columns you don’t list are left as-is. The
  `da-odk-guide` “Backfilling records into a form” section is now
  **captured live** against the `eri_test_river_prospection` sandbox
  form (real `created` / 409-`skipped` round-trip), and the field↔︎column
  mapping now normalizes ODK Central’s root-relative `/fields` paths
  (e.g. `/site_name`) so submissions carry their data on servers that
  omit the instance-root name from field paths.
- **Repeat-group upload verified end-to-end**
  ([\#215](https://github.com/thecartercenter/erifunctions/issues/215))
  against a live form: a parent + its repeat children, supplied as the
  `download_odk_form(tables = TRUE)` named-list shape, round-trips with
  each child nested under the right parent. The `da-odk-guide` backfill
  section gains a live-captured repeat example, and `.odk_colmap()` now
  excludes the repeat *container* (`type: "repeat"`, not `"structure"`)
  from the leaf map (latent edge; no behaviour change for current
  forms).

### Feature: harden analyst attribution + `eri_odk_purge()` for sandbox cleanup ([\#175](https://github.com/thecartercenter/erifunctions/issues/175) polish)

- **Analyst identity is now honest in the audit trail.** When
  `ERI_ANALYST_ID` is unset, governed actions are attributed to
  `"<os-user> (unverified)"` (was a bare OS username that looked like a
  real analyst id), so approval logs, the catalog `registered_by`, and
  `eri_logs`’ `analyst` column show the attribution is provisional. A
  team or CI run can **require** a configured identity by setting
  `ERI_REQUIRE_ANALYST_ID=true`, which makes governed actions *refuse*
  rather than fall back. The once-per-session warning now points at both
  options. Surfaced by both red-team runs.
- **New `eri_odk_purge(project_id, form_id, …)`** hard-deletes an ODK
  registry entry (active **or** already soft-deleted), unlike
  [`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md)
  which soft-deletes to preserve sync history. Use it to tear down
  **practice/sandbox** registrations so they don’t linger in the shared
  `odk/registry.yaml`; the `da-odk-guide` cleanup now uses it. Flagged
  by the fresh-DA red-team run.

### Fix: `eri_dir_delete()` prunes the catalog; `eri_split_cmr()` summarizes skipped sheets ([\#175](https://github.com/thecartercenter/erifunctions/issues/175) polish)

- [`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md)
  now **removes data-catalog entries under the deleted path** (new
  `prune_catalog` argument, default `TRUE` for Azure deletes), so
  deleting a namespace no longer leaves dangling rows that
  [`eri_catalog_verify()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_verify.md)
  would flag. Fail-silent — a catalog hiccup never blocks the delete.
  Surfaced by a fresh-Epi red-team run whose sandbox teardown left a
  phantom catalog row.
- [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  reports sheets the schema routes but the workbook lacks as a **single
  informational summary** (“Skipped N sheets …”) instead of a deferred
  pile of individual warnings (a fresh-DA nit).

### Data: bundled CMR schemas reconciled to the real country templates (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175))

- The seven bundled CMR schemas
  (`inst/schemas/cmr/{eth,nga,sdn,ssd,uga,tcd,mad}.yaml`) are
  regenerated from the **real** monthly templates’ structure (sheet
  names + machine-readable field codes only — no data values), replacing
  the earlier simplified stand-ins. Each country now carries its actual
  sheet set with `disease` / `data_type` routing keys, so
  [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  routes a real CMR completely: e.g. uga’s 14 sheets (RB/SCH Treatment,
  LF MMDP, VHT/Parish/Local-Leaders/Subcounty/MMDP-surgery/MMDP-patient/
  Field-Ento/Lab Training, LF Surveys, RB Epi Surveys, RB Ento Surveys);
  nga adds SCH/STH Treatment + Teacher/Health-Worker/Hope-Group
  trainings; mad is LF-only; the French `tcd`/`mad` keep their slug
  aliases. RB Epi Surveys → `oncho`/`prevalence`, RB Ento Surveys →
  `oncho`/`entomology`, LF Surveys → `lf`/`tas`, all Training sheets
  (incl. ToT) → combined `rblf`/`training`. `required_fields` now lists
  the real stable (non-monthly) identifier columns.

### Feature: `eri_odk_sync()` writes to the `research` channel (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4)

- [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
  now lands submissions in `data/{country}/{disease}/research/raw/` (was
  `.../odk/raw/`), recording `data_source = "research"` +
  `format = "odk"` in its operation log. ODK is the **research**
  channel’s collection *format*, not a `data_source` of its own — so
  this retires the transitional `odk` source token for new writes (the
  measure is assigned later, when the analyst cleans the form into a
  final dataset, so the path carries no measure level yet). The
  `odk`/`cmr` tokens remain registered for **reading legacy data** and
  are removed at the Phase-3 cutover. The `da-odk-guide` and
  `connections-guide` are updated to the `research` paths and a
  channel-level
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

### Feature: `eri_split_cmr()` routes a CMR per disease and measure (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4)

- New `eri_split_cmr(path, country, …)` reads every routable sheet of a
  CMR monthly report and writes each to
  `data/{country}/{disease}/programmatic/{data_type}/staged/`, so a
  single Excel fans out to its per-disease, per-measure canonical
  coordinates. The **disease comes from the sheet** (RB Treatment →
  `oncho`, SCH Treatment → `sch`, LF MMDP → `lf`; cross-programme
  Training sheets route together under the combined `rblf`), and the
  per-row `#…_disease` field — which holds programme-coverage codes
  (`RB`/`RBLF`/`RBLFSCH`) — is **kept as a column, not split on**, so
  treatment counts are never duplicated across diseases. Data is staged
  **parsed as-is** (machine-readable `#field-code` columns; no reshape,
  no automated DQ — CMR review is manual);
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  then promotes each disease/measure. `dry_run = TRUE` returns the
  routing plan without writing.
- The CMR schema gains two per-sheet keys, `disease` and `data_type`,
  driving the routing. **All seven registered countries**
  (eth/nga/sdn/ssd/uga English, tcd/mad French) now carry routing keys,
  so
  [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  works for each: Treatment sheets → the disease’s `treatment`, LF MMDP
  → `lf`/`mmdp`, Training sheets → combined `rblf`/`training`, Surveys →
  `rblf`/`survey`, River Prospection / Fly Collection →
  `oncho`/`entomology` (Drug Inventory and SBCC are logistics/comms, not
  split). The deeper reconciliation of each bundled schema’s sheet set
  to its real template (monthly `_jan…_dec` columns, the larger real
  sheet set) remains tracked as follow-up.
- The `da-cmr-guide` now teaches `upload → stage → split → approve`,
  approving each disease/measure on its own coordinates instead of one
  combined `rblf`/`cmr` bucket.

### Feature: `eri_ingest()` stages to the five-axis measure path (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4)

- [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
  now writes the cleaned parquet to
  `data/{country}/{disease}/{data_source}/{data_type}/staged/` (the
  **measure** is in the path, not just used to pick the schema), and its
  operation/DQ logs land alongside. So
  [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
  → `eri_approve(country, disease, data_source, period, data_type = …)`
  is now a consistent five-axis round-trip. **Behaviour change:** with
  the default `data_type = "aggregate"`, a plain
  `eri_ingest(path, country, disease)` now stages to
  `.../{data_source}/aggregate/staged/` (was
  `.../{data_source}/staged/`); pass the matching `data_type` to
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).
  This finishes the measure-into-path work for the ingest entry point
  and is the foundation the CMR per-disease split builds on.

### Feature: `eri_approve()` signposts the no-measure (four-axis) form (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4)

- When
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  runs without a `data_type`, the dataset is filed and catalogued at the
  channel level with the measure recorded as `NA`. That is legitimate
  for channel-only data (e.g. ODK), but it used to be silent —
  indistinguishable from forgetting the measure.
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  now emits a quiet, **once-per-session** `cli_inform` the first time
  the four-axis form is used, pointing to `data_type` and ADR-0012.
  Supplying a measure is silent. Surfaced by a fresh-DA red-team run.

### Feature: `eri_research_pull()` speaks the five-axis model (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4b)

- [`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
  — the Epi sourcing entry point — now takes `data_source` (the channel)
  plus an optional `data_type` (the measure), matching the coordinates
  \[eri_catalog_query()\] reports, so a study pulls canonical processed
  data with the same tokens a discovery query returns:
  `eri_research_pull("dr", "malaria", "surveillance", "case")`. Path
  construction delegates to
  [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md),
  so the four-axis (channel-only) form works too. **Back-compat:** the
  pre-ADR-0012 form where the channel was passed as `data_type`
  (`data_type = "surveillance"`) still resolves to the same processed
  path. Surfaced by a fresh-Epi red-team run as the one un-migrated step
  on the sourcing path. Note: because `data_source` is inserted before
  `data_type`, the `path` argument moves from the fourth to the fifth
  position — pass it by name
  (`eri_research_pull(path = "spatial/...")`), as the docs already do.

### Feature: the measure (`data_type`) reaches the human gate and the catalog (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4b)

- [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  gains an optional `data_type` (the measure) argument:
  `eri_approve(country, disease, data_source, period, data_type = NULL, …)`.
  When supplied it promotes the full five-axis path
  `{country}/{disease}/{data_source}/{data_type}/staged → processed/`
  and records the measure in the approval log, the operation log, and
  the catalog. The third positional argument is now named `data_source`
  (it always carried the channel); `data_type` defaults to `NULL`, so
  existing four-axis calls —
  `eri_approve("dr", "malaria", "surveillance", "2024-W01")` — are
  unchanged.
- The data catalog carries a `data_source` column alongside `data_type`,
  and
  [`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md)
  /
  [`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md)
  gain a `data_source` argument
  (`eri_catalog_register(... , data_source, ... , data_type = NULL)`;
  `eri_catalog_query(... , data_source = NULL, data_type = NULL, ...)`).
  Four-axis entries leave `data_type` as `NA`. Legacy positional
  [`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md)
  calls that passed the channel as `data_type` now pass it as
  `data_source`.
- The log triage reader follows the writer:
  [`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
  scans both the four-axis channel-level `…/{data_source}/logs/` and the
  five-axis measure-level `…/{data_source}/{data_type}/logs/` layouts,
  and its backlog tibble gains a `data_source` column with `data_type`
  now meaning the measure.
  `eri_logs(country, disease, data_source, data_type = NULL, …)` and
  `eri_dq_log(result, country, disease, data_source, data_type = NULL, …)`
  rename the old third/fourth argument to `data_source` (it always held
  the channel) and add the optional measure. Positional callers passing
  the channel third are unchanged.

### Feature: onboarding scaffolders emit the 4-part schema identity (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 4a)

- [`eri_onboard_disease()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_disease.md)
  and
  [`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md)
  now write schema skeletons named to the ADR-0012 identity
  `{country}_{disease}_{data_source}_{data_type}.yaml` with
  `data_source` / `data_type` header fields: `mda` → `programmatic` /
  `treatment`, `prevalence` → `research` / `prevalence`, and
  surveillance → `surveillance` / `{data_type}` (new
  `eri_onboard_country(data_type = "aggregate")` argument). So a freshly
  onboarded program is consistent with the migrated bundled schemas and
  loads via the 4-arg
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md).
  The DA onboarding guide is updated to match.

### Feature: `eri_ingest()` is a general, sandbox-runnable ingest core (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 3a)

- [`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md)
  no longer requires the `hsp-mal` pipeline registry or a registered
  country, and no longer *forces* a write to the legacy `projects` blob.
  It reads, DQ-checks, and stages to
  `data/{country}/{disease}/{data_source}/staged/` on **any** data — so
  the guides can finally teach it on a throwaway sandbox. Signature:
  `eri_ingest(path, country, disease, data_source = "surveillance", data_type = "aggregate", …)`.
- The legacy `projects`-blob dual-write is now the **opt-in
  `mirror_pipeline`** argument (default `NULL`); legacy callers pass
  `mirror_pipeline = "hsp-mal"`. The `.eri_schema_country_map` hack is
  retired (schemas are code-prefixed now). These mirror bits are
  transitional and removed at the Phase-3 hsp-mal cutover.

### Feature: DQ schemas keyed by `(country, disease, data_source, data_type)` (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 2)

- Bundled schemas are renamed to
  `{country}_{disease}_{data_source}_{data_type}.yaml` and carry
  `data_source` / `format` fields. `data_source` is `surveillance` /
  `programmatic` / `research`; **ODK is a research `format`** and **CMR
  a programmatic `format`** (the channel, not the lane). Country codes
  are normalised (`ug` → `uga`) and disease names too (`rb` → `oncho`).
- [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
  gains the four-argument identity form
  `load_dq_schema(country, disease, data_source, data_type)` (the
  measure is optional for `research`). The legacy two-argument form —
  where the second argument held a combined key like `"malaria_case"` or
  `"lf_tas"` — **still resolves** via an alias to the new name, so
  existing callers keep working.
- DR and HT malaria each keep **both** a `case` and an `aggregate`
  surveillance schema (they are distinct, not duplicates). Part of the
  [\#175](https://github.com/thecartercenter/erifunctions/issues/175)
  migration (ADR-0012).
- *Deferred to phase 4:* the `eri_onboard_*` scaffolders and the
  `adding-a-program` / `epi-analytics` / `da-ingest` guides still
  emit/teach the old `{country}_{disease}_{type}` names; they keep
  working via the alias shim and are swept to the four-part identity
  with the rest of the docs/onboarding pass.

### Feature: five-axis data addressing — `data_source` vs `data_type` (ADR-0012, [\#175](https://github.com/thecartercenter/erifunctions/issues/175) phase 1)

- The canonical path gains a measure axis:
  `data/{country}/{disease}/{data_source}/{data_type}/{layer}/`.
  `data_source` is the **channel** (`surveillance`, `programmatic`,
  `odk`); `data_type` is the **measure** (`case`, `aggregate`,
  `treatment`, `tas`, …). See
  [ADR-0012](https://thecartercenter.github.io/erifunctions/news/docs/adr/0012-source-measure-data-model.md).
- [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md)
  now takes
  `(country, disease, data_source, data_type, layer, filename)`. The
  legacy four-axis form
  `eri_data_path(country, disease, data_source, layer)` still resolves
  during the migration (detected because its fourth argument is a
  `layer` keyword), so existing callers keep working.
- New
  [`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)
  shows the registry of known `data_source` / `data_type` / `format`
  values. The axes are **extensible**: an unregistered value *warns*
  rather than errors, so onboarding a new source/measure never blocks
  data — first step of the ADR-0012 migration that will close
  [\#175](https://github.com/thecartercenter/erifunctions/issues/175).

### Docs: one vocabulary for addressing data and schemas

- A new README section (“How data is addressed”) names the four path
  axes — `country` / `disease` / `data_type` / `layer` — and clarifies
  that a DQ **schema key** (e.g. `malaria_case`, passed to
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md))
  is *not* a `data_type`.
  [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md)’s
  error now says so explicitly when a schema key is passed where a
  `data_type` belongs. This is Phase 1 of
  [ADR-0011](https://thecartercenter.github.io/erifunctions/news/docs/adr/0011-unified-schema-naming.md);
  the bundled schema names will be unified to one convention in a
  follow-up
  ([\#175](https://github.com/thecartercenter/erifunctions/issues/175)).
  Fixes the user-facing half of a fresh-user red-team finding.

### Improvement: `eri_spatial_reconcile()` surfaces the geocoded admin unit for review

- The function now returns one `geocoded_<admin_col>` column per admin
  level, holding the admin units the geocoded point fell into
  (point-in-polygon). They are filled for every geocoded row that landed
  inside a polygon — **including `geocoded_review` rows** — so a flagged
  row shows *exactly* what its geocoded location disagreed with, and you
  can resolve it without re-running a spatial join by hand. (`NA` for
  `matched`, `unresolved`, and outside-polygon rows.) Fixes a fresh-user
  red-team finding
  ([\#174](https://github.com/thecartercenter/erifunctions/issues/174)).

### Improvement: a one-time warning when `ERI_ANALYST_ID` is unset

- Governed actions (approve, ingest, ODK sync, catalog/registry writes,
  research operations, log resolution) stamp the **shared audit trail**
  with the analyst’s identity. When `ERI_ANALYST_ID` is unset **or
  empty**, erifunctions still falls back to the OS username — but now
  **warns once per session** so you know approvals and logs will be
  attributed to that fallback rather than your analyst id. (Previously
  an explicitly-empty `ERI_ANALYST_ID` would have stamped an empty
  actor; it now falls back too.) Identity resolution is centralised in a
  single internal helper. Fixes a fresh-user red-team finding
  ([\#171](https://github.com/thecartercenter/erifunctions/issues/171)).

### Docs: flag the steps you can’t rehearse on a sandbox

- The ODK guide now says up front that creating the project, uploading
  the form, and submitting practice entries happen in the ODK Central
  **web interface**, not in R.
- The CMR guide spells out that there is **no throwaway-sandbox path**
  for
  [`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
  / approve (they require a registered RB-expansion country); only the
  parsing step is hands-on.
- The connections guide notes that
  [`eri_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_list.md)’s
  `name` column holds the **full path** and that `full_names = FALSE`
  returns just the leaf filenames. Fresh-user findings
  ([\#177](https://github.com/thecartercenter/erifunctions/issues/177)).

### Fix: friendlier schema discovery and an accurate research-function reference

- [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
  now **lists the available bundled schema keys** when it cannot find
  the one you asked for — so `load_dq_schema("dr", "malaria")` points
  you to `dr_malaria_case` instead of a bare “No schema found.” error.
- The README’s research-projects reference now includes
  [`eri_research_scaffold()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_scaffold.md),
  [`eri_research_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_status.md),
  and
  [`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md)
  (previously omitted) and clarifies
  [`eri_research_scaffold()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_scaffold.md)
  (a new standalone project *repository*, ADR-0006) vs
  [`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md)
  (initialise a project in the current directory).
- The DQ guide names the `disease` argument in
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
  examples and notes that the schema key (e.g. `malaria_case`) is
  distinct from the layer-path `data_type`. Fresh-user findings
  ([\#176](https://github.com/thecartercenter/erifunctions/issues/176)).
  (The deeper `data_type`-vs-schema-key vocabulary unification is
  tracked in
  [\#175](https://github.com/thecartercenter/erifunctions/issues/175).)

### Improvement: `dq_report()` shows the offending values, not just counts

- The “Flags Requiring Review” section now prints up to three example
  offending values with their row numbers for each issue —
  e.g. `not in allowed_values: 2 rows [species] (e.g. P.vivax (row 4); P.ovale (row 2))`
  — with a `+N more` suffix when there are more, and a closing pointer
  to `result$flags` for the full row-level detail. Previously it printed
  only a count and column, so an analyst had to open `result$flags` to
  see *what* to fix. Fixes a fresh-user red-team finding
  ([\#178](https://github.com/thecartercenter/erifunctions/issues/178)).

### Fix: `eri_catalog_query()` no longer says “Catalog is empty” for a no-match filter

- A filtered
  [`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md)
  that matches nothing now reports *“No catalog entries match the
  specified filters”* — even when the catalog itself happens to have no
  entries — instead of the old *“Catalog is empty.”*, which could make a
  filtered lookup look like it had wiped the shared catalog. An
  unfiltered query on a truly empty catalog now reads *“The data catalog
  has no entries yet.”* Fixes a fresh-user red-team finding
  ([\#173](https://github.com/thecartercenter/erifunctions/issues/173)).

### Fix: cleaner console output from `eri_read()` and the file-writing helpers

- [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
  no longer prints `readr`’s column-specification block when reading a
  CSV (it now reads with `show_col_types = FALSE` / suppresses the
  message on both the local and Azure paths), so a read no longer erupts
  with engine noise in the middle of a pipeline.
- The side-effecting helpers
  ([`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md),
  [`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md),
  [`eri_dir_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_create.md),
  [`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md),
  [`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md))
  now return **invisibly**, so scripted / `Rscript` runs no longer print
  stray `NULL` lines between steps. Both fixes come from the fresh-user
  red-team
  ([\#172](https://github.com/thecartercenter/erifunctions/issues/172)).

### Docs: guides clean up with `eri_dir_delete()`/`eri_delete()`, not raw AzureStor

- Every guide’s “Clean up” section now tears down its sandbox with the
  exported
  [`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md)
  /
  [`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md)
  instead of
  [`AzureStor::delete_storage_dir()`](https://rdrr.io/pkg/AzureStor/man/generics.html)
  / `delete_storage_file()`. This keeps an analyst inside `erifunctions`
  for the one operation most likely to send them to Azure Storage
  Explorer, rather than dropping to raw blob calls. Fixes the fresh-user
  red-team’s top finding
  ([\#170](https://github.com/thecartercenter/erifunctions/issues/170)).

### Feature: ODK forms with repeat groups are now captured in full

- ODK Central exports a form with **repeat groups** as multiple tables —
  a parent table (one row per submission) plus one child table per
  repeat group, linked by `PARENT_KEY` → the parent’s `KEY`. Previously
  [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
  read only the parent CSV and
  [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
  wrote a single Parquet, so **repeat data was silently dropped**.
- [`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
  gains a `tables` argument. The default (`tables = FALSE`) is unchanged
  — it returns the parent table as a single tibble. With `tables = TRUE`
  it returns a **named list of every table** in the export (parent
  first, named by each table’s CSV).
- [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
  now writes **one Parquet per table** to `{country}/{disease}/odk/raw/`
  — single- table forms are unchanged (still exactly one Parquet);
  repeat forms produce `{form_id}.parquet` plus
  `{form_id}-{repeat}.parquet` for each repeat group.
- **New bundled XLSForm** `inst/extdata/odk-test-form-repeat.xlsx` (a
  river-prospection form with a repeated `larva_sample` group) and a new
  **“Forms with repeat groups”** section in the ODK guide
  (`vignettes/da-odk-guide.Rmd`) showing the parent/child tables, the
  `PARENT_KEY` join, and the one-Parquet-per-table sync.

### Fix: `eri_onboard_cmr()` creates the canonical `rblf/cmr/` directories

- [`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)
  now creates CMR Azure directories at
  `{country}/rblf/cmr/{raw,staged,processed}/` — the location
  [`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
  and
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  actually use — instead of per-disease folders like
  `{country}/{disease}/cmr/`, which never matched the pipeline. The
  `diseases` argument is replaced by `create_dirs` (logical): CMR for
  the RB-expansion programmes is filed under the combined `rblf` code
  (RB + LF), not split by disease.

### Documentation: a monthly CMR upload guide for data analysts

- **New article — “Uploading and processing a monthly country report
  (CMR)”** (`vignettes/da-cmr-guide.Rmd`). The Data Analyst monthly job:
  upload a filed CMR Excel to the `projects` blob,
  [`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
  it into `staged/`, parse each sheet with
  [`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md)
  (by its machine-readable `#field-code` row — language-neutral, so it
  parses English and French templates alike), and
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  it into `processed/`. The parsing step is run live on a new bundled
  synthetic example report (`inst/extdata/cmr-example.xlsx`); the Azure
  steps are shown as representative output. **Completes the
  `docs/guides.md` role × task matrix.**

### Documentation: an Epidemiologist anomaly-detection guide

- **New article — “Catching anomalies in a new surveillance extract”**
  (`vignettes/epi-dq-guide.Rmd`). A run-it-live, offline walkthrough of
  the anomaly detectors for epidemiologists: after
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md),
  chain
  [`add_anomaly_pct_change()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_pct_change.md)
  (case spikes),
  [`add_anomaly_gaps()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_gaps.md)
  (missing reporting weeks),
  [`add_anomaly_consistency()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_consistency.md)
  (cross-field rules), and
  [`add_anomaly_spatial()`](https://thecartercenter.github.io/erifunctions/reference/add_anomaly_spatial.md)
  (unrecognized admin names) on a synthetic multi-period extract, and
  interpret each flag. Complements the `dq-pipeline.Rmd` reference
  (which documents the schema + detector mechanics).

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
