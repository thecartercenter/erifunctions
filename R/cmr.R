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
#' @returns A tibble with field-code column names and data from row 6 onward.
#'   All-NA spacer rows are dropped. If `country` is supplied it is prepended
#'   as a `country` column.
#' @examples
#' \dontrun{
#' # English template — sheet name directly
#' df <- eri_ingest_cmr("data/uga_2024_01.xlsx", sheet = "RB Treatment", country = "uga")
#' # French template — canonical slug resolved via schema
#' df <- eri_ingest_cmr("data/tcd_2024_01.xlsx", sheet = "rb_treatment", country = "tcd")
#' }
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
      "Sheet {.val {actual_sheet}} has duplicate field code{?s} in row 5 (a template defect): ",
      "{.val {unique(field_cols[dup])}}. Kept both columns; the later one is suffixed. ",
      "Flag this to whoever maintains the CMR template."
    ))
    field_cols <- make.unique(field_cols, sep = "__")
  }

  df <- raw[, field_pos, drop = FALSE]
  names(df) <- field_cols

  all_na <- apply(df, 1, function(r) all(is.na(r)))
  df <- tibble::as_tibble(df[!all_na, , drop = FALSE])

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
#' @param path `str` Local path to the CMR Excel file.
#' @param country `str` Three-letter country code (e.g. `"uga"`); resolves the
#'   CMR schema via [load_cmr_schema()].
#' @param data_con Azure container for the `data` blob. `NULL` connects using
#'   `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#' @param overwrite `logical` If `FALSE` (default), warns before overwriting an
#'   existing staged file.
#' @param dry_run `logical` If `TRUE`, returns the routing plan and writes
#'   nothing. Default `FALSE`.
#' @param mirror_pipeline `str` or `NULL` Registered pipeline name (e.g.
#'   `"rb-expansion"`) whose legacy raw-drop location `path` should also be
#'   uploaded to. Default `NULL` (no mirror; sandbox-safe).
#' @param period `str` or `NULL` Reporting period (e.g. `"202605"`) for the
#'   mirror upload. `NULL` (default) parses a leading `YYYYMM_` from
#'   `basename(path)`; required if that can't be parsed.
#' @param projects_con Azure container for the `projects` blob; used only when
#'   `mirror_pipeline` is set. If `NULL`, connects automatically.
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
#' }
#' @export
eri_split_cmr <- function(path, country, data_con = NULL,
                          overwrite = FALSE, dry_run = FALSE,
                          mirror_pipeline = NULL, period = NULL,
                          projects_con = NULL) {
  if (!dry_run) .eri_log_session()
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
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
      detected <- regmatches(basename(path), regexpr("^\\d{6}(?=_)", basename(path), perl = TRUE))
      if (length(detected) == 0L) {
        cli::cli_abort(c(
          "Could not parse a {.val YYYYMM} period from {.path {basename(path)}}.",
          "i" = "Pass {.arg period} explicitly (e.g. {.code period = \"202605\"})."
        ))
      }
      period <- detected
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

  plan    <- list()
  skipped <- character(0)
  for (sheet_name in names(routable)) {
    spec <- routable[[sheet_name]]
    if (!sheet_name %in% available) {
      skipped <- c(skipped, sheet_name)
      next
    }
    df       <- eri_ingest_cmr(path, sheet = sheet_name, country = country)
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
    sheet     = vapply(plan, function(p) p$sheet,     character(1L)),
    disease   = vapply(plan, function(p) p$disease,   character(1L)),
    data_type = vapply(plan, function(p) p$data_type, character(1L)),
    dest      = vapply(plan, function(p) p$dest,      character(1L)),
    n_rows    = vapply(plan, function(p) p$n_rows,    integer(1L))
  )

  if (dry_run) {
    cli::cli_inform(c("i" = "Dry run -- nothing written. Routing plan:"))
    for (p in plan) {
      cli::cli_inform("  {.val {p$sheet}} -> {.path {p$dest}} ({p$n_rows} row{?s})")
    }
    if (!is.null(mirror)) {
      mirror_dest <- paste(c(mirror$reg$project_folder, mirror$reg$raw_dir,
                              mirror$subfolder, mirror$period, basename(path)), collapse = "/")
      cli::cli_inform("  Would also mirror raw file -> {.path {mirror_dest}}")
    }
    return(invisible(plan_tbl))
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
    parameters = list(country = country, path = path),
    status     = "in_progress", steps = list(), error = NULL, files = NULL
  )

  written   <- character(0)
  had_error <- FALSE
  err_msg   <- NULL

  tryCatch({
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
      mirror_dest <- paste0(mirror_dir, "/", basename(path))
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

  invisible(plan_tbl)
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
#' @export
eri_stage_cmr <- function(country,
                           period       = NULL,
                           overwrite    = FALSE,
                           projects_con = NULL,
                           data_con     = NULL) {
  .eri_log_session()

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

  src_base <- paste0(reg$project_folder, "/raw/filled_templates/", country)

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
      .eri_blob_write(data_con, tmp, dest_path)
      unlink(tmp)
      staged       <- c(staged, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "stage_file",
                                     src = src_path, dest = dest_path)
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
