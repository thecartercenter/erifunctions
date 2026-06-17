# CMR - Monthly Report ingestion and schema loading

#' Load a CMR country schema
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads the bundled CMR YAML schema for a given country code. Schemas live in
#' `inst/schemas/cmr/` and define which sheets are present for that country and
#' the required field codes expected in each sheet.
#'
#' @param country `str` Three-letter country code (e.g. `"uga"`, `"eth"`).
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
    available <- tools::file_path_sans_ext(
      list.files(schema_dir, pattern = "\\.yaml$")
    )
    cli::cli_abort(c(
      "No CMR schema found for country {.val {country}}.",
      "i" = "Available: {.val {available}}"
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

  raw <- readxl::read_excel(path, sheet = actual_sheet, skip = 4,
                             col_names = TRUE, .name_repair = "minimal")

  field_cols <- names(raw)[startsWith(names(raw), "#")]

  if (length(field_cols) == 0) {
    cli::cli_abort(c(
      "No field code columns found in sheet {.val {sheet}} of {.path {basename(path)}}.",
      "i" = "Row 5 of the template should contain machine-readable codes starting with {.code #} (e.g. {.code #rbtrt_year}).",
      "i" = "Check that {.arg sheet} is correct and the template has not been modified."
    ))
  }

  df <- raw[, field_cols, drop = FALSE]

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

    period <- period_dirs$period_name[which.max(period_dirs$period_name)]
    cli::cli_alert_info("No period specified; staging most recent: {.val {period}}")
  }

  src_dir    <- paste0(src_base, "/", period)
  staged_dir <- eri_data_path(country, "rblf", "cmr", "staged")
  log_dir    <- paste(c(country, "rblf", "cmr", "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_stage_cmr",
    analyst    = Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]]),
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
      AzureStor::storage_download(projects_con, src_path, tmp, overwrite = TRUE)
      AzureStor::storage_upload(data_con, tmp, dest_path)
      unlink(tmp)
      staged       <- c(staged, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "stage_file",
                                     src = src_path, dest = dest_path)
      cli::cli_alert_success("Staged: {.path {fname}}")
    }

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
