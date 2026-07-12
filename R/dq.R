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

#### 3) Anomaly detection ####

#' Flag rows with unusual period-over-period percent change
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Computes period-over-period percent change for a numeric column and flags
#' rows whose absolute change exceeds `threshold`. Works on a plain tibble or a
#' `dq_result` object returned by [run_dq_checks()], enabling chaining:
#'
#' ```r
#' run_dq_checks(data, schema) |>
#'   add_anomaly_pct_change("n_cases", "EpiWeek", group_cols = "Province_Residence")
#' ```
#'
#' When passed a `dq_result`, anomaly rows are appended to `$flags` and the
#' percent-change columns are added to `$data`.
#'
#' @param data A tibble or `dq_result` object.
#' @param value_col `str` Name of the numeric column to check.
#' @param period_col `str` Name of the column that defines time order within
#'   each group (e.g. `"EpiWeek"`, `"month"`).
#' @param threshold `num` Absolute percent change threshold (as a proportion).
#'   Default `0.5` flags changes greater than 50%.
#' @param group_cols `chr` vector of column names to group by before computing
#'   change (e.g. `c("Province_Residence", "disease")`). Default `NULL` treats
#'   the whole dataset as one group.
#' @param year_col `str` or `NULL` When `period_col` resets each year
#'   (e.g. `"EpiWeek"` 1–53), supply the year column so ordering is correct
#'   across year boundaries. Default `NULL`.
#'
#' @returns The input object with two columns added to the data:
#'   `pct_change_{value_col}` (numeric) and `anomaly_pct_change_{value_col}`
#'   (logical). If the input is a `dq_result`, flagged rows are also appended
#'   to `$flags`.
#' @examples
#' \dontrun{
#' agg <- dplyr::count(raw_dr, Year, EpiWeek, Province_Residence, name = "n_cases")
#' agg_flagged <- add_anomaly_pct_change(agg, "n_cases", "EpiWeek",
#'                                        group_cols = "Province_Residence",
#'                                        year_col   = "Year")
#' }
#' @export
add_anomaly_pct_change <- function(data, value_col, period_col,
                                    threshold  = 0.5,
                                    group_cols = NULL,
                                    year_col   = NULL) {
  is_dq <- inherits(data, "dq_result")
  df    <- if (is_dq) data$data else tibble::as_tibble(data)

  if (!value_col %in% names(df)) {
    cli::cli_abort("{.arg value_col} {.val {value_col}} not found in data.")
  }
  if (!period_col %in% names(df)) {
    cli::cli_abort("{.arg period_col} {.val {period_col}} not found in data.")
  }

  # Build ordering key: combine year + period when year_col supplied
  if (!is.null(year_col) && year_col %in% names(df)) {
    df$.eri_order <- df[[year_col]] * 1000 + df[[period_col]]
  } else {
    df$.eri_order <- df[[period_col]]
  }

  sort_cols <- c(group_cols, ".eri_order")

  df <- df |>
    dplyr::arrange(dplyr::across(dplyr::all_of(sort_cols))) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols %||% character(0)))) |>
    dplyr::mutate(
      .eri_lag = dplyr::lag(.data[[value_col]]),
      .eri_pct = dplyr::if_else(
        is.na(.eri_lag) | .eri_lag == 0,
        NA_real_,
        (.data[[value_col]] - .eri_lag) / .eri_lag
      )
    ) |>
    dplyr::ungroup()

  pct_col  <- paste0("pct_change_",         value_col)
  flag_col <- paste0("anomaly_pct_change_", value_col)

  df[[pct_col]]  <- df$.eri_pct
  df[[flag_col]] <- !is.na(df$.eri_pct) & abs(df$.eri_pct) > threshold
  df$.eri_order  <- NULL
  df$.eri_lag    <- NULL
  df$.eri_pct    <- NULL

  n_flagged <- sum(df[[flag_col]], na.rm = TRUE)
  if (n_flagged > 0) {
    cli::cli_alert_warning(
      "{n_flagged} row{?s} flagged for % change anomaly in {.val {value_col}} (threshold: {threshold * 100}%)."
    )
  } else {
    cli::cli_alert_success("No % change anomalies detected in {.val {value_col}}.")
  }

  if (is_dq) {
    flagged_idx <- which(df[[flag_col]])
    if (length(flagged_idx) > 0) {
      pct_vals <- round(df[[pct_col]][flagged_idx] * 100, 1)
      data$flags <- dplyr::bind_rows(
        data$flags,
        tibble::tibble(
          row    = flagged_idx,
          column = value_col,
          value  = as.character(df[[value_col]][flagged_idx]),
          issue  = paste0("% change anomaly (", pct_vals, "%): exceeds threshold ", threshold * 100, "%")
        )
      )
    }
    data$data <- df
    return(invisible(data))
  }

  df
}

#' Flag missing time periods in surveillance data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Identifies gaps in a time series by inferring the full expected sequence of
#' periods between the observed minimum and maximum, then returning rows for any
#' missing periods. Works on a plain tibble or a `dq_result` object.
#'
#' Supports two period types:
#' - `"week"` — expects contiguous integers 1–53 within each year. A gap at the
#'   year boundary (week 52/53 → week 1 of the next year) is handled correctly.
#' - `"month"` — expects contiguous integers 1–12 within each year.
#'
#' @param data A tibble or `dq_result` object.
#' @param period_col `str` Column containing the period value (integer week 1–53
#'   or month 1–12).
#' @param period_type `str` One of `"week"` or `"month"`.
#' @param group_cols `chr` vector of columns to check for gaps within each group
#'   (e.g. `c("Province_Residence")`). Default `NULL` checks the full dataset.
#' @param year_col `str` or `NULL` Column containing the year. Required when
#'   `period_type = "week"` or `"month"` to detect cross-year gaps.
#'
#' @returns A tibble of missing periods with columns `year` (if `year_col`
#'   supplied), `period`, any `group_cols`, and `issue = "structural_gap"`. If
#'   the input is a `dq_result`, missing-period rows are also appended to
#'   `$flags` (with `row = NA`). Returns an empty tibble when no gaps are found.
#' @examples
#' \dontrun{
#' gaps <- add_anomaly_gaps(agg_data, "EpiWeek", "week",
#'                           group_cols = "Province_Residence", year_col = "Year")
#' }
#' @export
add_anomaly_gaps <- function(data, period_col, period_type = c("week", "month"),
                              group_cols = NULL, year_col = NULL) {
  period_type <- match.arg(period_type)
  is_dq       <- inherits(data, "dq_result")
  df          <- if (is_dq) data$data else tibble::as_tibble(data)

  if (!period_col %in% names(df)) {
    cli::cli_abort("{.arg period_col} {.val {period_col}} not found in data.")
  }

  max_period <- if (period_type == "week") 53L else 12L
  all_cols   <- c(group_cols %||% character(0), year_col %||% character(0), period_col)
  grp_cols   <- c(group_cols %||% character(0), year_col %||% character(0))

  # Get distinct observed combinations
  observed <- df |>
    dplyr::select(dplyr::all_of(all_cols)) |>
    dplyr::distinct()

  if (length(grp_cols) == 0) {
    # No grouping — just check overall range
    all_periods <- seq(min(observed[[period_col]], na.rm = TRUE),
                       max(observed[[period_col]], na.rm = TRUE))
    missing_periods <- setdiff(all_periods, observed[[period_col]])
    gaps <- tibble::tibble(period = missing_periods, issue = "structural_gap")
    names(gaps)[1] <- period_col
  } else {
    # Group-wise gap detection
    gaps <- observed |>
      dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
      dplyr::summarise(
        .present = list(sort(unique(.data[[period_col]]))),
        .groups  = "drop"
      ) |>
      dplyr::mutate(
        .expected = purrr::map(.present, function(p) {
          if (!is.null(year_col)) {
            seq(min(p), max(p))
          } else {
            seq(min(p), max(p))
          }
        }),
        .missing  = purrr::map2(.expected, .present, setdiff)
      ) |>
      dplyr::filter(purrr::map_int(.missing, length) > 0) |>
      tidyr::unnest(cols = ".missing") |>
      dplyr::rename_with(~ period_col, ".missing") |>
      dplyr::select(dplyr::all_of(c(grp_cols, period_col))) |>
      dplyr::mutate(issue = "structural_gap")
    gaps$.expected <- NULL
    gaps$.present  <- NULL
  }

  n_gaps <- nrow(gaps)
  if (n_gaps > 0) {
    cli::cli_alert_warning(
      "{n_gaps} missing period{?s} detected in {.val {period_col}}."
    )
  } else {
    cli::cli_alert_success("No structural gaps detected in {.val {period_col}}.")
  }

  if (is_dq && n_gaps > 0) {
    flag_rows <- tibble::tibble(
      row    = NA_integer_,
      column = period_col,
      value  = as.character(gaps[[period_col]]),
      issue  = paste0("structural_gap: missing period ", gaps[[period_col]])
    )
    data$flags <- dplyr::bind_rows(data$flags, flag_rows)
    return(invisible(data))
  }
  if (is_dq) return(invisible(data))

  gaps
}

#' Flag cross-field consistency violations defined in a schema
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Evaluates named consistency rules from the schema's `consistency` block and
#' flags rows where a rule is violated. Each rule specifies a `lhs` column, a
#' comparison `op`, and either a `rhs` column or a `rhs_value` constant.
#'
#' Schema format (add a `consistency:` block to any YAML schema):
#' ```yaml
#' consistency:
#'   positives_le_tested:
#'     lhs: NumMicroPos
#'     op: "<="
#'     rhs: NumTestedMicro
#'     message: "Positive cases exceed tested"
#'   age_non_negative:
#'     lhs: Age
#'     op: ">="
#'     rhs_value: 0
#'     message: "Age is negative"
#' ```
#' Supported operators: `<=`, `>=`, `==`, `<`, `>`, `!=`.
#' Missing values (`NA`) in either operand skip the check for that row.
#'
#' Works on a plain tibble (returns a tibble of violations) or a `dq_result`
#' (appends violations to `$flags`).
#'
#' @param data A tibble or `dq_result` object.
#' @param schema Named list from [load_dq_schema()].
#'
#' @returns A tibble of violations with columns `row`, `column`, `value`, and
#'   `issue` (includes the rule name and message). If the input is a `dq_result`,
#'   violations are appended to `$flags` and the updated `dq_result` is returned.
#'   Returns an empty tibble when all rules pass.
#' @examples
#' \dontrun{
#' schema <- load_dq_schema("haiti", "malaria")
#' run_dq_checks(data, schema) |> add_anomaly_consistency(schema)
#' }
#' @export
add_anomaly_consistency <- function(data, schema) {
  is_dq <- inherits(data, "dq_result")
  df    <- if (is_dq) data$data else tibble::as_tibble(data)

  rules <- schema$consistency %||% list()
  if (length(rules) == 0) {
    cli::cli_alert_info("No consistency rules defined in schema.")
    if (is_dq) return(invisible(data))
    return(tibble::tibble(row    = integer(), column = character(),
                          value  = character(), issue  = character()))
  }

  all_flags <- tibble::tibble(row    = integer(), column = character(),
                               value  = character(), issue  = character())

  for (rule_name in names(rules)) {
    rule <- rules[[rule_name]]
    lhs  <- rule$lhs
    op   <- rule$op %||% "=="

    if (is.null(lhs) || !lhs %in% names(df)) {
      cli::cli_alert_warning(
        "Consistency rule {.val {rule_name}}: column {.val {lhs}} not found, skipping."
      )
      next
    }

    rhs_vals <- if (!is.null(rule$rhs) && rule$rhs %in% names(df)) {
      df[[rule$rhs]]
    } else if (!is.null(rule$rhs_value)) {
      rule$rhs_value
    } else {
      cli::cli_alert_warning(
        "Consistency rule {.val {rule_name}}: no valid {.arg rhs} or {.arg rhs_value}, skipping."
      )
      next
    }

    lhs_vals   <- df[[lhs]]
    applicable <- !is.na(lhs_vals) & !is.na(rhs_vals)

    ok <- switch(op,
      "<=" = lhs_vals <= rhs_vals,
      ">=" = lhs_vals >= rhs_vals,
      "==" = lhs_vals == rhs_vals,
      "<"  = lhs_vals <  rhs_vals,
      ">"  = lhs_vals >  rhs_vals,
      "!=" = lhs_vals != rhs_vals,
      rep(TRUE, nrow(df))
    )

    violated <- which(applicable & !ok)
    if (length(violated) > 0) {
      rhs_desc <- rule$rhs %||% as.character(rule$rhs_value)
      msg      <- rule$message %||% paste0(lhs, " ", op, " ", rhs_desc)
      all_flags <- dplyr::bind_rows(
        all_flags,
        tibble::tibble(
          row    = violated,
          column = lhs,
          value  = as.character(lhs_vals[violated]),
          issue  = paste0("consistency [", rule_name, "]: ", msg)
        )
      )
      cli::cli_alert_warning(
        "{length(violated)} row{?s} violate consistency rule {.val {rule_name}}."
      )
    }
  }

  n_flags <- nrow(all_flags)
  if (n_flags == 0) cli::cli_alert_success("All consistency checks passed.")

  if (is_dq) {
    data$flags <- dplyr::bind_rows(data$flags, all_flags)
    return(invisible(data))
  }
  all_flags
}

#' Validate admin unit names against a spatial reference
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Flags rows where admin unit names in the data do not appear in the canonical
#' list extracted from a reference shapefile. Checks admin1 and, optionally,
#' admin2 when a `admin2_name_field` is defined in the schema.
#'
#' The shapefile is downloaded from the Azure `data` blob at the path stored in
#' `schema$admin$admin1_spatial` (and `admin2_spatial`). If the shapefile is
#' unavailable or the `admin` block is absent from the schema, the check is
#' skipped with a warning — it never aborts the pipeline.
#'
#' @param data A tibble or `dq_result` object.
#' @param schema Named list returned by [load_dq_schema()].
#' @param azcontainer Azure container object for the `data` blob. If `NULL`
#'   (default), connects automatically using `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#'   Pass `NULL` to skip the Azure download and use only locally cached files.
#'
#' @returns For a plain tibble: a flags tibble with columns `row`, `column`,
#'   `value`, `issue` (same structure as `$flags` in a `dq_result`). For a
#'   `dq_result`: the same object with mismatches appended to `$flags`.
#' @examples
#' \dontrun{
#' schema <- load_dq_schema("dominican_republic", "malaria")
#' result <- run_dq_checks(raw_data, schema) |> add_anomaly_spatial(schema)
#' }
#' @export
add_anomaly_spatial <- function(data, schema, azcontainer = NULL) {
  is_dq <- inherits(data, "dq_result")
  df    <- if (is_dq) data$data else tibble::as_tibble(data)

  admin       <- schema$admin
  admin_match <- schema$admin_match %||% list()

  if (is.null(admin) && length(admin_match) == 0L) {
    cli::cli_alert_info("No admin block in schema; skipping spatial name check.")
    if (is_dq) return(invisible(data))
    return(.dq_empty_flags())
  }

  all_flags <- .dq_empty_flags()

  .check_level <- function(data_col, spatial_path, name_field, label) {
    if (is.null(data_col) || is.null(spatial_path) || is.null(name_field)) return()
    if (!data_col %in% names(df)) return()

    canonical <- .eri_load_spatial_names(spatial_path, name_field, azcontainer)
    if (is.null(canonical)) {
      cli::cli_warn(
        "Spatial reference unavailable for {.val {label}}; skipping admin name check."
      )
      return()
    }

    bad_rows <- which(!df[[data_col]] %in% canonical & !is.na(df[[data_col]]))
    if (length(bad_rows) == 0) {
      cli::cli_alert_success("All {label} names match spatial reference.")
      return()
    }

    cli::cli_warn("! {length(bad_rows)} row{?s} with unrecognized {label} name{?s}.")
    all_flags <<- dplyr::bind_rows(
      all_flags,
      tibble::tibble(
        row    = bad_rows,
        column = data_col,
        value  = as.character(df[[data_col]][bad_rows]),
        issue  = "unrecognized admin name"
      )
    )
  }

  if (!is.null(admin)) {
    .check_level(admin$admin1_col, admin$admin1_spatial, admin$admin1_name_field, "admin1")
    .check_level(admin$admin2_col, admin$admin2_spatial, admin$admin2_name_field, "admin2")
  }

  # --- admin_match: use eri_spatial_load() for canonical names ---
  for (entry in admin_match) {
    col     <- entry$col
    country <- entry$country
    level   <- entry$level
    label   <- entry$label %||% paste0("adm", level, " (", country, ")")

    if (is.null(col) || is.null(country) || is.null(level)) next
    if (!col %in% names(df)) {
      cli::cli_warn("admin_match: column {.val {col}} not found in data; skipping.")
      next
    }

    canonical_sf <- tryCatch(
      eri_spatial_load(country, level, data_con = azcontainer),
      error = function(e) {
        cli::cli_warn(
          "admin_match: could not load {label} boundaries ({e$message}); skipping name check."
        )
        NULL
      }
    )
    if (is.null(canonical_sf)) next

    name_col  <- paste0("adm", as.integer(level), "_name")
    canonical <- unique(as.character(
      canonical_sf[[name_col]][!is.na(canonical_sf[[name_col]])]
    ))

    bad_rows <- which(!df[[col]] %in% canonical & !is.na(df[[col]]))
    if (length(bad_rows) == 0) {
      cli::cli_alert_success("All {label} names match spatial reference.")
      next
    }

    cli::cli_warn("! {length(bad_rows)} row{?s} with unrecognized {label} name{?s}.")
    all_flags <- dplyr::bind_rows(
      all_flags,
      tibble::tibble(
        row    = bad_rows,
        column = col,
        value  = as.character(df[[col]][bad_rows]),
        issue  = paste0("admin_match: unrecognized ", label, " name")
      )
    )
  }

  if (is_dq) {
    data$flags <- dplyr::bind_rows(data$flags, all_flags)
    return(invisible(data))
  }
  all_flags
}

.dq_empty_flags <- function() {
  tibble::tibble(
    row    = integer(),
    column = character(),
    value  = character(),
    issue  = character()
  )
}

#' Download shapefile components from Azure and return canonical name vector
#'
#' Downloads the `.shp`, `.dbf`, `.shx`, and (optionally) `.prj` components
#' to a temp directory, reads with `terra::vect()`, and returns the unique
#' values of `name_field`. Returns `NULL` on any failure.
#' @keywords internal
.eri_load_spatial_names <- function(spatial_path, name_field, azcontainer) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_warn(
      "Package {.pkg terra} is required for spatial admin checks. Install it to enable this check."
    )
    return(NULL)
  }

  stem  <- tools::file_path_sans_ext(spatial_path)
  exts  <- c(".shp", ".dbf", ".shx", ".prj", ".cpg")
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  if (!is.null(azcontainer)) {
    tryCatch({
      for (ext in exts) {
        blob_path  <- paste0(stem, ext)
        local_path <- file.path(tmp_dir, paste0("ref", ext))
        tryCatch(
          .eri_blob_read(azcontainer, blob_path, local_path),
          error = function(e) NULL
        )
      }
    }, error = function(e) NULL)
  }

  shp_tmp <- file.path(tmp_dir, "ref.shp")
  if (!file.exists(shp_tmp)) return(NULL)

  tryCatch({
    v <- terra::vect(shp_tmp)
    vals <- terra::values(v)[[name_field]]
    if (is.null(vals)) return(NULL)
    unique(as.character(vals[!is.na(vals)]))
  }, error = function(e) NULL)
}

#### 4) Public API ####

# Alias map from a legacy schema stem ({country}_{key}) to its new ADR-0012
# canonical name ({country}_{disease}_{data_source}_{data_type}). Lets the legacy
# two-argument load_dq_schema() form (and old filenames) keep resolving during the
# migration.
#' @keywords internal
.eri_schema_aliases <- c(
  dr_malaria_case            = "dr_malaria_surveillance_case",
  dominican_republic_malaria = "dr_malaria_surveillance_aggregate",
  ht_malaria_case            = "ht_malaria_surveillance_case",
  haiti_malaria              = "ht_malaria_surveillance_aggregate",
  dr_lf_mda                  = "dr_lf_programmatic_treatment",
  dr_lf_tas                  = "dr_lf_research_tas",
  ht_lf_mda                  = "ht_lf_programmatic_treatment",
  ht_lf_tas                  = "ht_lf_research_tas",
  oepa_oncho_mda             = "oepa_oncho_programmatic_treatment",
  oepa_oncho_prevalence      = "oepa_oncho_research_prevalence",
  ug_rb_mda                  = "uga_oncho_programmatic_treatment",
  ug_rb_prevalence           = "uga_oncho_research_prevalence",
  schisto_mda                = "global_schisto_programmatic_treatment",
  schisto_prevalence         = "global_schisto_research_prevalence",
  sth_mda                    = "global_sth_programmatic_treatment",
  sth_prevalence             = "global_sth_research_prevalence"
)

#' @keywords internal
.eri_schema_alias <- function(stem) {
  if (stem %in% names(.eri_schema_aliases)) .eri_schema_aliases[[stem]] else stem
}

#### 4a) DQ schema local override lifecycle ####
#
# One resolver for the whole system (CLAUDE.md guardrail): local override ->
# Azure blob -> bundled. See ADR "DQ schema local overrides" for the full
# rationale; in short, a DA's local edit (via eri_dq_schema_edit()) is the
# active schema for load_dq_schema() until either eri_dq_schema_reset() or an
# upstream change retires it -- never silently discarded, never silently
# winning forever over a maintainer's fix.

#' @keywords internal
.eri_dq_schema_stem <- function(country, disease, data_source = NULL, data_type = NULL) {
  parts <- c(country, disease, data_source, data_type)
  paste(parts[nzchar(parts)], collapse = "_")
}

#' @keywords internal
.eri_dq_schema_not_found_abort <- function(stem) {
  schema_path <- paste0("schemas/", stem, ".yaml")
  schema_dir  <- system.file("schemas", package = "erifunctions")
  available   <- if (nzchar(schema_dir)) {
    sort(sub("\\.ya?ml$", "", list.files(schema_dir, pattern = "\\.ya?ml$")))
  } else {
    character()
  }
  msg <- c(
    "No schema found for {.file {basename(schema_path)}}.",
    "i" = "Identity: country/disease/data_source/data_type (ADR-0012)."
  )
  if (length(available)) {
    msg <- c(msg, "i" = paste(
      "Available bundled schemas: {.val {available}}.",
      "Call e.g. {.code load_dq_schema(\"dr\", \"malaria\", \"surveillance\", \"case\")}."
    ))
  }
  cli::cli_abort(msg)
}

# Per-user cache for schemas downloaded from Azure: refreshed on every call (so
# it always reflects the current blob), but a real file on disk rather than a
# with_tempfile() that vanishes the instant the caller returns -- callers like
# eri_dq_schema_path()/eri_dq_schema_edit() need a path that's still there
# after load_dq_schema() (or they) returns.
#' @keywords internal
.eri_dq_schema_cache_dir <- function() {
  dir <- file.path(tools::R_user_dir("erifunctions", "cache"), "schemas")
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  dir
}

# Resolves the CANONICAL upstream for a stem -- Azure blob if reachable, else
# the bundled copy -- never the local override. Returns list(path, source) or
# NULL if the schema doesn't exist anywhere.
#' @keywords internal
.eri_dq_schema_upstream <- function(stem, azcontainer) {
  schema_path <- paste0("schemas/", stem, ".yaml")
  if (!is.null(azcontainer)) {
    cache_path <- file.path(.eri_dq_schema_cache_dir(), paste0(stem, ".yaml"))
    ok <- tryCatch({
      AzureStor::download_blob(azcontainer, schema_path, cache_path, overwrite = TRUE)
      TRUE
    }, error = function(e) {
      cli::cli_alert_warning(
        "Could not load schema from Azure ({e$message}). Falling back to local."
      )
      FALSE
    })
    if (ok) return(list(path = cache_path, source = "azure"))
  }
  local_path <- system.file(schema_path, package = "erifunctions")
  if (nzchar(local_path)) return(list(path = local_path, source = "bundled"))
  NULL
}

# Per-user directory for DA-authored schema overrides (Q7 of the DQ workflow
# redesign consult): deliberately NOT the working directory, so an override
# survives switching RStudio projects and never leaks into a git repo or a
# synced folder.
#' @keywords internal
.eri_schema_override_dir <- function() {
  dir <- file.path(tools::R_user_dir("erifunctions", "data"), "schema_overrides")
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  dir
}

#' @keywords internal
.eri_schema_override_paths <- function(stem) {
  dir <- .eri_schema_override_dir()
  list(yaml = file.path(dir, paste0(stem, ".yaml")),
       meta = file.path(dir, paste0(stem, ".meta.yaml")))
}

# One place that determines whether a local override for `stem` exists and,
# if so, whether it's still valid against the current upstream. Used by every
# caller that needs this judgment (the resolver, eri_dq_schema_edit(),
# eri_dq_schema_status()) so they can't independently drift on the edge cases
# -- in particular "upstream unreachable" (Azure down AND no bundled copy for
# this stem, e.g. a newly-onboarded country/disease that only lives in Azure
# so far): that must never be treated the same as "stale", because retiring a
# DA's only local copy of a schema when nothing better is available would
# destroy the fix, not protect against a stale one.
#' @keywords internal
.eri_dq_schema_override_state <- function(stem, azcontainer) {
  paths <- .eri_schema_override_paths(stem)
  if (!file.exists(paths$yaml) || !file.exists(paths$meta)) {
    return(list(state = "none", meta = NULL, upstream = NULL, paths = paths))
  }
  meta         <- yaml::read_yaml(paths$meta)
  upstream     <- .eri_dq_schema_upstream(stem, azcontainer)
  current_hash <- if (!is.null(upstream)) unname(tools::md5sum(upstream$path)) else NA_character_

  state <- if (is.null(upstream)) {
    "unknown"
  } else if (identical(meta$base_hash, current_hash)) {
    "active"
  } else {
    "stale"
  }
  list(state = state, meta = meta, upstream = upstream, paths = paths)
}

# Renames a stale override (+ sidecar) aside so it survives as a record but
# stops taking precedence. Returns TRUE only if BOTH files were confirmed
# renamed: file.rename() FAILS (returns FALSE) rather than overwriting when
# the destination already exists (notably on Windows) -- a numeric suffix
# guards against two retirements of the same stem landing in the same UTC
# second (e.g. scripted reruns), so a silent rename failure never leaves the
# "stale" override live on disk under its original name while the caller
# believes it was retired.
#' @keywords internal
.eri_dq_schema_retire <- function(stem, paths) {
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  candidate <- function(n) {
    suffix <- if (n == 0L) stamp else paste0(stamp, "-", n)
    list(yaml = file.path(dirname(paths$yaml), paste0(stem, ".retired-", suffix, ".yaml")),
         meta = file.path(dirname(paths$meta), paste0(stem, ".retired-", suffix, ".meta.yaml")))
  }
  n    <- 0L
  dest <- candidate(n)
  while (file.exists(dest$yaml) || file.exists(dest$meta)) {
    n    <- n + 1L
    dest <- candidate(n)
  }
  ok_yaml <- file.rename(paths$yaml, dest$yaml)
  ok_meta <- file.rename(paths$meta, dest$meta)
  isTRUE(ok_yaml) && isTRUE(ok_meta)
}

# Three-tier resolution: local override -> Azure -> bundled. Never silent
# (rule 1): a live override always announces itself, including the degraded
# "can't verify freshness" case. Never silently wins forever, never silently
# discarded (rule 2): a stale override is retired (renamed aside), and if the
# retirement itself can't be completed, the override is used as-is rather than
# claiming (and acting on) a retirement that didn't really happen.
#' @keywords internal
.eri_dq_schema_resolve <- function(stem, azcontainer, allow_override = TRUE) {
  if (allow_override) {
    ov <- .eri_dq_schema_override_state(stem, azcontainer)

    if (ov$state == "active") {
      cli::cli_bullets(c(
        "i" = "Using your local schema override for {.val {stem}} (created {ov$meta$forked_at}).",
        " " = "Reset with {.fn eri_dq_schema_reset}."
      ))
      return(list(path = ov$paths$yaml, source = "local_override",
                  hash = unname(tools::md5sum(ov$paths$yaml))))
    }

    if (ov$state == "unknown") {
      cli::cli_bullets(c(
        "!" = "Could not verify your local schema override for {.val {stem}} against upstream (Azure unreachable and no bundled copy found) -- using it as-is.",
        "i" = "Its freshness relative to the canonical schema could not be confirmed this time."
      ))
      return(list(path = ov$paths$yaml, source = "local_override",
                  hash = unname(tools::md5sum(ov$paths$yaml))))
    }

    if (ov$state == "stale") {
      if (.eri_dq_schema_retire(stem, ov$paths)) {
        cli::cli_bullets(c(
          "!" = "Your local schema override for {.val {stem}} (forked {ov$meta$forked_at}) is stale -- the upstream schema changed since you forked it.",
          "i" = "Retired; using the current upstream instead.",
          "i" = "If issues re-flag that you thought you'd fixed, your changes weren't folded into the update -- re-review, or re-fork with {.fn eri_dq_schema_edit}."
        ))
        return(list(path = ov$upstream$path, source = ov$upstream$source,
                    hash = unname(tools::md5sum(ov$upstream$path))))
      }
      cli::cli_bullets(c(
        "x" = "Could not fully retire the stale local override for {.val {stem}} -- using it as-is.",
        "i" = "Check {.path {.eri_schema_override_dir()}} manually, or run {.fn eri_dq_schema_reset}."
      ))
      return(list(path = ov$paths$yaml, source = "local_override",
                  hash = unname(tools::md5sum(ov$paths$yaml))))
    }
    # ov$state == "none": no override at all -- fall through to upstream.
  }

  upstream <- .eri_dq_schema_upstream(stem, azcontainer)
  if (is.null(upstream)) .eri_dq_schema_not_found_abort(stem)
  list(path = upstream$path, source = upstream$source,
       hash = unname(tools::md5sum(upstream$path)))
}

#' Load a DQ schema
#'
#' Loads a data quality schema for a `(country, disease, data_source, data_type)`
#' identity (ADR-0012). Resolution order is **local override -> Azure blob ->
#' bundled**: a DA's own [eri_dq_schema_edit()] fork wins if one exists and
#' still matches what it was forked from; otherwise the Azure `schemas/` blob;
#' otherwise the copy bundled with the package. For `research` the `data_type`
#' (measure) is optional. When a schema is not found the error lists every
#' available bundled schema.
#'
#' The legacy two-argument form `load_dq_schema(country, key)` — where `key` was a
#' combined `{disease}_{measure}` string like `"malaria_case"` or `"lf_tas"` — still
#' resolves during the migration via an alias to the new name; local overrides
#' are not consulted for the legacy form.
#'
#' The returned schema carries `$schema_source` (`"local_override"`, `"azure"`,
#' or `"bundled"`) and `$schema_hash` (an MD5 identity hash of whichever file was
#' actually read), which flow through [run_dq_checks()] into every `dq_flags`
#' log entry -- so a DQ result produced under a modified schema is always
#' distinguishable, in the permanent log, from one produced under the canonical
#' schema.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"uga"`).
#' @param disease `str` Disease (e.g. `"malaria"`, `"lf"`). In the legacy
#'   two-argument form this slot held a combined schema key.
#' @param data_source `str` The channel: `"surveillance"`, `"programmatic"`,
#'   `"research"`. `NULL` (default) selects the legacy two-argument form.
#' @param data_type `str` The measure (e.g. `"case"`, `"treatment"`, `"tas"`);
#'   optional for `research`.
#' @param azcontainer Azure container object from [get_azure_storage_connection()].
#'   Pass `NULL` to use only the locally bundled schema files (local overrides
#'   are still consulted).
#' @returns A named list representing the parsed YAML schema, plus
#'   `$schema_source` and `$schema_hash`.
#' @examples
#' \dontrun{
#' schema <- load_dq_schema("dr", "malaria", "surveillance", "case")
#' schema <- load_dq_schema("uga", "oncho", "programmatic", "treatment")
#' }
#' @export
load_dq_schema <- function(
    country,
    disease,
    data_source = NULL,
    data_type   = NULL,
    azcontainer = suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
      )
    )) {
  if (is.null(data_source)) {
    # Legacy form: `disease` holds a combined {disease}_{measure} key; alias the
    # old stem to its new canonical name. Overrides are keyed by the modern
    # stem only, so the legacy form never resolves one -- fine, since every
    # real caller of the legacy form predates the override feature.
    stem     <- .eri_schema_alias(paste0(country, "_", disease))
    resolved <- .eri_dq_schema_resolve(stem, azcontainer, allow_override = FALSE)
  } else {
    stem     <- .eri_dq_schema_stem(country, disease, data_source, data_type)
    resolved <- .eri_dq_schema_resolve(stem, azcontainer, allow_override = TRUE)
  }

  schema               <- yaml::read_yaml(resolved$path)
  schema$schema_source <- resolved$source
  schema$schema_hash   <- resolved$hash
  schema
}

#' Resolve the local file path of the currently active DQ schema
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Runs the same three-tier resolution as [load_dq_schema()] (local override ->
#' Azure -> bundled) but returns the resolved file's local path instead of its
#' parsed content -- for opening the schema in an editor, or for a script that
#' wants to know exactly which file will be used without downloading/parsing
#' it twice.
#'
#' @inheritParams eri_dq_schema_edit
#' @returns `str` Local path to the resolved schema file: the override file
#'   itself when a live override exists, a per-user cache copy when the source
#'   is Azure, or the bundled package path when that's the fallback.
#' @examples
#' \dontrun{
#' path <- eri_dq_schema_path("atlantis", "oncho", "programmatic", "treatment")
#' file.edit(path)  # or rstudioapi::navigateToFile(path)
#' }
#' @export
eri_dq_schema_path <- function(country, disease, data_source = NULL, data_type = NULL,
                                azcontainer = suppressMessages(
                                  get_azure_storage_connection(
                                    storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
                                  ))) {
  stem     <- .eri_dq_schema_stem(country, disease, data_source, data_type)
  resolved <- .eri_dq_schema_resolve(stem, azcontainer)
  resolved$path
}

#' Fork the active DQ schema into a local, editable override
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Copies the currently resolved upstream schema (Azure, or bundled if Azure has
#' none) into a per-user override directory and records a sidecar with what it
#' was forked from. The override then becomes the active schema for
#' [load_dq_schema()] until you [eri_dq_schema_reset()] it, or until the
#' upstream schema changes -- at which point it is retired automatically (see
#' [eri_dq_schema_status()]) rather than either winning forever or vanishing
#' silently.
#'
#' This is a **local working copy**, not a submission: nothing here reaches
#' other DAs or the canonical Azure schema until a maintainer folds it in.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"uga"`).
#' @param disease `str` Disease (e.g. `"malaria"`, `"lf"`).
#' @param data_source `str` The channel: `"surveillance"`, `"programmatic"`,
#'   `"research"`.
#' @param data_type `str` The measure (e.g. `"case"`, `"treatment"`); optional
#'   for `research`.
#' @param azcontainer Azure container object from [get_azure_storage_connection()].
#'   Pass `NULL` to fork only from the bundled copy.
#' @returns Invisibly, the local path to the override file.
#' @examples
#' \dontrun{
#' path <- eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment")
#' file.edit(path)  # or rstudioapi::navigateToFile(path)
#' # ... load_dq_schema() now returns this override until eri_dq_schema_reset() ...
#' }
#' @export
eri_dq_schema_edit <- function(country, disease, data_source = NULL, data_type = NULL,
                                azcontainer = suppressMessages(
                                  get_azure_storage_connection(
                                    storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
                                  ))) {
  stem <- .eri_dq_schema_stem(country, disease, data_source, data_type)
  ov   <- .eri_dq_schema_override_state(stem, azcontainer)

  if (ov$state %in% c("active", "unknown")) {
    cli::cli_bullets(c(
      "i" = "You already have a local override for {.val {stem}} (forked {ov$meta$forked_at}).",
      " " = if (ov$state == "unknown") {
        "Could not verify it against upstream right now (unreachable) -- returning it as-is."
      } else {
        "Returning it as-is. Start over with {.fn eri_dq_schema_reset}."
      }
    ))
    return(invisible(ov$paths$yaml))
  }

  if (ov$state == "stale") {
    if (!.eri_dq_schema_retire(stem, ov$paths)) {
      cli::cli_bullets(c(
        "x" = "Could not fully retire the stale local override for {.val {stem}} -- leaving it in place.",
        "i" = "Resolve manually in {.path {.eri_schema_override_dir()}}, or run {.fn eri_dq_schema_reset} then try again."
      ))
      return(invisible(ov$paths$yaml))
    }
  }

  # ov$state is "none" (no prior override) or "stale" (just retired above) --
  # either way, fork fresh. Reuse the upstream already resolved by
  # .eri_dq_schema_override_state() when we have it, instead of a third fetch.
  upstream <- if (!is.null(ov$upstream)) ov$upstream else .eri_dq_schema_upstream(stem, azcontainer)
  if (is.null(upstream)) .eri_dq_schema_not_found_abort(stem)

  file.copy(upstream$path, ov$paths$yaml, overwrite = TRUE)
  meta <- list(
    forked_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    forked_by   = .eri_analyst_id(azcontainer),
    base_source = upstream$source,
    base_hash   = unname(tools::md5sum(upstream$path)),
    edits       = list()
  )
  yaml::write_yaml(meta, ov$paths$meta)
  cli::cli_alert_success("Forked {.val {stem}} into a local override: {.path {ov$paths$yaml}}")
  cli::cli_bullets(c(
    "i" = "This is now your active schema for {.val {stem}} until you {.fn eri_dq_schema_reset} it.",
    " " = "If the upstream schema changes, it is retired automatically -- never silently overridden or discarded."
  ))
  invisible(ov$paths$yaml)
}

#' List local DQ schema overrides
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Lists every local override created by [eri_dq_schema_edit()], with its age
#' and whether it is still active or has gone stale (the upstream schema
#' changed since it was forked -- it will be retired automatically the next
#' time [load_dq_schema()] resolves it). Read-only: unlike a real schema load,
#' checking status never itself retires a stale override.
#'
#' @param azcontainer Azure container object from [get_azure_storage_connection()].
#'   Pass `NULL` to check staleness against only the bundled copies.
#' @returns A tibble with columns `stem`, `forked_at`, `forked_by`,
#'   `base_source`, `status` (`"active"`, `"stale (will be retired on next load)"`,
#'   `"unknown (upstream unreachable)"`, or `"incomplete (missing override file)"`
#'   for a sidecar whose paired schema file is missing, e.g. from an interrupted
#'   retire). Zero rows if there are no overrides.
#' @examples
#' \dontrun{
#' eri_dq_schema_status()
#' }
#' @export
eri_dq_schema_status <- function(azcontainer = suppressMessages(
                                    get_azure_storage_connection(
                                      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
                                    ))) {
  dir   <- .eri_schema_override_dir()
  metas <- list.files(dir, pattern = "\\.meta\\.yaml$")
  # Retired sidecars carry ".retired-<timestamp>" in the name -- historical
  # record, not a candidate override, so excluded from this listing.
  metas <- sort(metas[!grepl("\\.retired-", metas)])

  empty <- tibble::tibble(stem = character(0), forked_at = character(0),
                           forked_by = character(0), base_source = character(0),
                           status = character(0))
  if (length(metas) == 0L) {
    cli::cli_alert_info("No local schema overrides.")
    return(invisible(empty))
  }

  rows <- lapply(metas, function(mf) {
    stem <- sub("\\.meta\\.yaml$", "", mf)
    ov   <- tryCatch(.eri_dq_schema_override_state(stem, azcontainer),
                      error = function(e) list(state = "unknown", meta = NULL))
    status <- switch(ov$state,
      none    = "incomplete (missing override file)",
      active  = "active",
      stale   = "stale (will be retired on next load)",
      unknown = "unknown (upstream unreachable)"
    )
    # ov$meta is NULL in the "none" case (the shared helper only reads the
    # sidecar once it's confirmed the paired schema file also exists) -- read
    # it directly here so an incomplete entry still shows who/when forked it.
    meta <- ov$meta %||% yaml::read_yaml(file.path(dir, mf))
    tibble::tibble(stem = stem, forked_at = meta$forked_at %||% NA_character_,
                   forked_by = meta$forked_by %||% NA_character_,
                   base_source = meta$base_source %||% NA_character_, status = status)
  })
  out <- dplyr::bind_rows(rows)
  print(out)
  invisible(out)
}

#' Delete a local DQ schema override
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Removes the local override created by [eri_dq_schema_edit()] (and its
#' sidecar), so [load_dq_schema()] goes back to resolving Azure/bundled
#' directly. Does not touch retired overrides (`.retired-*` files) -- those
#' stay on disk as a record of what a DA's local changes used to be.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"uga"`).
#' @param disease `str` Disease (e.g. `"malaria"`, `"lf"`).
#' @param data_source `str` The channel: `"surveillance"`, `"programmatic"`,
#'   `"research"`.
#' @param data_type `str` The measure (e.g. `"case"`, `"treatment"`); optional
#'   for `research`.
#' @param confirm `logical` Ask for confirmation in an interactive session
#'   before deleting. Default `TRUE`; non-interactive sessions (scripts/CI)
#'   proceed without asking regardless.
#' @returns Invisibly, `TRUE` if an override was deleted, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' eri_dq_schema_reset("atlantis", "oncho", "programmatic", "treatment")
#' }
#' @export
eri_dq_schema_reset <- function(country, disease, data_source = NULL, data_type = NULL,
                                 confirm = TRUE) {
  stem  <- .eri_dq_schema_stem(country, disease, data_source, data_type)
  paths <- .eri_schema_override_paths(stem)

  if (!file.exists(paths$yaml) && !file.exists(paths$meta)) {
    cli::cli_alert_info("No local override for {.val {stem}} to reset.")
    return(invisible(FALSE))
  }

  if (isTRUE(confirm) && rlang::is_interactive()) {
    ans <- utils::menu(c("Yes, delete it", "No, cancel"),
                        title = paste0("Delete local schema override for '", stem, "'?"))
    if (ans != 1L) {
      cli::cli_alert_info("Cancelled -- override kept.")
      return(invisible(FALSE))
    }
  }

  unlink(c(paths$yaml, paths$meta))
  cli::cli_alert_success(
    "Deleted local override for {.val {stem}}. {.fn load_dq_schema} will use Azure/bundled again."
  )
  invisible(TRUE)
}

# A fully-named list (every element has a non-empty name) is a YAML mapping
# (e.g. `columns`, `columns$district`) -- worth recursing into. A YAML
# sequence (`aliases: [...]`, `range: [0, 100]`) parses to an unnamed list --
# a leaf to compare directly, not a sub-block to walk.
#' @keywords internal
.eri_dq_schema_is_named_list <- function(x) {
  is.list(x) && length(x) > 0L && !is.null(names(x)) && all(nzchar(names(x)))
}

#' @keywords internal
.eri_dq_schema_fmt_value <- function(x) {
  if (is.null(x)) return("(none)")
  v <- unlist(x, use.names = FALSE)
  # A DQ range like [0, 10000000] is exactly the common case here -- plain
  # as.character() on a round numeric renders scientific notation ("1e+07"),
  # which would be actively misleading in an auto-drafted ticket message.
  fmt1 <- function(e) {
    if (is.character(e)) paste0('"', e, '"')
    else if (is.numeric(e)) format(e, scientific = FALSE, trim = TRUE)
    else as.character(e)
  }
  if (length(v) == 1L) return(fmt1(v))
  paste0("[", paste(vapply(v, fmt1, character(1L)), collapse = ", "), "]")
}

# Human-readable diff between a base and an edited DQ schema (both already
# parsed YAML), for eri_dq_schema_submit()'s ticket message. Recurses into
# named sub-blocks; at a leaf, `aliases` and any key ending `_values` (e.g.
# `allowed_values`) -- the two typed-edit shapes the workflow-redesign vision
# names explicitly -- are diffed as a set of added/removed entries, since
# that's the more readable framing for a growing list. Everything else
# (ranges, flags, scalars) is shown as a before -> after value change. Not
# exhaustive for arbitrarily creative hand edits, but always shows *something*
# changed rather than silently omitting a diff it doesn't have a nice phrasing
# for.
#' @keywords internal
.eri_dq_schema_diff <- function(base, override, path = character(0)) {
  lines <- character(0)
  keys  <- union(names(base) %||% character(0), names(override) %||% character(0))
  for (k in keys) {
    key_path  <- c(path, k)
    key_label <- paste(key_path, collapse = ".")
    b <- base[[k]]
    o <- override[[k]]

    if (identical(b, o)) next

    if (is.null(b)) {
      lines <- c(lines, paste0(key_label, ": added ", .eri_dq_schema_fmt_value(o)))
      next
    }
    if (is.null(o)) {
      lines <- c(lines, paste0(key_label, ": removed (was ", .eri_dq_schema_fmt_value(b), ")"))
      next
    }
    if (.eri_dq_schema_is_named_list(b) && .eri_dq_schema_is_named_list(o)) {
      lines <- c(lines, .eri_dq_schema_diff(b, o, key_path))
      next
    }
    if (grepl("(^aliases$|_values$)", k)) {
      bv      <- as.character(unlist(b, use.names = FALSE))
      ov      <- as.character(unlist(o, use.names = FALSE))
      added   <- setdiff(ov, bv)
      removed <- setdiff(bv, ov)
      if (length(added))   lines <- c(lines, paste0(key_label, ": added ",   paste(sprintf('"%s"', added),   collapse = ", ")))
      if (length(removed)) lines <- c(lines, paste0(key_label, ": removed ", paste(sprintf('"%s"', removed), collapse = ", ")))
      next
    }
    lines <- c(lines, paste0(key_label, ": ", .eri_dq_schema_fmt_value(b), " -> ", .eri_dq_schema_fmt_value(o)))
  }
  lines
}

#' Submit a local DQ schema override for a maintainer to fold in
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Packages a live local schema override (from [eri_dq_schema_edit()]) into a
#' ticket via [eri_feedback()]: the message is an auto-drafted, human-readable
#' diff against the schema it was forked from (so a maintainer never has to
#' retype YAML from a prose description), the full override file is attached,
#' and the four ADR-0012 axes plus the schema's own stem are recorded as
#' `context`. Filed under `area = "dq"`.
#'
#' Submitting does **not** apply the change anywhere else — it only files the
#' ticket. Folding it in means a maintainer updates the Azure `schemas/`
#' `.yaml` blob directly ([load_dq_schema()] already prefers the Azure copy
#' over the bundled one), which takes effect for every DA within minutes, not
#' at the next package release. Your own local override keeps working
#' independently (see [eri_dq_schema_status()]) until it's reset or the
#' upstream change retires it.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"uga"`).
#' @param disease `str` Disease (e.g. `"malaria"`, `"lf"`).
#' @param data_source `str` The channel: `"surveillance"`, `"programmatic"`,
#'   `"research"`.
#' @param data_type `str` The measure (e.g. `"case"`, `"treatment"`); optional
#'   for `research`.
#' @param note `str` or `NULL` An optional one-line note appended after the
#'   auto-drafted diff (e.g. why the change matters, or which real submission
#'   surfaced it).
#' @param azcontainer Azure container object from [get_azure_storage_connection()].
#' @returns Invisibly, the logged ticket from [eri_feedback()] (`NULL` if the
#'   override is identical to upstream, in which case nothing is filed).
#' @examples
#' \dontrun{
#' eri_dq_schema_edit("sdn", "oncho", "programmatic", "treatment")
#' # ... edit the file, e.g. widen a range or add a district alias ...
#' eri_dq_schema_submit("sdn", "oncho", "programmatic", "treatment",
#'                      note = "Barbar's real submissions use this alias")
#' }
#' @seealso [eri_dq_schema_edit()] to create the override being submitted,
#'   [eri_feedback()] for the general ticket log.
#' @export
eri_dq_schema_submit <- function(country, disease, data_source = NULL, data_type = NULL,
                                  note = NULL,
                                  azcontainer = suppressMessages(
                                    get_azure_storage_connection(
                                      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
                                    ))) {
  if (!is.null(note) && (length(note) != 1L || !is.character(note) || is.na(note))) {
    cli::cli_abort("{.arg note} must be a single string, or {.code NULL}.")
  }

  stem <- .eri_dq_schema_stem(country, disease, data_source, data_type)
  ov   <- .eri_dq_schema_override_state(stem, azcontainer)

  if (ov$state == "none") {
    cli::cli_abort(c(
      "No local schema override for {.val {stem}} to submit.",
      "i" = "Fork one with {.fn eri_dq_schema_edit} first."
    ))
  }
  if (ov$state == "stale") {
    cli::cli_abort(c(
      "Your local override for {.val {stem}} is stale -- the upstream schema changed since you forked it.",
      "i" = "Re-fork with {.fn eri_dq_schema_edit}, re-apply your change, then submit again."
    ))
  }
  if (ov$state == "unknown") {
    cli::cli_abort(c(
      "Could not verify your local override for {.val {stem}} against upstream (unreachable).",
      "i" = "Try again once connected -- a reliable diff needs to compare against the current upstream."
    ))
  }

  base_content <- yaml::read_yaml(ov$upstream$path)
  edit_content <- yaml::read_yaml(ov$paths$yaml)
  diff_lines   <- .eri_dq_schema_diff(base_content, edit_content)

  if (length(diff_lines) == 0L) {
    cli::cli_alert_info("Your local override for {.val {stem}} is identical to upstream -- nothing to submit.")
    return(invisible(NULL))
  }

  message_lines <- c(
    paste0("DQ schema override for `", stem, "`:"),
    paste0("- ", diff_lines)
  )
  if (!is.null(note) && nzchar(trimws(note))) {
    message_lines <- c(message_lines, "", trimws(note))
  }
  message_lines <- c(message_lines, "", paste0(
    "(Fold in by updating `schemas/", stem, ".yaml` in the Azure `data` blob -- ",
    "load_dq_schema() prefers it over the bundled copy, so this takes effect for every DA ",
    "within minutes, not at the next package release.)"
  ))

  # A research-lane submission has no data_type -- eri_feedback() itself
  # scrubs a NULL-valued context element (list()'s constructor keeps it,
  # unlike assigning NULL into an existing list, which removes it), so no
  # NULL-filtering is needed here.
  ticket <- eri_feedback(
    message    = paste(message_lines, collapse = "\n"),
    area       = "dq",
    context    = list(country = country, disease = disease, data_source = data_source,
                      data_type = data_type, schema = stem),
    attachment = ov$paths$yaml,
    data_con   = azcontainer
  )
  cli::cli_alert_success("Submitted schema override for {.val {stem}} as ticket #{ticket$id}.")
  invisible(ticket)
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

  structure(
    list(data = state$data, log = state$log, flags = state$flags,
         # Carried straight from the schema this check actually ran against
         # (set by load_dq_schema()'s resolver) so .eri_dq_log_write() can
         # record, in the permanent log, whether this result came from a DA's
         # local schema override -- without a signature change of its own.
         schema_source = schema$schema_source %||% NA_character_,
         schema_hash   = schema$schema_hash %||% NA_character_),
    class = "dq_result"
  )
}

#' Print a formatted DQ summary report
#'
#' Prints an analyst-readable summary of a `dq_result` object, including
#' data shape, corrections applied by column, and flagged issues grouped by
#' type. Called automatically when a `dq_result` is printed.
#'
#' @param result A `dq_result` object returned by [run_dq_checks()].
#' @returns Invisibly returns `result`.
#' @examples
#' \dontrun{
#' result <- run_dq_checks(raw_data, schema)
#' result          # print method calls dq_report automatically
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
        sub  <- row_flags[row_flags$issue == issue, ]
        n    <- nrow(sub)
        cols <- paste(unique(sub$column), collapse = ", ")
        # Show up to 3 offending values with their row numbers, so the analyst
        # sees *what* to fix without digging into result$flags.
        k    <- min(3L, n)
        val  <- sub$value[seq_len(k)]
        val[is.na(val)] <- "<NA>"
        val[val == ""]  <- "<empty>"
        ex   <- paste0(val, " (row ", sub$row[seq_len(k)], ")", collapse = "; ")
        more <- if (n > k) paste0(", +", n - k, " more") else ""
        cli::cli_bullets(c("!" = "{issue}: {n} row{?s} [{cols}] (e.g. {ex}{more})"))
      }
      cli::cli_text("")
      cli::cli_alert_info("See {.code result$flags} for the full row-level detail.")
    }
  }

  invisible(result)
}

#' S3 methods for dq_result objects
#'
#' @param x,object A `dq_result` object returned by `run_dq_checks()`.
#' @param ... Unused; included for S3 method compatibility.
#' @name dq_result-methods
NULL

#' @export
#' @rdname dq_result-methods
print.dq_result <- function(x, ...) {
  dq_report(x)
}

#' @export
#' @rdname dq_result-methods
summary.dq_result <- function(object, ...) {
  cli::cli_text(
    "{nrow(object$data)} rows | {nrow(object$log)} correction{?s} | {nrow(object$flags)} flag{?s}"
  )
  invisible(object)
}
