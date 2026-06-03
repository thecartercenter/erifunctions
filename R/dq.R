# DQ - Data Quality Checks

`%||%` <- function(x, y) if (is.null(x)) y else x

#### 1) Internal state helpers ####

.dq_state <- function(data) {
  list(
    data  = tibble::as_tibble(data),
    log   = tibble::tibble(
      row             = integer(),
      column          = character(),
      original_value  = character(),
      corrected_value = character(),
      rule            = character(),
      action          = character()
    ),
    flags = tibble::tibble(
      row    = integer(),
      column = character(),
      value  = character(),
      issue  = character()
    )
  )
}

.dq_log_correction <- function(state, rows, column, original, corrected, rule) {
  state$log <- dplyr::bind_rows(
    state$log,
    tibble::tibble(
      row             = as.integer(rows),
      column          = as.character(column),
      original_value  = as.character(original),
      corrected_value = as.character(corrected),
      rule            = as.character(rule),
      action          = "corrected"
    )
  )
  state
}

.dq_log_flag <- function(state, rows, column, value, issue) {
  state$flags <- dplyr::bind_rows(
    state$flags,
    tibble::tibble(
      row    = as.integer(rows),
      column = as.character(column),
      value  = as.character(value),
      issue  = as.character(issue)
    )
  )
  state
}

#### 2) Internal DQ steps ####

.dq_remove_smart_quotes <- function(x) {
  dq_pat <- paste0("[", intToUtf8(c(0x201cL, 0x201dL)), "]")
  sq_pat <- paste0("[", intToUtf8(c(0x2018L, 0x2019L)), "]")
  x <- gsub(dq_pat, '"', x, perl = TRUE)
  x <- gsub(sq_pat, "'", x, perl = TRUE)
  x
}

.dq_try_parse_date <- function(x) {
  x <- as.character(x)
  if (is.na(x)) return(as.Date(NA))
  # Excel serial date (purely numeric)
  if (grepl("^\\d{5}$", x)) {
    return(tryCatch(as.Date(as.numeric(x), origin = "1899-12-30"), error = function(e) as.Date(NA)))
  }
  formats <- c("%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y", "%m-%d-%Y",
               "%d.%m.%Y", "%Y.%m.%d")
  for (fmt in formats) {
    result <- suppressWarnings(as.Date(x, format = fmt))
    if (!is.na(result)) return(result)
  }
  as.Date(NA)
}

.dq_preprocess <- function(state, schema) {
  data  <- state$data
  steps <- schema$preprocessing %||% character(0)

  if ("remove_smart_quotes" %in% steps) {
    char_cols <- names(data)[vapply(data, is.character, logical(1))]
    for (col in char_cols) {
      data[[col]] <- .dq_remove_smart_quotes(data[[col]])
    }
  }

  if ("strip_column_name_spaces" %in% steps) {
    colnames(data) <- gsub("[ ()]", "", colnames(data))
  }

  state$data <- data
  state
}

# Runs after alias resolution so the canonical year column name is present
.dq_drop_missing_year <- function(state, schema) {
  steps    <- schema$preprocessing %||% character(0)
  year_col <- schema$temporal$year_col %||% NULL

  if (!"drop_rows_missing_year" %in% steps) return(state)
  if (is.null(year_col) || !year_col %in% names(state$data)) return(state)

  n_before <- nrow(state$data)
  state$data <- state$data[!is.na(state$data[[year_col]]), , drop = FALSE]
  n_dropped  <- n_before - nrow(state$data)
  if (n_dropped > 0) {
    cli::cli_alert_warning("Dropped {n_dropped} row{?s} with missing {.val {year_col}}.")
  }
  state
}

.dq_resolve_aliases <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (canonical in names(cols_schema)) {
    if (canonical %in% names(data)) next
    aliases   <- cols_schema[[canonical]]$aliases %||% character(0)
    match_col <- intersect(aliases, names(data))
    if (length(match_col) > 0) {
      names(data)[names(data) == match_col[1]] <- canonical
      cli::cli_alert_info("Renamed column {.val {match_col[1]}} -> {.val {canonical}}.")
    }
  }

  state$data <- data
  state
}

.dq_check_required <- function(state, schema) {
  cols_schema <- schema$columns %||% list()
  present     <- names(state$data)

  for (canonical in names(cols_schema)) {
    if (isTRUE(cols_schema[[canonical]]$required) && !canonical %in% present) {
      state <- .dq_log_flag(
        state,
        rows   = NA_integer_,
        column = canonical,
        value  = NA_character_,
        issue  = "Required column is missing from data"
      )
      cli::cli_alert_danger("Required column {.val {canonical}} is missing.")
    }
  }
  state
}

.dq_coerce_types <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (col in names(cols_schema)) {
    if (!col %in% names(data)) next
    expected_type <- cols_schema[[col]]$type %||% "character"

    if (expected_type == "numeric") {
      raw <- data[[col]]
      if (is.character(raw)) raw <- .dq_remove_smart_quotes(raw)
      coerced <- suppressWarnings(as.numeric(raw))
      bad <- which(!is.na(raw) & is.na(coerced))
      if (length(bad) > 0) {
        state <- .dq_log_flag(state, rows = bad, column = col,
                              value = as.character(raw[bad]),
                              issue = "Could not coerce value to numeric")
      }
      data[[col]] <- coerced

    } else if (expected_type == "date") {
      raw <- data[[col]]
      if (!inherits(raw, "Date")) {
        coerced <- as.Date(vapply(as.character(raw), .dq_try_parse_date,
                                  FUN.VALUE = Sys.Date()))
        bad <- which(!is.na(raw) & is.na(coerced))
        if (length(bad) > 0) {
          state <- .dq_log_flag(state, rows = bad, column = col,
                                value = as.character(raw[bad]),
                                issue = "Could not parse as a date")
        }
        data[[col]] <- coerced
      }

    } else {
      data[[col]] <- as.character(data[[col]])
    }
  }

  state$data <- data
  state
}

.dq_check_ranges <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (col in names(cols_schema)) {
    if (!col %in% names(data)) next
    range_def <- cols_schema[[col]]$range
    if (is.null(range_def) || length(range_def) != 2) next

    vals          <- data[[col]]
    out_of_range  <- which(!is.na(vals) & (vals < range_def[1] | vals > range_def[2]))
    if (length(out_of_range) > 0) {
      state <- .dq_log_flag(
        state,
        rows   = out_of_range,
        column = col,
        value  = as.character(vals[out_of_range]),
        issue  = glue::glue("Value outside expected range [{range_def[1]}, {range_def[2]}]")
      )
    }
  }
  state
}

.dq_apply_translations <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (col in names(cols_schema)) {
    if (!col %in% names(data)) next
    translations <- cols_schema[[col]]$translations
    if (is.null(translations)) next

    vals <- data[[col]]
    for (original in names(translations)) {
      target <- translations[[original]]
      idx    <- which(vals == original)
      if (length(idx) > 0) {
        state <- .dq_log_correction(state, rows = idx, column = col,
                                    original = original, corrected = target,
                                    rule = "translation")
        vals[idx] <- target
      }
    }
    data[[col]] <- vals
  }

  state$data <- data
  state
}

.dq_apply_corrections <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (col in names(cols_schema)) {
    if (!col %in% names(data)) next
    corrections <- cols_schema[[col]]$corrections
    if (is.null(corrections)) next

    vals <- data[[col]]
    for (original in names(corrections)) {
      target <- corrections[[original]]
      idx    <- which(vals == original)
      if (length(idx) > 0) {
        state <- .dq_log_correction(state, rows = idx, column = col,
                                    original = original, corrected = target,
                                    rule = "correction")
        vals[idx] <- target
      }
    }
    data[[col]] <- vals
  }

  state$data <- data
  state
}

.dq_check_allowed_values <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (col in names(cols_schema)) {
    if (!col %in% names(data)) next
    allowed <- cols_schema[[col]]$allowed_values
    if (is.null(allowed)) next

    vals <- data[[col]]
    bad  <- which(!is.na(vals) & !vals %in% allowed)
    if (length(bad) > 0) {
      state <- .dq_log_flag(state, rows = bad, column = col,
                            value = as.character(vals[bad]),
                            issue = "Value not in allowed_values list")
    }
  }
  state
}

.dq_na_fill <- function(state, schema) {
  data        <- state$data
  cols_schema <- schema$columns %||% list()

  for (col in names(cols_schema)) {
    if (!col %in% names(data)) next
    fill_val <- cols_schema[[col]]$na_fill
    if (is.null(fill_val)) next

    na_idx <- which(is.na(data[[col]]))
    if (length(na_idx) > 0) {
      state <- .dq_log_correction(
        state,
        rows      = na_idx,
        column    = col,
        original  = NA_character_,
        corrected = as.character(fill_val),
        rule      = "na_fill"
      )
      data[[col]][na_idx] <- fill_val
    }
  }

  state$data <- data
  state
}

.dq_temporal_checks <- function(state, schema) {
  data     <- state$data
  temporal <- schema$temporal %||% list()

  date_col  <- temporal$date_col %||% NULL
  cross_col <- temporal$cross_check_year_col %||% NULL

  if (!is.null(date_col) && !is.null(cross_col) &&
      date_col %in% names(data) && cross_col %in% names(data)) {
    date_years <- as.integer(format(data[[date_col]], "%Y"))
    reported   <- suppressWarnings(as.integer(data[[cross_col]]))
    mismatch   <- which(!is.na(date_years) & !is.na(reported) & date_years != reported)
    if (length(mismatch) > 0) {
      state <- .dq_log_flag(
        state,
        rows   = mismatch,
        column = date_col,
        value  = as.character(data[[date_col]][mismatch]),
        issue  = glue::glue("Year extracted from {date_col} does not match {cross_col}")
      )
    }
  }

  state
}

.dq_derive_columns <- function(data, schema) {
  derived <- schema$derived %||% list()
  for (col_name in names(derived)) {
    formula_str <- derived[[col_name]]$formula %||% NULL
    if (is.null(formula_str)) next
    tryCatch(
      data[[col_name]] <- with(data, eval(parse(text = formula_str))),
      error = function(e) {
        cli::cli_alert_warning("Could not compute derived column {.val {col_name}}: {e$message}")
      }
    )
  }
  data
}

.dq_aggregate_checks <- function(state, schema) {
  data    <- state$data
  derived <- schema$derived %||% list()

  for (col_name in names(derived)) {
    if (!col_name %in% names(data)) next
    formula_str <- derived[[col_name]]$formula %||% NULL
    if (is.null(formula_str)) next
    tryCatch({
      expected <- with(data, eval(parse(text = formula_str)))
      actual   <- data[[col_name]]
      mismatch <- which(!is.na(actual) & !is.na(expected) & abs(actual - expected) > 0.001)
      if (length(mismatch) > 0) {
        state <- .dq_log_flag(
          state,
          rows   = mismatch,
          column = col_name,
          value  = as.character(actual[mismatch]),
          issue  = glue::glue("Derived column does not match formula: {formula_str}")
        )
      }
    }, error = function(e) NULL)
  }
  state
}

#### 3) Public API ####

#' Load a DQ schema
#'
#' Loads a disease surveillance data quality schema from Azure blob storage, or
#' falls back to the schema bundled with the package.
#'
#' Schema files are YAML documents stored at `schemas/<country>_<disease>.yaml`
#' in the `data` Azure container (or in `inst/schemas/` locally).
#' The container name is read from `ERIFUNCTIONS_DATA_STORAGE_NAME` (default `"data"`).
#'
#' @param country `str` Country identifier matching the schema filename prefix
#'   (e.g., `"dominican_republic"`, `"haiti"`).
#' @param disease `str` Disease name matching the schema filename suffix
#'   (e.g., `"malaria"`).
#' @param azcontainer Azure container object from [get_azure_storage_connection()].
#'   Defaults to the `data` container via `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#'   Pass `NULL` to use only the locally bundled schema files.
#' @returns A named list representing the parsed YAML schema.
#' @examples
#' \dontrun{
#' schema <- load_dq_schema("dominican_republic", "malaria")
#' schema <- load_dq_schema("haiti", "malaria")
#' }
#' @export
load_dq_schema <- function(
    country,
    disease,
    azcontainer = suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
      )
    )) {
  schema_path <- paste0("schemas/", country, "_", disease, ".yaml")

  if (!is.null(azcontainer)) {
    result <- tryCatch({
      withr::with_tempfile("tmp", fileext = ".yaml", code = {
        AzureStor::download_blob(azcontainer, schema_path, tmp, overwrite = TRUE)
        yaml::read_yaml(tmp)
      })
    }, error = function(e) {
      cli::cli_alert_warning(
        "Could not load schema from Azure ({e$message}). Falling back to local."
      )
      NULL
    })
    if (!is.null(result)) return(result)
  }

  local_path <- system.file(schema_path, package = "erifunctions")
  if (!nzchar(local_path)) {
    cli::cli_abort("No schema found for {.val {country}}/{.val {disease}}.")
  }
  yaml::read_yaml(local_path)
}

#' Run data quality checks on surveillance data
#'
#' Applies a sequence of automated DQ checks defined by a schema: preprocessing
#' (smart-quote removal, column-name stripping, empty-row dropping), column
#' alias resolution, required-column validation, type coercion, range checks,
#' categorical translations and corrections, NA filling for count columns,
#' temporal cross-checks, derived column computation, and aggregate consistency
#' checks. Additional analyst-supplied checks can be appended via
#' `custom_checks`.
#'
#' @param data `data.frame` or `tibble` of raw surveillance data.
#' @param schema Named list returned by [load_dq_schema()].
#' @param custom_checks `list` of functions, each with signature
#'   `function(data, log, flags)` returning a named list with those same three
#'   elements. Applied in order after all automated checks.
#' @returns A named list with three elements:
#'   - `$data`: cleaned tibble with corrections applied and derived columns added
#'   - `$log`: tibble of automated corrections (columns: `row`, `column`,
#'     `original_value`, `corrected_value`, `rule`, `action`)
#'   - `$flags`: tibble of issues requiring analyst review (columns: `row`,
#'     `column`, `value`, `issue`)
#' @examples
#' \dontrun{
#' schema <- load_dq_schema("dominican_republic", "malaria")
#' result <- run_dq_checks(raw_data, schema)
#' dq_report(result)
#' }
#' @export
run_dq_checks <- function(data, schema, custom_checks = list()) {
  state <- .dq_state(data)

  state <- .dq_preprocess(state, schema)       # smart-quote removal, column name stripping
  state <- .dq_resolve_aliases(state, schema)  # rename aliases to canonical names
  state <- .dq_drop_missing_year(state, schema) # drop empty rows (needs canonical year column)
  state <- .dq_check_required(state, schema)
  state <- .dq_coerce_types(state, schema)
  state <- .dq_check_ranges(state, schema)
  state <- .dq_apply_translations(state, schema)
  state <- .dq_apply_corrections(state, schema)
  state <- .dq_check_allowed_values(state, schema)
  state <- .dq_na_fill(state, schema)
  state <- .dq_temporal_checks(state, schema)

  state$data <- .dq_derive_columns(state$data, schema)
  state      <- .dq_aggregate_checks(state, schema)

  for (fn in custom_checks) {
    result      <- fn(data = state$data, log = state$log, flags = state$flags)
    state$data  <- result$data
    state$log   <- result$log
    state$flags <- result$flags
  }

  n_corrections <- nrow(state$log)
  n_flags       <- nrow(state$flags)
  cli::cli_alert_success(
    "DQ checks complete: {n_corrections} correction{?s}, {n_flags} flag{?s} for review."
  )

  list(data = state$data, log = state$log, flags = state$flags)
}

#' Print a formatted DQ summary report
#'
#' Prints an analyst-readable summary of [run_dq_checks()] output, including
#' data shape, corrections applied by column, and flagged issues grouped by
#' type.
#'
#' @param result Named list returned by [run_dq_checks()].
#' @returns Invisibly returns `result`.
#' @examples
#' \dontrun{
#' result <- run_dq_checks(raw_data, schema)
#' dq_report(result)
#' }
#' @export
dq_report <- function(result) {
  data  <- result$data
  log   <- result$log
  flags <- result$flags

  cli::cli_h1("Data Quality Report")
  cli::cli_text("{.strong Shape:} {nrow(data)} rows x {ncol(data)} columns")
  cli::cli_text("")

  cli::cli_h2("Automated Corrections ({nrow(log)} total)")
  if (nrow(log) == 0) {
    cli::cli_alert_success("No corrections applied.")
  } else {
    by_col <- sort(table(log$column), decreasing = TRUE)
    for (col in names(by_col)) {
      n     <- by_col[[col]]
      rules <- paste(unique(log$rule[log$column == col]), collapse = ", ")
      cli::cli_bullets(c("*" = "{.val {col}}: {n} correction{?s} ({rules})"))
    }
  }
  cli::cli_text("")

  cli::cli_h2("Flags Requiring Review ({nrow(flags)} total)")
  if (nrow(flags) == 0) {
    cli::cli_alert_success("No flags.")
  } else {
    missing_cols <- flags[is.na(flags$row), ]
    if (nrow(missing_cols) > 0) {
      cli::cli_alert_danger(
        "Missing required columns: {paste(missing_cols$column, collapse = ', ')}"
      )
    }
    row_flags <- flags[!is.na(flags$row), ]
    if (nrow(row_flags) > 0) {
      by_issue <- sort(table(row_flags$issue), decreasing = TRUE)
      for (issue in names(by_issue)) {
        n    <- by_issue[[issue]]
        cols <- paste(unique(row_flags$column[row_flags$issue == issue]), collapse = ", ")
        cli::cli_bullets(c("!" = "{issue}: {n} row{?s} [{cols}]"))
      }
    }
  }

  invisible(result)
}
