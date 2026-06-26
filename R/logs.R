#### Operation / DQ log triage ####
#
# Reads the structured operation-log YAMLs already written across
# `{country}/{disease}/{data_type}/logs/` (by .eri_write_log) plus the DQ-flag
# logs written by eri_dq_log(), into a triage backlog, and lets an analyst mark
# items handled. Mirrors the catalog query/verify pattern in R/catalog.R.

#' @keywords internal
.eri_na_chr <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  if (length(x) == 1L && is.na(x)) return(NA_character_)
  as.character(x[[1L]])
}

#' @keywords internal
.eri_na_int <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_integer_)
  as.integer(x[[1L]])
}

# Resolve the data/ container from arg or env vars (mirrors .eri_catalog_con).
#' @keywords internal
.eri_logs_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

# Top-level data/ directories that are infrastructure, not country namespaces.
#' @keywords internal
.ERI_LOGS_INFRA_DIRS <- c("artifacts", "research", "schemas", "spatial",
                          "odk", "templates", "logs")

# List immediate sub-directory names under a blob prefix, skipping infra dirs
# (those starting with "_", e.g. _catalog, or in the known infra set).
#' @keywords internal
.eri_logs_list_subdirs <- function(con, prefix) {
  lst <- tryCatch(
    dplyr::as_tibble(AzureStor::list_storage_files(con, prefix)),
    error = function(e) NULL
  )
  if (is.null(lst) || nrow(lst) == 0L) return(character(0))
  nm <- basename(lst$name[lst$isdir])
  nm[!startsWith(nm, "_") & !(nm %in% .ERI_LOGS_INFRA_DIRS)]
}

# Resolve which `…/logs/` directories to scan. If country+disease+data_type are
# all supplied, that single dir; otherwise enumerate the tree (data_type is
# bounded to the three known types, so only country/disease levels are listed).
#' @keywords internal
.eri_logs_dirs <- function(con, country, disease, data_type) {
  dts <- if (!is.null(data_type)) data_type else c("surveillance", "cmr", "odk")
  countries <- if (!is.null(country)) country else .eri_logs_list_subdirs(con, "")

  dirs <- character(0)
  for (cc in countries) {
    diseases <- if (!is.null(disease)) disease else .eri_logs_list_subdirs(con, cc)
    for (dd in diseases) {
      for (dt in dts) {
        d <- paste(c(cc, dd, dt, "logs"), collapse = "/")
        exists <- isTRUE(tryCatch(
          AzureStor::storage_dir_exists(con, d),
          error = function(e) FALSE
        ))
        if (exists) dirs <- c(dirs, d)
      }
    }
  }
  unique(dirs)
}

# Flatten one parsed log YAML into a single backlog row (tolerant of the rich
# pipeline envelope, the flat ODK envelope, and the dq_flags envelope).
#' @keywords internal
.eri_log_flatten <- function(entry, log_path) {
  # Some operations (eri_odk_sync, eri_stage_cmr) don't record every scoping
  # field in `parameters`; the values are unambiguous in the blob path
  # `{country}/{disease}/{data_type}/logs/{file}.yaml`, so fall back to that.
  parts   <- strsplit(log_path, "/", fixed = TRUE)[[1]]
  logs_at <- which(parts == "logs")
  logs_at <- if (length(logs_at)) logs_at[length(logs_at)] else NA_integer_
  from_path <- function(offset) {
    i <- logs_at - offset
    if (!is.na(logs_at) && i >= 1L) parts[i] else NA_character_
  }
  coalesce_chr <- function(x, fallback) {
    x <- .eri_na_chr(x)
    if (is.na(x)) fallback else x
  }

  ts <- entry$completed_at %||% entry$timestamp %||% entry$started_at
  summary <- if (!is.null(entry$error)) {
    as.character(entry$error)
  } else if (!is.null(entry$n_flags)) {
    paste0(entry$n_flags, " flag", if (as.integer(entry$n_flags) == 1L) "" else "s")
  } else {
    NA_character_
  }
  n_issues <- if (!is.null(entry$n_flags)) {
    as.integer(entry$n_flags)
  } else if (identical(entry$status, "error")) {
    1L
  } else {
    0L
  }
  list(
    log_path   = log_path,
    timestamp  = .eri_na_chr(ts),
    operation  = .eri_na_chr(entry$operation),
    status     = .eri_na_chr(entry$status),
    analyst    = .eri_na_chr(entry$analyst),
    country    = coalesce_chr(entry$parameters$country,   from_path(3L)),
    disease    = coalesce_chr(entry$parameters$disease,   from_path(2L)),
    data_type  = coalesce_chr(entry$parameters$data_type, from_path(1L)),
    period     = .eri_na_chr(entry$parameters$period),
    summary    = .eri_na_chr(summary),
    n_issues   = .eri_na_int(n_issues),
    handled    = isTRUE(entry$triage$handled),
    handled_by = .eri_na_chr(entry$triage$handled_by),
    handled_at = .eri_na_chr(entry$triage$handled_at)
  )
}

#' @keywords internal
.eri_logs_empty <- function() {
  tibble::tibble(
    log_path   = character(),
    timestamp  = character(),
    operation  = character(),
    status     = character(),
    analyst    = character(),
    country    = character(),
    disease    = character(),
    data_type  = character(),
    period     = character(),
    summary    = character(),
    n_issues   = integer(),
    handled    = logical(),
    handled_by = character(),
    handled_at = character()
  )
}

#### eri_dq_log ####

#' Persist data-quality flags to the log backlog
#'
#' Writes the `$flags` from a [run_dq_checks()] result (plus a corrections count)
#' to a YAML log in `{country}/{disease}/{data_type}/logs/` in the `data/` Azure
#' blob, so the data-quality issues are durable and discoverable by [eri_logs()].
#' Without this, `run_dq_checks()` flags exist only in your R session. `eri_ingest()`
#' calls this automatically.
#'
#' @param result A `dq_result` object returned by [run_dq_checks()].
#' @param country `chr` Country code (e.g. `"uga"`).
#' @param disease `chr` Disease name (e.g. `"oncho"`).
#' @param data_type `chr` Data type (`"surveillance"`, `"cmr"`, or `"odk"`).
#' @param period `chr` or `NULL` Reporting period the data covers (e.g. `"2024-01"`).
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, the number of flags logged.
#' @examples
#' \dontrun{
#' result <- run_dq_checks(raw, schema)
#' eri_dq_log(result, "uga", "oncho", "surveillance", period = "2024-01")
#' }
#' @export
eri_dq_log <- function(result, country, disease, data_type,
                       period = NULL, data_con = NULL) {
  if (!inherits(result, "dq_result")) {
    cli::cli_abort("{.arg result} must be a {.cls dq_result} from {.fn run_dq_checks}.")
  }
  data_con <- .eri_logs_con(data_con)

  flags   <- result$flags
  n_flags <- nrow(flags)
  flags_list <- lapply(seq_len(n_flags), function(i) {
    list(
      row    = .eri_na_int(flags$row[i]),
      column = .eri_na_chr(flags$column[i]),
      value  = .eri_na_chr(flags$value[i]),
      issue  = .eri_na_chr(flags$issue[i])
    )
  })

  envelope <- list(
    operation     = "dq_flags",
    analyst       = Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]]),
    timestamp     = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters    = list(country = country, disease = disease,
                         data_type = data_type, period = period),
    status        = if (n_flags > 0L) "needs_review" else "clean",
    n_flags       = n_flags,
    n_corrections = nrow(result$log),
    flags         = flags_list
  )

  log_dir <- paste(c(country, disease, data_type, "logs"), collapse = "/")
  .eri_write_log(envelope, data_con, log_dir)
  cli::cli_alert_success(
    "Logged {n_flags} DQ flag{?s} ({envelope$status})."
  )
  invisible(n_flags)
}

#### eri_logs ####

#' List the operation / DQ log backlog for triage
#'
#' Reads the structured operation logs (written by `eri_ingest()`, `eri_approve()`,
#' `eri_stage()`, `eri_odk_sync()`, …) and the DQ-flag logs (written by
#' [eri_dq_log()]) from `{country}/{disease}/{data_type}/logs/` in the `data/`
#' Azure blob, and returns them as a triage backlog. Filter to failures with
#' `status = "error"` or data-quality items with `status = "needs_review"`, then
#' close items out with [eri_logs_resolve()].
#'
#' If `country`, `disease`, and `data_type` are all supplied, only that one log
#' directory is read (fast). Otherwise the function enumerates the data blob to
#' build a system-wide backlog (slower); supplying filters narrows the scan.
#'
#' @param country,disease,data_type `chr` or `NULL` Scope the search. All three
#'   together read a single `logs/` directory; any left `NULL` triggers enumeration.
#' @param status `chr` or `NULL` Filter by status (`"success"`, `"error"`,
#'   `"in_progress"`, `"needs_review"`, `"clean"`).
#' @param operation `chr` or `NULL` Filter by operation (e.g. `"eri_approve"`, `"dq_flags"`).
#' @param analyst `chr` or `NULL` Filter by the analyst who ran the operation.
#' @param since `Date`/`chr` or `NULL` Keep logs at or after this date (ISO `YYYY-MM-DD`).
#' @param include_handled `lgl` Include items already marked handled. Default `FALSE`.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble, newest first, with columns: `log_path`, `timestamp`,
#'   `operation`, `status`, `analyst`, `country`, `disease`, `data_type`,
#'   `period`, `summary`, `n_issues`, `handled`, `handled_by`, `handled_at`.
#' @examples
#' \dontrun{
#' # Everything needing attention across the system
#' eri_logs(status = "error")
#'
#' # The backlog for one dataset
#' eri_logs("uga", "oncho", "surveillance")
#' }
#' @export
eri_logs <- function(country = NULL, disease = NULL, data_type = NULL,
                     status = NULL, operation = NULL, analyst = NULL,
                     since = NULL, include_handled = FALSE, data_con = NULL) {
  data_con <- .eri_logs_con(data_con)
  dirs     <- .eri_logs_dirs(data_con, country, disease, data_type)

  if (length(dirs) == 0L) {
    cli::cli_inform("No log directories found.")
    return(.eri_logs_empty())
  }

  rows <- list()
  for (d in dirs) {
    files <- tryCatch(
      dplyr::as_tibble(AzureStor::list_storage_files(data_con, d)),
      error = function(e) NULL
    )
    if (is.null(files) || nrow(files) == 0L) next
    files <- files[!files$isdir & grepl("\\.yaml$", files$name), , drop = FALSE]
    for (fp in files$name) {
      entry <- tryCatch({
        tmp <- tempfile(fileext = ".yaml")
        .eri_blob_read(data_con, fp, tmp)
        e <- yaml::read_yaml(tmp)
        unlink(tmp)
        e
      }, error = function(e) NULL)
      if (is.null(entry)) next
      rows[[length(rows) + 1L]] <- .eri_log_flatten(entry, fp)
    }
  }

  if (length(rows) == 0L) {
    cli::cli_inform("No logs found.")
    return(.eri_logs_empty())
  }

  out <- tibble::tibble(
    log_path   = vapply(rows, function(r) .eri_na_chr(r$log_path),   character(1L)),
    timestamp  = vapply(rows, function(r) .eri_na_chr(r$timestamp),  character(1L)),
    operation  = vapply(rows, function(r) .eri_na_chr(r$operation),  character(1L)),
    status     = vapply(rows, function(r) .eri_na_chr(r$status),     character(1L)),
    analyst    = vapply(rows, function(r) .eri_na_chr(r$analyst),    character(1L)),
    country    = vapply(rows, function(r) .eri_na_chr(r$country),    character(1L)),
    disease    = vapply(rows, function(r) .eri_na_chr(r$disease),    character(1L)),
    data_type  = vapply(rows, function(r) .eri_na_chr(r$data_type),  character(1L)),
    period     = vapply(rows, function(r) .eri_na_chr(r$period),     character(1L)),
    summary    = vapply(rows, function(r) .eri_na_chr(r$summary),    character(1L)),
    n_issues   = vapply(rows, function(r) .eri_na_int(r$n_issues),   integer(1L)),
    handled    = vapply(rows, function(r) isTRUE(r$handled),         logical(1L)),
    handled_by = vapply(rows, function(r) .eri_na_chr(r$handled_by), character(1L)),
    handled_at = vapply(rows, function(r) .eri_na_chr(r$handled_at), character(1L))
  )

  if (!include_handled)    out <- out[!out$handled, , drop = FALSE]
  if (!is.null(status))    out <- out[!is.na(out$status)    & out$status    == status,    , drop = FALSE]
  if (!is.null(operation)) out <- out[!is.na(out$operation) & out$operation == operation, , drop = FALSE]
  if (!is.null(analyst))   out <- out[!is.na(out$analyst)   & out$analyst   == analyst,   , drop = FALSE]
  if (!is.null(since))     out <- out[!is.na(out$timestamp) & out$timestamp >= as.character(since), , drop = FALSE]

  out <- out[order(out$timestamp, decreasing = TRUE), , drop = FALSE]

  if (nrow(out) == 0L) {
    cli::cli_inform("No logs match the specified filters.")
    return(.eri_logs_empty())
  }

  n_attention <- sum(out$status %in% c("error", "needs_review"))
  cli::cli_inform("{nrow(out)} log{?s} ({n_attention} needing attention).")
  out
}

#### eri_logs_resolve ####

#' Mark a log entry as handled
#'
#' Records a triage note on a single log YAML (by its `log_path` from
#' [eri_logs()]), flagging it handled so it drops out of the open backlog. Adds a
#' `triage` block (`handled`, `handled_by`, `handled_at`, `note`) to the file in
#' place; the original operation record is preserved.
#'
#' @param log_path `chr` Blob path of the log to resolve (the `log_path` column
#'   from [eri_logs()]).
#' @param note `chr` or `NULL` An optional note describing how it was handled.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, `TRUE`.
#' @examples
#' \dontrun{
#' backlog <- eri_logs(status = "error")
#' eri_logs_resolve(backlog$log_path[1], note = "Re-ran after the source fixed the file.")
#' }
#' @export
eri_logs_resolve <- function(log_path, note = NULL, data_con = NULL) {
  data_con <- .eri_logs_con(data_con)

  tmp <- tempfile(fileext = ".yaml")
  entry <- tryCatch({
    .eri_blob_read(data_con, log_path, tmp)
    yaml::read_yaml(tmp)
  }, error = function(e) {
    cli::cli_abort("Could not read log {.path {log_path}}: {conditionMessage(e)}")
  })

  entry$triage <- list(
    handled    = TRUE,
    handled_by = Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]]),
    handled_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    note       = if (is.null(note)) NA_character_ else note
  )

  yaml::write_yaml(entry, tmp)
  .eri_blob_write(data_con, tmp, log_path)
  unlink(tmp)

  cli::cli_alert_success("Marked {.path {basename(log_path)}} handled.")
  invisible(TRUE)
}
