# CMR - Monthly Report ingestion and schema loading

# Synthetic, non-real "countries" whose CMR schema exists only to exercise the
# pipeline for training/testing (no real reporting country's namespace touched).
# Listed separately in the schema-not-found hint so a DA who mistypes a real
# code isn't offered a fictional one as if it were real.
.eri_cmr_sandbox_countries <- "atlantis"

#' Load a CMR country schema
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads the bundled CMR YAML schema for a given country code. Schemas live in
#' `inst/schemas/cmr/` and define which sheets are present for that country and
#' the required field codes expected in each sheet.
#'
#' @param country `str` Country code, usually the three-letter reporting code
#'   (e.g. `"uga"`, `"eth"`). A training sandbox schema such as `"atlantis"` —
#'   a fictional country for exercising the pipeline without touching real data
#'   — is also accepted.
#'
#' @returns A named list with keys `country`, `country_code`, `language`,
#'   `template`, and `sheets`. Each element of `sheets` is itself a named list
#'   with `field_code_prefix` and `required_fields`.
#' @examples
#' schema <- load_cmr_schema("uga")
#' names(schema$sheets)  # sheet names present for Uganda
#' @export
load_cmr_schema <- function(country) {
  schema_dir <- system.file("schemas", "cmr", package = "erifunctions")
  if (!nzchar(schema_dir)) {
    cli::cli_abort("CMR schema directory not found in package installation.")
  }
  path <- file.path(schema_dir, paste0(country, ".yaml"))
  if (!file.exists(path)) {
    all_schemas <- tools::file_path_sans_ext(
      list.files(schema_dir, pattern = "\\.yaml$")
    )
    sandbox   <- intersect(all_schemas, .eri_cmr_sandbox_countries)
    available <- setdiff(all_schemas, sandbox)
    cli::cli_abort(c(
      "No CMR schema found for country {.val {country}}.",
      "i" = "Available: {.val {available}}",
      if (length(sandbox) > 0) {
        c("i" = "Training sandbox (not a real country): {.val {sandbox}}")
      }
    ))
  }
  yaml::read_yaml(path)
}

#' Read and parse a CMR monthly report Excel file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads a single sheet from a Carter Center RBLF monthly report template,
#' using the machine-readable field code row (row 5 of the template) as column
#' names. Field codes (e.g. `#rbtrt_year`, `#rbtrt_adm1`) are consistent across
#' all country templates regardless of language, so the same function parses
#' both English and French templates.
#'
#' ## Template structure assumed
#' | Row | Content |
#' |-----|---------|
#' | 1 | Sheet title |
#' | 2 | Empty spacer |
#' | 3 | Group headers (Location / Targets / Month columns) |
#' | 4 | Human-readable column names |
#' | 5 | Machine-readable field codes — **parsing anchor** |
#' | 6+ | Data |
#'
#' @param path `str` Local path to the CMR Excel file.
#' @param sheet `str` or `int` Sheet name, 1-based index, or canonical slug
#'   (e.g. `"rb_treatment"`). Slugs are resolved to actual sheet names via the
#'   country schema's `sheet_aliases` block when `country` is supplied.
#' @param country `str` or `NULL` Optional country code (e.g. `"tcd"`, `"uga"`).
#'   When supplied, the country code is prepended as a `country` column and slug
#'   aliases are resolved. Default `NULL`.
#'
#' @returns A tibble with field-code column names and data from row 6 onward,
#'   plus an `excel_row` column recording each row's real position in the
#'   workbook (survives all-NA spacer-row dropping, so it stays accurate even
#'   after rows are removed). If `country` is supplied it is prepended as a
#'   `country` column.
#' @examples
#' \dontrun{
#' # English template — sheet name directly
#' df <- eri_ingest_cmr("data/uga_2024_01.xlsx", sheet = "RB Treatment", country = "uga")
#' # French template — canonical slug resolved via schema
#' df <- eri_ingest_cmr("data/tcd_2024_01.xlsx", sheet = "rb_treatment", country = "tcd")
#' }
#' @family CMR pipeline functions
#' @export
eri_ingest_cmr <- function(path, sheet, country = NULL) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

  actual_sheet <- sheet
  if (!is.null(country) && is.character(sheet)) {
    schema <- tryCatch(load_cmr_schema(country), error = function(e) NULL)
    if (!is.null(schema) && !is.null(schema$sheet_aliases)) {
      resolved <- schema$sheet_aliases[[sheet]]
      if (!is.null(resolved)) actual_sheet <- resolved
    }
  }

  # Fail with a helpful, named error rather than readxl's opaque one when the
  # sheet (after alias resolution) isn't in the workbook.
  if (is.character(actual_sheet)) {
    available <- readxl::excel_sheets(path)
    if (!actual_sheet %in% available) {
      cli::cli_abort(c(
        "Sheet {.val {actual_sheet}} not found in {.path {basename(path)}}.",
        "i" = "Available sheets: {.val {available}}."
      ))
    }
  }

  raw <- readxl::read_excel(path, sheet = actual_sheet, skip = 4,
                             col_names = TRUE, .name_repair = "minimal")

  field_pos  <- which(startsWith(names(raw), "#"))
  field_cols <- names(raw)[field_pos]

  if (length(field_cols) == 0) {
    cli::cli_abort(c(
      "No field code columns found in sheet {.val {sheet}} of {.path {basename(path)}}.",
      "i" = "Row 5 of the template should contain machine-readable codes starting with {.code #} (e.g. {.code #rbtrt_year}).",
      "i" = "Check that {.arg sheet} is correct and the template has not been modified."
    ))
  }

  # A real template can have the same field code typed twice in row 5 (a
  # copy-paste slip when a monthly block was duplicated, not a data problem).
  # Selecting by position (not by name) keeps both columns' data distinct;
  # de-duplicating the names lets the rest of the pipeline proceed instead of
  # hard-erroring on every row of an otherwise-valid submission.
  dup <- duplicated(field_cols) | duplicated(field_cols, fromLast = TRUE)
  if (any(dup)) {
    cli::cli_warn(c(
      "Sheet {.val {actual_sheet}} has duplicate field code{?s} in row 5 (a template defect): {.val {unique(field_cols[dup])}}.",
      "i" = "Kept both columns; the later one is suffixed ({.code __1}, {.code __2}, ...).",
      "i" = "Flag this to whoever maintains the CMR template."
    ))
    field_cols <- make.unique(field_cols, sep = "__")
  }

  df <- raw[, field_pos, drop = FALSE]
  names(df) <- field_cols

  # The template's row 6 is the first data row (row 5 is the field-code
  # header, consumed by skip = 4 + col_names = TRUE); track each row's real
  # Excel row so a flagged issue can point a DA at the actual cell to fix,
  # not a post-filtering index into the parsed tibble.
  excel_row <- seq_len(nrow(df)) + 5L

  all_na    <- apply(df, 1, function(r) all(is.na(r)))
  df        <- tibble::as_tibble(df[!all_na, , drop = FALSE])
  excel_row <- excel_row[!all_na]
  df        <- tibble::add_column(df, excel_row = excel_row, .before = 1)

  if (!is.null(country)) {
    df <- tibble::add_column(df, country = country, .before = 1)
  }

  cli::cli_alert_success(
    "CMR sheet {.val {actual_sheet}}: {nrow(df)} data row{?s}, {length(field_cols)} field code{?s}."
  )

  df
}

#' Split a CMR monthly report into per-disease, per-measure staged datasets
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads every sheet a country's CMR schema routes (those declaring a `disease`
#' and a `data_type`), and writes each sheet's parsed rows to
#' `data/{country}/{disease}/programmatic/{data_type}/staged/` in the `data` blob
#' (ADR-0012, #175). The **disease comes from the sheet** (e.g. `RB Treatment` →
#' `oncho`, `SCH Treatment` → `sch`, `LF MMDP` → `lf`); cross-programme Training
#' sheets route together under the combined `rblf` disease. The per-row
#' `#..._disease` field — which holds program-coverage codes (`RB` / `RBLF` /
#' `RBLFSCH`) — is kept as a data column, **not** split on, so no row is
#' duplicated across diseases.
#'
#' Data is staged **parsed as-is** (machine-readable `#field-code` columns; no
#' reshape, no automated DQ — CMR review is manual). [eri_approve()] then promotes
#' each `{disease}/programmatic/{data_type}` to `processed/`.
#'
#' If `country` has no bundled CMR schema, this does not just abort: it also
#' writes a starter schema template for that country to the working directory
#' (the same template [eri_onboard_cmr()] produces) so the failure leaves you
#' with something to edit and submit, not just a dead end.
#'
#' ## Mirroring to the legacy contractor pipeline
#'
#' During the Phase-3 parallel run, some countries' CMR still also feeds a
#' legacy contractor process that reads the raw workbook from a fixed Azure
#' location (`{project_folder}/{raw_dir}/{country}/{period}/`, e.g.
#' `health-rb-country-expansion-dev/raw/filled_templates/ssd/202605/`). Passing
#' `mirror_pipeline` uploads `path` there too, so a DA does **one step**
#' (`eri_split_cmr(..., mirror_pipeline = "rb-expansion")`) instead of also
#' separately dropping the file for the legacy pipeline to pick up. `period`
#' defaults to a `YYYYMM` prefix parsed from `basename(path)` (the real
#' convention observed in submitted filenames); pass it explicitly if the
#' filename doesn't start that way.
#'
#' This does **not** replace [eri_stage_cmr()]: that function reads the *same*
#' raw-drop location and copies the workbook into `data/{country}/rblf/cmr/staged/`
#' as the governed raw archive `eri_approve()` promotes. `mirror_pipeline` here
#' only *writes* to the raw-drop location for the legacy pipeline's benefit — a
#' DA doing a fresh-period pilot run may still want both:
#' `eri_split_cmr(..., mirror_pipeline = ...)` then [eri_stage_cmr()] (or the
#' reverse order; neither depends on the other having run first).
#'
#' ## Re-splitting the same period from a corrected file
#'
#' If you fix an issue upstream and re-run this on a different local file (e.g.
#' the `_fixed.xlsx` copy convention) for a period already split, the prior
#' staged file(s) for each sheet's destination folder are removed first (when
#' `period` is known) -- otherwise both the broken original and the corrected
#' file would sit in `staged/` together, and [eri_approve()]'s period-substring
#' match would promote both. Each removal is logged as a `supersede_staged`
#' step.
#'
#' @param path `str` Local path to the CMR Excel file.
#' @param country `str` Three-letter country code (e.g. `"uga"`); resolves the
#'   CMR schema via [load_cmr_schema()].
#' @param data_con Azure container for the `data` blob. `NULL` connects using
#'   `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#' @param overwrite `logical` If `FALSE` (default), warns before overwriting an
#'   existing staged file.
#' @param dry_run `logical` If `TRUE`, returns the routing plan and writes no
#'   *data*. Default `FALSE`. One exception: if the dry run finds a skipped
#'   sheet or a warning, that fact **is** logged (a lightweight triage entry,
#'   not staged data) so there's a stable `log_path` to attach an
#'   [eri_logs_resolve()] note to later -- see step 3 of the CMR guide.
#' @param mirror_pipeline `str` or `NULL` Registered pipeline name (e.g.
#'   `"rb-expansion"`) whose legacy raw-drop location `path` should also be
#'   uploaded to. Default `NULL` (no mirror; sandbox-safe).
#' @param period `str` or `NULL` Reporting period (e.g. `"202605"`), used to tag
#'   the op-log (so [eri_cmr_last_plan()] can find this run again) and, if
#'   `mirror_pipeline` is set, the mirror upload. `NULL` (default) parses a
#'   leading `YYYYMM_` from `basename(path)`; only required to be resolvable
#'   when `mirror_pipeline` is set.
#' @param projects_con Azure container for the `projects` blob; used only when
#'   `mirror_pipeline` is set. If `NULL`, connects automatically.
#' @param supersede_staged `logical` Re-splitting the same period from a
#'   DIFFERENT local file (e.g. a `_fixed.xlsx` correction) can leave a prior
#'   staged file behind in each destination folder -- `eri_approve()`'s period
#'   match would then promote both to `processed/`. When `period` is known,
#'   candidate stale files (their name starts with `period`, not just contains
#'   it anywhere -- the real filename convention, so this doesn't collide with
#'   an unrelated file that merely mentions those six digits) are always
#'   detected and reported. Default `FALSE` only warns about them -- **this
#'   package's first destructive Azure operation is opt-in, not automatic**;
#'   set `TRUE` to actually delete them. Ignored (nothing detected or deleted)
#'   when `period` couldn't be resolved.
#' @returns Invisibly, a tibble with one row per routed sheet: `sheet`, `disease`,
#'   `data_type`, `dest`, `n_rows`.
#' @examples
#' \dontrun{
#' # Preview where each sheet would land
#' eri_split_cmr("uga_2024_06.xlsx", "uga", dry_run = TRUE)
#' # Stage for real, then approve each disease/measure
#' eri_split_cmr("uga_2024_06.xlsx", "uga")
#' eri_approve("uga", "oncho", "programmatic", "2024-06", data_type = "treatment")
#' # One step: also mirror the raw file to the legacy contractor pipeline
#' eri_split_cmr("202605_ssd_report.xlsx", "ssd", mirror_pipeline = "rb-expansion")
#' # Re-splitting a corrected file for a period already staged: opt in to
#' # actually removing the superseded original (default only warns)
#' eri_split_cmr("202605_ssd_report_fixed.xlsx", "ssd", supersede_staged = TRUE)
#' }
#' @family CMR pipeline functions
#' @export
eri_split_cmr <- function(path, country, data_con = NULL,
                          overwrite = FALSE, dry_run = FALSE,
                          mirror_pipeline = NULL, period = NULL,
                          projects_con = NULL, supersede_staged = FALSE) {
  if (!dry_run) .eri_log_session()
  # ADR-0020: normalize once, up front -- the country_map/schema lookups and
  # the hand-built log_dir (there's no per-disease data path here; the run
  # splits into several) all need to agree.
  country <- .eri_normalize_geo_axis("country", country, .eri_known_countries())
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

  # Identity for the workbook this run splits, not security -- carried into
  # every measure's dq_flags entry (via the plan) so an audit trail can
  # confirm exactly which submission a flag/approval traces back to. Computed
  # once, up front, so it's identical whether this call is a dry run or real.
  source_hash <- unname(tools::md5sum(path))

  # Resolve period generally (not just for the mirror): a leading YYYYMM_ in
  # the filename, same convention observed in real submissions. Used to tag
  # the op-log so eri_cmr_last_plan() can find this run again later. Failing
  # to detect it here is only fatal if mirror_pipeline needs it (below).
  if (is.null(period)) {
    detected <- regmatches(basename(path), regexpr("^\\d{6}(?=_)", basename(path), perl = TRUE))
    if (length(detected) > 0L) period <- detected
  }

  # Validate the optional legacy mirror up front (fail fast, no I/O), same
  # spirit as eri_ingest()'s mirror_pipeline.
  mirror <- NULL
  if (!is.null(mirror_pipeline)) {
    reg <- .eri_pipeline_registry[[mirror_pipeline]]
    if (is.null(reg)) {
      cli::cli_abort(c(
        "Unknown pipeline {.val {mirror_pipeline}}.",
        "i" = "Registered pipelines: {paste(names(.eri_pipeline_registry), collapse = ', ')}."
      ))
    }
    if (is.null(reg$raw_dir)) {
      cli::cli_abort(c(
        "Pipeline {.val {mirror_pipeline}} has no legacy raw-drop location registered.",
        "i" = "Only pipelines with a {.field raw_dir} entry support mirroring from {.fn eri_split_cmr}."
      ))
    }
    subfolder <- reg$country_map[[country]]
    if (is.null(subfolder)) {
      cli::cli_abort(c(
        "Country {.val {country}} is not registered for pipeline {.val {mirror_pipeline}}.",
        "i" = "Registered countries: {paste(names(reg$country_map), collapse = ', ')}."
      ))
    }
    if (is.null(period)) {
      cli::cli_abort(c(
        "Could not parse a {.val YYYYMM} period from {.path {basename(path)}}.",
        "i" = "Pass {.arg period} explicitly (e.g. {.code period = \"202605\"})."
      ))
    }
    mirror <- list(reg = reg, subfolder = subfolder, period = period)
  }

  schema <- tryCatch(load_cmr_schema(country), error = function(e) e)
  if (inherits(schema, "error")) {
    scaffold_path <- file.path(getwd(), paste0(country, "_cmr_schema.yaml"))
    if (!file.exists(scaffold_path)) {
      writeLines(.cmr_schema_template(country, paste0("TODO: full name for ", country), "en"),
                 scaffold_path)
      cli::cli_alert_info("Wrote a starter CMR schema template: {.path {scaffold_path}}")
    }
    cli::cli_abort(c(
      conditionMessage(schema),
      "i" = "A starter template is waiting at {.path {scaffold_path}} -- fill in {.field country}, uncomment the sheets this country's real CMR uses, and re-run.",
      "i" = "Or scaffold fresh (and optionally create the Azure dirs) with {.fn eri_onboard_cmr}."
    ))
  }
  routable <- Filter(
    function(s) !is.null(s$disease) && !is.null(s$data_type),
    schema$sheets
  )
  if (length(routable) == 0L) {
    cli::cli_abort(c(
      "No routable sheets in the {.val {country}} CMR schema.",
      "i" = "A sheet routes only when it declares both {.field disease} and {.field data_type}."
    ))
  }

  available <- readxl::excel_sheets(path)
  fbase     <- tools::file_path_sans_ext(basename(path))
  slug      <- function(x) gsub("_+", "_", gsub("[^a-z0-9]+", "_", tolower(x)))

  plan     <- list()
  skipped  <- character(0)
  warnings_seen <- character(0)
  for (sheet_name in names(routable)) {
    spec <- routable[[sheet_name]]
    if (!sheet_name %in% available) {
      skipped <- c(skipped, sheet_name)
      next
    }
    # Observe (don't muffle) warnings from parsing -- they still propagate
    # normally, this just also lets the dry-run summary below say whether
    # anything needs attention before you run for real.
    df <- withCallingHandlers(
      eri_ingest_cmr(path, sheet = sheet_name, country = country),
      warning = function(w) {
        warnings_seen <<- c(warnings_seen, paste0(sheet_name, ": ", conditionMessage(w)))
      }
    )
    dest_dir <- eri_data_path(country, spec$disease, "programmatic", spec$data_type, "staged")
    dest     <- paste0(dest_dir, "/", fbase, "_", slug(sheet_name), ".parquet")
    plan[[length(plan) + 1L]] <- list(
      sheet = sheet_name, disease = spec$disease, data_type = spec$data_type,
      dest = dest, dest_dir = dest_dir, n_rows = nrow(df), data = df
    )
  }

  # One tidy summary of sheets the schema routes but this workbook lacks, rather
  # than a deferred pile of individual warnings.
  if (length(skipped) > 0L) {
    cli::cli_inform(c(
      "i" = "Skipped {length(skipped)} sheet{?s} not in {.path {basename(path)}}: {.val {skipped}}."
    ))
  }

  # A wrong workbook (none of the schema's routable sheets present) is an error,
  # not a silent 0-routed success.
  if (length(plan) == 0L) {
    cli::cli_abort(c(
      "None of the {.val {country}} CMR routable sheets were found in {.path {basename(path)}}.",
      "i" = "Routable sheets: {paste(names(routable), collapse = ', ')}."
    ))
  }

  plan_tbl <- tibble::tibble(
    sheet       = vapply(plan, function(p) p$sheet,     character(1L)),
    disease     = vapply(plan, function(p) p$disease,   character(1L)),
    data_type   = vapply(plan, function(p) p$data_type, character(1L)),
    dest        = vapply(plan, function(p) p$dest,      character(1L)),
    n_rows      = vapply(plan, function(p) p$n_rows,    integer(1L)),
    source_hash = source_hash
  )

  if (dry_run) {
    cli::cli_inform(c("i" = "Dry run -- no data written. Routing plan:"))
    for (p in plan) {
      cli::cli_inform("  {.val {p$sheet}} -> {.path {p$dest}} ({p$n_rows} row{?s})")
    }
    if (!is.null(mirror)) {
      mirror_dir <- paste(c(mirror$reg$project_folder, mirror$reg$raw_dir,
                             mirror$subfolder, mirror$period), collapse = "/")
      cli::cli_inform(c(
        "i" = "Would also mirror raw file -> {.path {mirror_dir}}/{country}_{mirror$period}_<timestamp>.{tools::file_ext(path)}",
        " " = "(the timestamp is generated fresh at write time, not reused from this preview)"
      ))
    }

    if (length(skipped) == 0L && length(warnings_seen) == 0L) {
      cli::cli_alert_success("Dry run clean -- no issues found. Ready to run for real.")
    } else {
      cli::cli_alert_warning(
        "Dry run found {length(skipped)} skipped sheet{?s} and {length(warnings_seen)} warning{?s} -- review before running for real."
      )
      dr_data_con <- tryCatch(
        if (is.null(data_con)) {
          suppressMessages(get_azure_storage_connection(
            storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
          ))
        } else data_con,
        error = function(e) NULL
      )
      if (!is.null(dr_data_con)) {
        dr_log_dir <- paste(c(country, "rblf", "cmr", "logs"), collapse = "/")
        dr_log_path <- .eri_write_log(
          list(
            operation  = "eri_split_cmr_dryrun",
            analyst    = .eri_analyst_id(dr_data_con),
            timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
            parameters = list(country = country, path = path),
            status     = "needs_review",
            skipped    = as.list(skipped),
            warnings   = as.list(warnings_seen)
          ),
          dr_data_con, dr_log_dir
        )
        if (!is.null(dr_log_path)) {
          cli::cli_alert_info(c(
            "i" = "Once you've fixed things, note what you did with {.run eri_logs_resolve('{dr_log_path}', note = '...')}."
          ))
        }
      }
    }

    return(invisible(plan_tbl))
  }

  if (is.null(period)) {
    cli::cli_warn(c(
      "Could not resolve a period for this run (no {.val YYYYMM_} prefix in {.path {basename(path)}}).",
      "i" = "This run's op-log will have no period, so {.fn eri_cmr_last_plan} won't be able to find it later.",
      "i" = "Pass {.arg period} explicitly if you'll want to recover this plan without keeping the R object."
    ))
  }

  data_con <- if (is.null(data_con)) {
    suppressMessages(get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
    ))
  } else data_con

  # One op-log per split run, co-located with eri_stage_cmr's log at the CMR
  # staging coordinate (the run spans multiple disease/measure outputs, so it has
  # no single per-disease home); the per-disease data lands under programmatic/.
  log_dir <- paste(c(country, "rblf", "cmr", "logs"), collapse = "/")
  op_log  <- list(
    operation  = "eri_split_cmr",
    analyst    = .eri_analyst_id(data_con),
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(country = country, path = path, period = period),
    source_file = basename(path),
    source_hash = source_hash,
    status     = "in_progress", steps = list(), error = NULL, files = NULL,
    # Structured routing table (sheet/disease/data_type/dest/n_rows), not just
    # the flat `files` path list -- lets eri_cmr_last_plan() reconstruct the
    # plan tibble later without rerunning eri_split_cmr() or keeping the R
    # object alive in-session. source_hash travels with each row so
    # eri_cmr_dq_report() can attribute a DQ check back to the exact workbook.
    plan = lapply(plan, function(p) {
      list(sheet = p$sheet, disease = p$disease, data_type = p$data_type,
           dest = p$dest, n_rows = p$n_rows, source_hash = source_hash)
    })
  )

  written   <- character(0)
  had_error <- FALSE
  err_msg   <- NULL

  tryCatch({
    # Re-splitting the same period from a DIFFERENT local file (e.g. a
    # "_fixed.xlsx" correction) can leave a prior staged file sitting
    # alongside the new one -- eri_approve()'s period match would then
    # promote both to processed/. Detect candidates whose name STARTS with
    # `period` (the real filename convention: "202605_..."), not merely
    # contains it anywhere -- an unanchored substring match would also catch
    # an unrelated file that happens to mention those six digits for some
    # other reason (a date, a facility code, ...) sharing this same
    # programmatic/{data_type}/staged/ folder from a different source.
    if (!is.null(period)) {
      # period is normally an auto-detected 6-digit string, but it's also a
      # caller-supplied argument with no enforced format -- escape it before
      # splicing into a PCRE pattern so a stray "." or "(" in a hand-typed
      # period can't widen the match or fail to compile.
      period_escaped <- gsub("([^A-Za-z0-9_])", "\\\\\\1", period, perl = TRUE)
      period_prefix  <- paste0("^", period_escaped, "(?!\\d)")  # period, not a longer number containing it
      seen_dirs <- character(0)
      for (p in plan) {
        if (p$dest_dir %in% seen_dirs) next
        seen_dirs <- c(seen_dirs, p$dest_dir)
        existing <- tryCatch(
          AzureStor::list_storage_files(data_con, p$dest_dir),
          error = function(e) NULL
        )
        if (is.null(existing) || nrow(existing) == 0L) next
        existing <- existing[!existing$isdir, , drop = FALSE]
        stale <- existing$name[
          grepl(period_prefix, basename(existing$name), perl = TRUE) &
          !startsWith(basename(existing$name), fbase)
        ]
        if (length(stale) == 0L) next

        if (isTRUE(supersede_staged)) {
          for (s in stale) {
            AzureStor::delete_storage_file(data_con, s, confirm = FALSE)
            op_log$steps <- .eri_log_step(op_log$steps, "supersede_staged", path = s)
            cli::cli_alert_info("Superseded a prior staged file for this period: {.path {basename(s)}}")
          }
        } else {
          cli::cli_warn(c(
            "{length(stale)} prior staged file{?s} for period {.val {period}} in {.path {p$dest_dir}} look{?s/} superseded by this run: {.val {basename(stale)}}.",
            "i" = "Not deleted -- pass {.code supersede_staged = TRUE} to remove {length(stale)} file{?s}, or they'll also be promoted by {.fn eri_approve}'s period match."
          ))
        }
      }
    }

    for (p in plan) {
      if (!AzureStor::storage_dir_exists(data_con, p$dest_dir)) {
        .eri_create_azure_dir(data_con, p$dest_dir)
        op_log$steps <- .eri_log_step(op_log$steps, "create_staged_dir", path = p$dest_dir)
      }
      if (AzureStor::storage_file_exists(data_con, p$dest) && !overwrite) {
        cli::cli_warn("Overwriting existing staged file: {.path {basename(p$dest)}}")
      }
      withr::with_tempfile("parquet_file", fileext = ".parquet", {
        arrow::write_parquet(p$data, parquet_file)
        .eri_blob_write(data_con, parquet_file, p$dest)
      })
      written      <- c(written, p$dest)
      op_log$steps <- .eri_log_step(op_log$steps, "split_sheet",
                                     sheet = p$sheet, disease = p$disease,
                                     data_type = p$data_type, dest = p$dest)
      .eri_say_done("{.val {p$sheet}} -> {.path {p$dest}}")
    }

    if (!is.null(mirror)) {
      if (is.null(projects_con)) {
        projects_con <- suppressMessages(get_azure_storage_connection())
      }
      mirror_dir  <- paste(c(mirror$reg$project_folder, mirror$reg$raw_dir,
                              mirror$subfolder, mirror$period), collapse = "/")
      # Generate the destination filename rather than reusing basename(path)
      # verbatim: real CMR filenames are human-titled ("...Data Report
      # Submitted_09-June-2026.xlsx") and can contain characters that break
      # the storage REST call (observed: HTTP 400 "invalid query parameter"
      # on this upload while the slugified parquet upload succeeded). A
      # generated name is also self-timestamping, so the DA doesn't need to
      # rename the local file to embed the period.
      mirror_ext  <- tools::file_ext(path)
      mirror_ts   <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
      mirror_name <- paste0(country, "_", mirror$period, "_", mirror_ts,
                            if (nzchar(mirror_ext)) paste0(".", mirror_ext) else "")
      mirror_dest <- paste0(mirror_dir, "/", mirror_name)
      if (!AzureStor::storage_dir_exists(projects_con, mirror_dir)) {
        .eri_create_azure_dir(projects_con, mirror_dir)
        op_log$steps <- .eri_log_step(op_log$steps, "create_mirror_dir", path = mirror_dir)
      }
      if (AzureStor::storage_file_exists(projects_con, mirror_dest) && !overwrite) {
        cli::cli_warn("Overwriting existing legacy raw file: {.path {basename(mirror_dest)}}")
      }
      .eri_blob_write(projects_con, path, mirror_dest)
      written      <- c(written, mirror_dest)
      op_log$steps <- .eri_log_step(op_log$steps, "mirror_legacy_raw",
                                     pipeline = mirror_pipeline, dest = mirror_dest)
      .eri_say_done("Mirrored raw file to legacy pipeline: {.path {mirror_dest}}")
    }

    .eri_summary("Split CMR by disease/measure", c(
      Sheets   = sprintf("%d routed", length(written) - as.integer(!is.null(mirror))),
      Diseases = paste(sort(unique(plan_tbl$disease)), collapse = ", ")
    ))
    op_log$status <- "success"
    op_log$files  <- as.list(written)
  }, error = function(e) {
    had_error <<- TRUE
    err_msg   <<- conditionMessage(e)
  })

  op_log$completed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (had_error) {
    op_log$status <- "error"
    op_log$error  <- err_msg
    op_log$steps  <- .eri_log_step(op_log$steps, "error_caught",
                                    status = "error", message = err_msg)
  }
  .eri_write_log(op_log, data_con, log_dir)
  if (had_error) cli::cli_abort(err_msg, call = NULL)

  .eri_task_epilogue("eri_split_cmr")
  invisible(plan_tbl)
}

#' Reconstruct a past `eri_split_cmr()` run's routing plan
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Recovers the routing plan (`sheet`, `disease`, `data_type`, `dest`, `n_rows`)
#' for a country/period from the persisted operation log, without rerunning
#' [eri_split_cmr()] or needing to have kept its return value in your R
#' session. [eri_split_cmr()] records the full plan in its op-log on every
#' successful run; this reads the most recent one back.
#'
#' "Most recent" assumes a re-split for the same country/period supersedes the
#' one before it with an equal-or-larger set of measures (the normal case: a
#' corrected workbook re-uploaded whole). If a later run split a workbook with
#' *fewer* routable sheets than an earlier one for the same period, only the
#' narrower, newer set is returned -- the earlier run's other measures won't
#' appear here (or in [eri_approve_cmr()]'s task list) even though they were
#' routed. Not expected in normal use; worth knowing if periods get re-split
#' from partial/corrective files rather than a full re-upload.
#'
#' @param country `str` Country code (e.g. `"sdn"`).
#' @param period `str` Reporting period matching the run you want (e.g. `"202605"`).
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with one row per routed sheet: `sheet`, `disease`, `data_type`,
#'   `dest`, `n_rows` -- identical in shape to what [eri_split_cmr()] returns.
#' @examples
#' \dontrun{
#' plan <- eri_cmr_last_plan("sdn", "202605")
#' }
#' @family CMR pipeline functions
#' @export
eri_cmr_last_plan <- function(country, period, data_con = NULL) {
  data_con <- .eri_logs_con(data_con)

  logs <- eri_logs(country, "rblf", "cmr", operation = "eri_split_cmr",
                   status = "success", include_handled = TRUE, data_con = data_con)
  logs <- logs[!is.na(logs$period) & logs$period == period, ]

  if (nrow(logs) == 0L) {
    cli::cli_abort(c(
      "No successful {.fn eri_split_cmr} run logged for {.val {country}} / {.val {period}}.",
      "i" = "Check the period, or recompute it locally instead with {.code eri_split_cmr(path, country, dry_run = TRUE)}."
    ))
  }

  log_path <- logs$log_path[[1]]  # eri_logs() returns newest first
  tmp   <- tempfile(fileext = ".yaml")
  entry <- tryCatch({
    .eri_blob_read(data_con, log_path, tmp)
    yaml::read_yaml(tmp)
  }, error = function(e) {
    cli::cli_abort("Could not read log {.path {log_path}}: {conditionMessage(e)}")
  })
  unlink(tmp)

  if (is.null(entry$plan) || length(entry$plan) == 0L) {
    cli::cli_abort(c(
      "Log {.path {log_path}} has no structured plan recorded.",
      "i" = "This run predates the structured-plan logging; recompute locally with {.code dry_run = TRUE} instead."
    ))
  }

  tibble::tibble(
    sheet       = vapply(entry$plan, function(p) p$sheet,     character(1L)),
    disease     = vapply(entry$plan, function(p) p$disease,   character(1L)),
    data_type   = vapply(entry$plan, function(p) p$data_type, character(1L)),
    dest        = vapply(entry$plan, function(p) p$dest,      character(1L)),
    n_rows      = vapply(entry$plan, function(p) p$n_rows,    integer(1L)),
    # NA for a plan logged before source_hash was added -- older entries
    # still reconstruct, just without that provenance field.
    source_hash = vapply(entry$plan, function(p) p$source_hash %||% NA_character_, character(1L))
  )
}

#' Approve every disease/measure one CMR workbook routed to, in one call
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' [eri_approve()] promotes one `(disease, data_type)` at a time, but one CMR
#' workbook fans out into many of them via [eri_split_cmr()]. This looks up
#' what got routed for `country`/`period` (via [eri_cmr_last_plan()] if `plan`
#' isn't supplied), checks every measure's DQ-flag log, and only if **none**
#' have an outstanding item -- either unresolved flags or never having been
#' DQ-checked at all for this period -- approves every measure in one call.
#'
#' If anything is outstanding, **nothing is approved**. This is the explicit
#' human-review gate for CMR data; the point is that a DA can't accidentally
#' approve past an unreviewed measure by looping blindly. Instead you get back
#' a task list: one row per measure still needing attention. Review each,
#' close it out with [eri_logs_resolve()] (passing what you did/decided via
#' its `note` argument), and re-run this function -- it re-checks from
#' scratch each time.
#'
#' **A stale flag keeps blocking until it's explicitly resolved.** This checks
#' every `dq_flags` log entry for the period, not just the most recent one: if
#' an earlier [eri_dq_log()] run had unresolved flags and a later rerun for the
#' same period came back `"clean"`, the earlier entry still blocks approval
#' until you [eri_logs_resolve()] it. This is deliberate (an unreviewed flag
#' shouldn't be silently superseded by a fresh "clean" run), but it does mean a
#' truly stale/superseded flag needs an explicit note to clear, not just a
#' clean recheck.
#'
#' **`force = TRUE` approves anyway**, for the rare case a DA needs to promote
#' data despite an outstanding measure (e.g. a genuine template quirk that
#' will never resolve cleanly, under a deadline). It requires a non-empty
#' `justification` -- no confirmation prompt here, since this scriptable core
#' has to work unattended in scripts/CI; an interactive wrapper is the right
#' place for extra human friction (e.g. "type the period to confirm"), not
#' this function. Every bypassed measure's `dq_flags` entry (when one exists)
#' is annotated `handled` via [eri_logs_resolve()] with `forced = TRUE` and a
#' note pointing back at this approval's own log -- so the open backlog stays
#' clean without pretending the flag was ever actually reviewed, and
#' [eri_audit()] renders the whole thing prominently rather than folding it in
#' as an ordinary approval.
#'
#' @param country `str` Country code (e.g. `"sdn"`).
#' @param period `str` Reporting period (e.g. `"202605"`).
#' @param plan `tibble` or `NULL` The plan from [eri_split_cmr()] /
#'   [eri_cmr_last_plan()]. `NULL` (default) looks it up via [eri_cmr_last_plan()].
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @param force `lgl` Approve even if some measures are outstanding. Default
#'   `FALSE`. Requires `justification`.
#' @param justification `chr` or `NULL` Required (non-empty) when `force = TRUE`:
#'   why this approval is going through despite what's outstanding. Recorded
#'   on the approval's own log and ignored when `force = FALSE`.
#' @returns Invisibly, a tibble: if everything was clean (or `force = TRUE`),
#'   one row per `(disease, data_type)` that got approved; if anything was
#'   outstanding and `force = FALSE`, one row per `(disease, data_type)` still
#'   needing attention (with `log_path`/`issue`) and **nothing was approved**.
#' @examples
#' \dontrun{
#' eri_approve_cmr("sdn", "202605")
#'
#' # Only if you genuinely mean to promote past an outstanding measure:
#' eri_approve_cmr("sdn", "202605", force = TRUE,
#'                  justification = "Known template quirk in RB Treatment; confirmed with country lead.")
#' }
#' @family CMR pipeline functions
#' @export
eri_approve_cmr <- function(country, period, plan = NULL, data_con = NULL,
                            force = FALSE, justification = NULL) {
  # ADR-0020: normalize once, up front -- eri_cmr_last_plan()'s lookup and
  # the hand-built log_dir below both need to agree.
  country <- .eri_normalize_geo_axis("country", country, .eri_known_countries())

  if (isTRUE(force) &&
      (is.null(justification) || length(justification) != 1L ||
       is.na(justification) || !nzchar(trimws(justification)))) {
    cli::cli_abort(c(
      "{.arg justification} must be a single non-empty string when {.code force = TRUE}.",
      "i" = "Explain why this approval should go through despite what's outstanding."
    ))
  }

  data_con <- .eri_logs_con(data_con)

  if (is.null(plan)) plan <- eri_cmr_last_plan(country, period, data_con = data_con)

  measures <- unique(plan[, c("disease", "data_type")])

  outstanding  <- list()
  dq_reviewed  <- character(0)  # log_paths that backed a clean measure -- for the approval's own audit trail
  for (i in seq_len(nrow(measures))) {
    m <- measures[i, ]
    dq_logs <- eri_logs(country, m$disease, "programmatic", m$data_type,
                        operation = "dq_flags", include_handled = TRUE,
                        data_con = data_con)
    dq_logs <- dq_logs[!is.na(dq_logs$period) & dq_logs$period == period, ]

    if (nrow(dq_logs) == 0L) {
      outstanding[[length(outstanding) + 1L]] <- tibble::tibble(
        disease = m$disease, data_type = m$data_type,
        log_path = NA_character_, issue = "never DQ-checked for this period"
      )
      next
    }
    open_flags <- dq_logs[dq_logs$status == "needs_review" & !dq_logs$handled, ]
    if (nrow(open_flags) > 0L) {
      outstanding[[length(outstanding) + 1L]] <- tibble::tibble(
        disease = m$disease, data_type = m$data_type,
        log_path = open_flags$log_path[[1]],
        issue = paste0(open_flags$n_issues[[1]], " unresolved DQ flag(s)")
      )
    } else {
      dq_reviewed <- c(dq_reviewed, dq_logs$log_path)
    }
  }
  outstanding_tbl <- if (length(outstanding) > 0L) dplyr::bind_rows(outstanding) else NULL

  if (!is.null(outstanding_tbl) && !isTRUE(force)) {
    cli::cli_bullets(c(
      "x" = "{nrow(outstanding_tbl)} measure{?s} still need{?s/} attention -- approving nothing.",
      "i" = "Review each below, close it out with {.fn eri_logs_resolve} (pass a {.arg note}), then re-run this.",
      "i" = "Or pass {.code force = TRUE} and a {.arg justification} to approve anyway."
    ))
    print(outstanding_tbl)
    return(invisible(outstanding_tbl))
  }

  if (!is.null(outstanding_tbl)) {
    cli::cli_bullets(c(
      "!" = "FORCE-APPROVING {.val {country}} / {.val {period}} despite {nrow(outstanding_tbl)} outstanding measure{?s}.",
      "i" = "Justification: {justification}"
    ))
    print(outstanding_tbl)
  }

  approved <- vector("list", nrow(measures))
  for (i in seq_len(nrow(measures))) {
    m <- measures[i, ]
    eri_approve(country, m$disease, "programmatic", period, data_type = m$data_type,
               azcontainer = data_con)
    approved[[i]] <- tibble::tibble(disease = m$disease, data_type = m$data_type)
  }
  approved_tbl <- dplyr::bind_rows(approved)

  # One combined record cross-referencing exactly which DQ reviews backed this
  # approval -- eri_approve() itself writes one op-log per measure, but none
  # of those reference the dq_flags entries that justified them. This is the
  # traceable link from "approved/processed" back to "here's what was
  # reviewed and decided, and by whom" (each dq_flags log_path carries its own
  # per-flag notes via eri_dq_flag_resolve() and its whole-entry note via
  # eri_logs_resolve()).
  trail_log <- list(
    operation  = "eri_approve_cmr",
    analyst    = .eri_analyst_id(data_con),
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(country = country, period = period),
    status     = "success",
    measures   = as.list(paste(approved_tbl$disease, approved_tbl$data_type, sep = "/")),
    dq_reviewed = as.list(dq_reviewed)
  )
  if (!is.null(outstanding_tbl)) {
    trail_log$forced        <- TRUE
    trail_log$justification <- justification
    trail_log$bypassed <- lapply(seq_len(nrow(outstanding_tbl)), function(i) {
      b <- outstanding_tbl[i, ]
      list(disease = b$disease, data_type = b$data_type, issue = b$issue,
           log_path = if (is.na(b$log_path)) NA_character_ else b$log_path)
    })
  }
  trail_path <- .eri_write_log(
    trail_log, data_con, paste(c(country, "rblf", "cmr", "logs"), collapse = "/")
  )

  # Annotate (never silently resolve) each bypassed dq_flags entry that
  # actually exists, pointing back at this approval's own log -- the open
  # backlog stays clean, but the record says exactly what happened and why,
  # never that the flag was genuinely reviewed. A "never DQ-checked" bypass
  # (no log_path) has nothing to annotate -- it's already captured in
  # trail_log$bypassed above.
  if (!is.null(outstanding_tbl)) {
    bypass_note <- paste0(
      "Bypassed by a forced eri_approve_cmr() approval",
      if (!is.null(trail_path)) {
        paste0(" (", basename(trail_path), ")")
      } else {
        " (this approval's own log could not be written -- no back-reference available)"
      },
      ": ", justification
    )
    for (lp in outstanding_tbl$log_path[!is.na(outstanding_tbl$log_path)]) {
      tryCatch(
        eri_logs_resolve(lp, note = bypass_note, forced = TRUE, data_con = data_con),
        error = function(e) cli::cli_alert_warning(
          "Could not annotate bypassed log {.path {lp}}: {conditionMessage(e)}"
        )
      )
    }
  }

  cli::cli_alert_success(
    if (!is.null(outstanding_tbl)) {
      "Force-approved {nrow(approved_tbl)} measure{?s} for {.val {country}} / {.val {period}}."
    } else {
      "Approved {nrow(approved_tbl)} measure{?s} for {.val {country}} / {.val {period}}."
    }
  )
  if (is.null(trail_path)) {
    cli::cli_bullets(c(
      "x" = "The measures above ARE approved, but the {.val dq_reviewed} audit-trail record could not be written",
      "i" = "(see the Azure write warning above). The per-measure {.fn eri_approve} logs still exist; only this combined cross-reference is missing."
    ))
  }
  .eri_task_epilogue("eri_approve_cmr")
  invisible(approved_tbl)
}

#' Run and log DQ checks for a whole CMR workbook, one combined report
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' [eri_split_cmr()] fans one CMR workbook out into many disease/measure
#' datasets; checking each with [run_dq_checks()] one at a time means reading
#' twelve separate `dq_report()` printouts. This runs DQ checks for every
#' measure in `plan` (looked up via [eri_cmr_last_plan()] if not supplied),
#' logs each measure's flags with [eri_dq_log()] as usual, and returns **one**
#' tibble spanning every flag from every measure -- sortable/filterable in
#' one place instead of twelve.
#'
#' Each row's `flag_id` is what you pass to [eri_dq_flag_resolve()] to triage
#' that specific issue (`"not_important"`, `"fixed"`, or `"noted"`) before
#' closing out the whole measure with [eri_logs_resolve()].
#'
#' @param country `str` Country code (e.g. `"sdn"`).
#' @param period `str` Reporting period (e.g. `"202605"`).
#' @param plan `tibble` or `NULL` The plan from [eri_split_cmr()] /
#'   [eri_cmr_last_plan()]. `NULL` (default) looks it up via [eri_cmr_last_plan()].
#' @param supersede `logical` The normal review loop is run, fix, re-run --
#'   each run logs a fresh entry, and [eri_approve_cmr()] blocks on *every*
#'   unresolved historical entry for a period, not just the newest. Default
#'   `TRUE` auto-resolves prior open entries for the same measure/period with
#'   a "superseded by a newer run" note when this run logs a new one, so
#'   re-running doesn't pile up entries you have to close by hand. Set `FALSE`
#'   to keep every run's entry open until you resolve it yourself.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with one row per flag across every measure: `sheet`,
#'   `disease`, `data_type`, `log_path`, `flag_id`, `row` (the flag's index
#'   into the checked data, not the workbook), `excel_row` (the real row in
#'   the original Excel sheet -- use this one when telling a DA what to go
#'   fix), `column`, `value`, `issue`, `status` (all `"open"` on a fresh run),
#'   `note` (`NA` on a fresh run -- only set once a flag has been triaged via
#'   [eri_dq_flag_resolve()] and this function is re-run). Zero rows if every
#'   measure is clean.
#' @examples
#' \dontrun{
#' flags <- eri_cmr_dq_report("sdn", "202605")
#' flags[flags$status == "open", ]
#' eri_dq_flag_resolve(flags$flag_id[1], "fixed", note = "corrected upstream")
#' }
#' @family CMR pipeline functions
#' @export
eri_cmr_dq_report <- function(country, period, plan = NULL, supersede = TRUE, data_con = NULL) {
  data_con <- .eri_logs_con(data_con)

  if (is.null(plan)) plan <- eri_cmr_last_plan(country, period, data_con = data_con)

  rows <- list()
  for (i in seq_len(nrow(plan))) {
    p <- plan[i, ]
    staged <- tryCatch(
      eri_read(p$dest, azcontainer = data_con),
      error = function(e) {
        cli::cli_alert_warning("{.val {p$sheet}}: could not read {.path {p$dest}}: {conditionMessage(e)}")
        NULL
      }
    )
    if (is.null(staged)) next

    schema <- tryCatch(
      load_dq_schema(country, p$disease, "programmatic", p$data_type, azcontainer = data_con),
      error = function(e) {
        cli::cli_alert_warning("{.val {p$sheet}}: no DQ schema for {p$disease}/{p$data_type}: {conditionMessage(e)}")
        NULL
      }
    )
    if (is.null(schema)) next

    result       <- run_dq_checks(staged, schema)
    p_source_hash <- if ("source_hash" %in% names(plan)) p$source_hash else NULL
    written <- .eri_dq_log_write(result, country, p$disease, "programmatic", p$data_type, period, data_con,
                                 source_hash = p_source_hash)

    if (isTRUE(supersede)) {
      prior <- tryCatch(
        eri_logs(country, p$disease, "programmatic", p$data_type,
                operation = "dq_flags", status = "needs_review",
                include_handled = FALSE, data_con = data_con),
        error = function(e) NULL
      )
      if (!is.null(prior) && nrow(prior) > 0L) {
        prior <- prior[!is.na(prior$period) & prior$period == period &
                       prior$log_path != written$log_path, , drop = FALSE]
        for (lp in prior$log_path) {
          eri_logs_resolve(
            lp, note = paste0("Superseded by a newer eri_cmr_dq_report() run (", written$log_path, ")."),
            data_con = data_con
          )
        }
      }
    }

    if (written$n_flags == 0L) next
    has_excel_row <- "excel_row" %in% names(result$data)
    for (f in written$flags) {
      # f$row indexes into result$data (post drop-missing-year etc.), not the
      # original workbook -- excel_row travels as a column through those row
      # drops, so this is the DA's real "go fix cell in row N" reference, not
      # a post-filtering position that may not match the Excel sheet at all.
      excel_row_val <- if (has_excel_row && !is.na(f$row) && f$row >= 1L && f$row <= nrow(result$data)) {
        result$data$excel_row[f$row]
      } else NA_integer_
      rows[[length(rows) + 1L]] <- tibble::tibble(
        sheet = p$sheet, disease = p$disease, data_type = p$data_type,
        log_path = written$log_path, flag_id = paste0(written$log_path, "::", f$index),
        row = f$row, excel_row = excel_row_val, column = f$column, value = f$value,
        issue = f$issue, status = f$status, note = .eri_na_chr(f$note)
      )
    }
  }

  if (length(rows) == 0L) {
    cli::cli_alert_success("No DQ flags across {nrow(plan)} measure{?s} -- all clean.")
    return(tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0), note = character(0)
    ))
  }

  dplyr::bind_rows(rows)
}

#' Stage CMR monthly report files into the data/ blob
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Pulls CMR Excel files from the `projects` blob's
#' `raw/filled_templates/{country}/{period}/` folder and copies them into
#' `data/{country}/rblf/cmr/staged/`, ready for analyst review via
#' [eri_approve()].
#'
#' If `period` is `NULL`, the most recent period folder (by `YYYYMM` name) is
#' selected automatically and reported to the console. If any destination file
#' already exists in `staged/`, a warning is issued and the file is overwritten.
#'
#' @param country `str` Three-letter country code (e.g. `"uga"`, `"eth"`).
#'   Must be registered in the `"rb-expansion"` pipeline.
#' @param period `str` or `NULL` Six-digit period string matching the source
#'   folder name (e.g. `"202603"`). Default `NULL` uses the most recent period.
#' @param overwrite `logical` If `FALSE` (default), warns before overwriting an
#'   existing staged file. If `TRUE`, overwrites silently (for scripted runs).
#' @param projects_con Azure container for the `projects` blob. `NULL` connects
#'   automatically via [get_azure_storage_connection()].
#' @param data_con Azure container for the `data` blob. `NULL` connects using
#'   `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#'
#' @returns Invisibly, a character vector of the staged file paths in the `data` blob.
#' @examples
#' \dontrun{
#' eri_stage_cmr("uga", "202603")
#' eri_stage_cmr("nga")  # auto-selects most recent period
#' }
#' @family CMR pipeline functions
#' @export
eri_stage_cmr <- function(country,
                           period       = NULL,
                           overwrite    = FALSE,
                           projects_con = NULL,
                           data_con     = NULL) {
  .eri_log_session()
  # ADR-0020: normalize once, up front -- the country_map lookup below,
  # eri_data_path(), and the hand-built log_dir all need to agree.
  country <- .eri_normalize_geo_axis("country", country, .eri_known_countries())

  reg <- .eri_pipeline_registry[["rb-expansion"]]

  if (!country %in% names(reg$country_map)) {
    known <- paste(names(reg$country_map), collapse = ", ")
    cli::cli_abort(c(
      "Country {.val {country}} is not registered for CMR staging.",
      "i" = "Registered countries: {known}."
    ))
  }

  if (is.null(projects_con)) {
    projects_con <- suppressMessages(get_azure_storage_connection())
  }
  if (is.null(data_con)) {
    data_con <- suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
      )
    )
  }

  src_base <- paste(c(reg$project_folder, reg$raw_dir, country), collapse = "/")

  if (is.null(period)) {
    period_listing <- AzureStor::list_storage_files(projects_con, src_base) |>
      dplyr::as_tibble()
    period_dirs <- period_listing[period_listing$isdir, ]
    period_dirs$period_name <- basename(period_dirs$name)

    if (nrow(period_dirs) == 0) {
      cli::cli_abort(
        "No period directories found under {.path {src_base}} in the projects blob."
      )
    }

    # Most recent = lexically greatest period label. Directories are zero-padded
    # `YYYYMM` (and the lexical order also holds for ISO labels like "2024-W01"),
    # so a string `max()` is correct and robust. Use `max()` not `which.max()`:
    # which.max() coerces the labels to numeric, which is fragile (a warning, and
    # an `integer(0)` result for any non-numeric label). Assumes fixed-width,
    # zero-padded components.
    period <- max(period_dirs$period_name)
    cli::cli_alert_info("No period specified; staging most recent: {.val {period}}")
  }

  src_dir    <- paste0(src_base, "/", period)
  staged_dir <- eri_data_path(country, "rblf", "cmr", "staged")
  log_dir    <- paste(c(country, "rblf", "cmr", "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_stage_cmr",
    analyst    = .eri_analyst_id(data_con),
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(country = country, period = period),
    status     = "in_progress",
    steps      = list(),
    error      = NULL,
    files      = NULL
  )

  staged    <- character(0)
  had_error <- FALSE
  err_msg   <- NULL

  tryCatch({
    if (!AzureStor::storage_dir_exists(projects_con, src_dir)) {
      cli::cli_abort(
        "Source directory not found in projects blob: {.path {src_dir}}"
      )
    }
    op_log$steps <- .eri_log_step(op_log$steps, "check_src_dir", path = src_dir)

    all_files <- AzureStor::list_storage_files(projects_con, src_dir) |>
      dplyr::as_tibble()
    src_files <- all_files[!all_files$isdir, ]

    if (nrow(src_files) == 0) {
      cli::cli_abort("No files found in {.path {src_dir}}.")
    }
    op_log$steps <- .eri_log_step(op_log$steps, "list_src_files",
                                   files_found = nrow(src_files),
                                   filenames   = as.list(basename(src_files$name)))

    if (!AzureStor::storage_dir_exists(data_con, staged_dir)) {
      .eri_create_azure_dir(data_con, staged_dir)
      op_log$steps <- .eri_log_step(op_log$steps, "create_staged_dir",
                                     path = staged_dir)
    }

    for (src_path in src_files$name) {
      fname     <- basename(src_path)
      dest_path <- paste0(staged_dir, "/", fname)

      if (AzureStor::storage_file_exists(data_con, dest_path)) {
        if (!overwrite) {
          cli::cli_warn("Overwriting existing staged file: {.path {fname}}")
        }
        op_log$steps <- .eri_log_step(op_log$steps, "overwrite",
                                       status = "warning", file = dest_path)
      }

      tmp <- tempfile()
      .eri_blob_read(projects_con, src_path, tmp)
      file_hash <- unname(tools::md5sum(tmp))  # identity, not security -- same convention as eri_ingest()
      .eri_blob_write(data_con, tmp, dest_path)
      unlink(tmp)
      staged       <- c(staged, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "stage_file",
                                     src = src_path, dest = dest_path, source_hash = file_hash)
      .eri_say_done("Staged: {.path {fname}}")
    }

    .eri_summary("Staged CMR to data blob", c(
      Files    = sprintf("%d", length(staged)),
      Location = if (length(staged)) dirname(staged[[1L]]) else "(none)"
    ))
    op_log$status <- "success"
    op_log$files  <- as.list(staged)

  }, error = function(e) {
    had_error <<- TRUE
    err_msg   <<- conditionMessage(e)
  })

  op_log$completed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (had_error) {
    op_log$status <- "error"
    op_log$error  <- err_msg
    op_log$steps  <- .eri_log_step(op_log$steps, "error_caught",
                                    status = "error", message = err_msg)
  }
  .eri_write_log(op_log, data_con, log_dir)
  if (had_error) cli::cli_abort(err_msg, call = NULL)
  invisible(staged)
}
