#### Operation / DQ log triage ####
#
# Reads the structured operation-log YAMLs already written across
# `{country}/{disease}/{data_source}[/{data_type}]/logs/` (by .eri_write_log)
# plus the DQ-flag logs written by eri_dq_log(), into a triage backlog, and lets
# an analyst mark items handled. Mirrors the catalog query/verify pattern in
# R/catalog.R. Per ADR-0012 the log path carries the channel (`data_source`) and,
# when present, the measure (`data_type`); the reader handles both the four-axis
# (no measure) and five-axis layouts.

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

# Top-level `data/` directories that are infrastructure, not country namespaces.
# These are skipped only at the *country* level of the walk — crucially, some of
# these names (`research`, `odk`) are also valid `data_source` values deeper in
# the tree, so they must NOT be stripped below the country level.
#' @keywords internal
.ERI_LOGS_INFRA_DIRS <- c("artifacts", "research", "schemas", "spatial",
                          "odk", "templates", "logs")

# Structural directory names that are never a country/disease/data_source/measure
# value: the pipeline layers and the `logs/` leaf. Skipped at every level below
# the country so the measure enumeration doesn't mistake a layer for a measure.
#' @keywords internal
.ERI_LOGS_NONAXIS_DIRS <- c("raw", "staged", "processed", "logs")

# List immediate sub-directory names under a blob prefix, skipping `_`-prefixed
# dirs (e.g. _catalog) and any name in `exclude`. `exclude` is level-specific:
# the top-level infra set at the country level, the non-axis set deeper down.
#' @keywords internal
.eri_logs_list_subdirs <- function(con, prefix, exclude = .ERI_LOGS_NONAXIS_DIRS) {
  lst <- tryCatch(
    dplyr::as_tibble(AzureStor::list_storage_files(con, prefix)),
    error = function(e) NULL
  )
  if (is.null(lst) || nrow(lst) == 0L) return(character(0))
  nm <- basename(lst$name[lst$isdir])
  nm[!startsWith(nm, "_") & !(nm %in% exclude)]
}

#' @keywords internal
.eri_logs_dir_exists <- function(con, d) {
  isTRUE(tryCatch(AzureStor::storage_dir_exists(con, d), error = function(e) FALSE))
}

# Resolve which `…/logs/` directories to scan, across both the four-axis
# (`{country}/{disease}/{data_source}/logs/`) and five-axis
# (`{country}/{disease}/{data_source}/{data_type}/logs/`) layouts (ADR-0012).
# Supplying `country`/`disease`/`data_source`/`data_type` narrows each level;
# any left `NULL` is enumerated from the blob. A supplied `data_type` (measure)
# restricts to the five-axis dir for that measure; otherwise both the channel's
# own `logs/` and every measure's `logs/` under it are scanned.
#' @keywords internal
.eri_logs_dirs <- function(con, country, disease, data_source, data_type) {
  countries <- if (!is.null(country)) country
               else .eri_logs_list_subdirs(con, "", exclude = .ERI_LOGS_INFRA_DIRS)

  dirs <- character(0)
  for (cc in countries) {
    diseases <- if (!is.null(disease)) disease
                else .eri_logs_list_subdirs(con, cc)
    for (dd in diseases) {
      dd_prefix <- paste(cc, dd, sep = "/")
      sources   <- if (!is.null(data_source)) data_source
                   else .eri_logs_list_subdirs(con, dd_prefix)
      for (ds in sources) {
        src_prefix <- paste(dd_prefix, ds, sep = "/")

        # Four-axis: the channel's own logs/ (only when not scoping to a measure).
        if (is.null(data_type)) {
          d4 <- paste0(src_prefix, "/logs")
          if (.eri_logs_dir_exists(con, d4)) dirs <- c(dirs, d4)
        }

        # Five-axis: a measure level under the channel.
        measures <- if (!is.null(data_type)) data_type
                    else .eri_logs_list_subdirs(con, src_prefix)
        for (mm in measures) {
          d5 <- paste(c(cc, dd, ds, mm, "logs"), collapse = "/")
          if (.eri_logs_dir_exists(con, d5)) dirs <- c(dirs, d5)
        }
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
  # `{country}/{disease}/{data_source}[/{data_type}]/logs/{file}.yaml`, so fall
  # back to that. The path is authoritative for the channel/measure axes, since
  # legacy envelopes overloaded `parameters$data_type` with the channel value.
  parts   <- strsplit(log_path, "/", fixed = TRUE)[[1]]
  logs_at <- which(parts == "logs")
  logs_at <- if (length(logs_at)) logs_at[length(logs_at)] else NA_integer_
  depth   <- if (!is.na(logs_at)) logs_at - 1L else 0L  # segments before /logs
  # Layout is country/disease/data_source[/data_type]/logs, so the axes read off
  # the front of the path; a measure exists only at depth 4 (the five-axis form).
  path_country <- if (depth >= 1L) parts[1L] else NA_character_
  path_disease <- if (depth >= 2L) parts[2L] else NA_character_
  path_source  <- if (depth >= 3L) parts[3L] else NA_character_
  path_measure <- if (depth >= 4L) parts[4L] else NA_character_
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
    country     = coalesce_chr(entry$parameters$country, path_country),
    disease     = coalesce_chr(entry$parameters$disease, path_disease),
    # Channel/measure: trust the path (legacy envelopes overloaded data_type).
    data_source = coalesce_chr(path_source,  entry$parameters$data_source),
    data_type   = coalesce_chr(path_measure, NA_character_),
    period      = .eri_na_chr(entry$parameters$period),
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
    analyst     = character(),
    country     = character(),
    disease     = character(),
    data_source = character(),
    data_type   = character(),
    period      = character(),
    summary     = character(),
    n_issues    = integer(),
    handled     = logical(),
    handled_by  = character(),
    handled_at  = character()
  )
}

#### eri_dq_log ####

#' Persist data-quality flags to the log backlog
#'
#' Writes the `$flags` from a [run_dq_checks()] result (plus a corrections count)
#' to a YAML log in `{country}/{disease}/{data_source}[/{data_type}]/logs/` in the
#' `data/` Azure blob, so the data-quality issues are durable and discoverable by
#' [eri_logs()]. Without this, `run_dq_checks()` flags exist only in your R session.
#' `eri_ingest()` calls this automatically.
#'
#' @param result A `dq_result` object returned by [run_dq_checks()].
#' @param country `chr` Country code (e.g. `"uga"`).
#' @param disease `chr` Disease name (e.g. `"oncho"`).
#' @param data_source `chr` The channel (`"surveillance"`, `"programmatic"`,
#'   `"research"`).
#' @param data_type `chr` or `NULL` The measure (e.g. `"case"`, `"treatment"`);
#'   `NULL` (default) writes to the four-axis channel-level `logs/` directory.
#' @param period `chr` or `NULL` Reporting period the data covers (e.g. `"2024-01"`).
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @param source_hash `chr` or `NULL` MD5 hash of the source file this check ran
#'   against (identity, not security), if you have one -- lets a later audit
#'   trail confirm exactly which bytes were reviewed. `NULL` (default) when
#'   there's no local file to hash (e.g. checking data already staged in Azure).
#' @returns Invisibly, the number of flags logged.
#' @examples
#' \dontrun{
#' result <- run_dq_checks(raw, schema)
#' eri_dq_log(result, "uga", "oncho", "surveillance", period = "2024-01")
#' }
#' @export
eri_dq_log <- function(result, country, disease, data_source,
                       data_type = NULL, period = NULL, data_con = NULL,
                       source_hash = NULL) {
  written <- .eri_dq_log_write(result, country, disease, data_source,
                               data_type, period, data_con, source_hash)
  invisible(written$n_flags)
}

#' @keywords internal
.eri_dq_log_write <- function(result, country, disease, data_source,
                              data_type = NULL, period = NULL, data_con = NULL,
                              source_hash = NULL) {
  if (!inherits(result, "dq_result")) {
    cli::cli_abort("{.arg result} must be a {.cls dq_result} from {.fn run_dq_checks}.")
  }
  data_con <- .eri_logs_con(data_con)

  flags   <- result$flags
  n_flags <- nrow(flags)
  flags_list <- lapply(seq_len(n_flags), function(i) {
    list(
      index  = i,
      row    = .eri_na_int(flags$row[i]),
      column = .eri_na_chr(flags$column[i]),
      value  = .eri_na_chr(flags$value[i]),
      issue  = .eri_na_chr(flags$issue[i]),
      # Per-flag triage (distinct from the whole-entry `triage` block
      # eri_logs_resolve() writes) -- set via eri_dq_flag_resolve(), one
      # flag at a time. "open" until a DA works through it.
      status      = "open",
      note        = NA_character_,
      resolved_by = NA_character_,
      resolved_at = NA_character_
    )
  })

  status   <- if (n_flags > 0L) "needs_review" else "clean"
  envelope <- list(
    operation     = "dq_flags",
    analyst       = .eri_analyst_id(data_con),
    timestamp     = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters    = list(country = country, disease = disease,
                         data_source = data_source, data_type = data_type,
                         period = period),
    # Identity for the file this check actually ran against -- lets an audit
    # trail answer "which exact bytes were reviewed here", not just "some
    # file was". NULL (default) when the caller has no local file to hash
    # (e.g. checking data already staged in Azure).
    source_hash   = if (is.null(source_hash)) NA_character_ else source_hash,
    status        = status,
    n_flags       = n_flags,
    n_corrections = nrow(result$log),
    flags         = flags_list
  )

  # c() drops a NULL data_type, so a four-axis call lands at the channel level.
  log_dir  <- paste(c(country, disease, data_source, data_type, "logs"),
                    collapse = "/")
  log_path <- .eri_write_log(envelope, data_con, log_dir)
  cli::cli_alert_success(
    "Logged {n_flags} DQ flag{?s} ({status})."
  )
  list(n_flags = n_flags, log_path = log_path, status = status, flags = flags_list)
}

#### eri_logs ####

#' List the operation / DQ log backlog for triage
#'
#' Reads the structured operation logs (written by `eri_ingest()`, `eri_approve()`,
#' `eri_stage()`, `eri_odk_sync()`, …) and the DQ-flag logs (written by
#' [eri_dq_log()]) from `{country}/{disease}/{data_source}[/{data_type}]/logs/` in
#' the `data/` Azure blob, and returns them as a triage backlog. Filter to failures
#' with `status = "error"` or data-quality items with `status = "needs_review"`,
#' then close items out with [eri_logs_resolve()].
#'
#' The function scopes the scan to whichever axes you supply and enumerates the
#' rest from the blob; the more you supply (`country` → `disease` → `data_source`
#' → `data_type`), the faster it is. It reads both the four-axis channel-level
#' logs and the five-axis measure-level logs (ADR-0012).
#'
#' @param country,disease,data_source `chr` or `NULL` Scope the search by country,
#'   disease, and channel; any left `NULL` is enumerated from the blob.
#' @param data_type `chr` or `NULL` Scope to a single measure (the five-axis
#'   layout). `NULL` reads the channel-level logs and every measure beneath it.
#' @param status `chr` or `NULL` Filter by status (`"success"`, `"error"`,
#'   `"in_progress"`, `"needs_review"`, `"clean"`).
#' @param operation `chr` or `NULL` Filter by operation (e.g. `"eri_approve"`, `"dq_flags"`).
#' @param analyst `chr` or `NULL` Filter by the analyst who ran the operation.
#' @param since `Date`/`chr` or `NULL` Keep logs at or after this date (ISO `YYYY-MM-DD`).
#' @param include_handled `lgl` Include items already marked handled. Default `FALSE`.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble, newest first, with columns: `log_path`, `timestamp`,
#'   `operation`, `status`, `analyst`, `country`, `disease`, `data_source`,
#'   `data_type`, `period`, `summary`, `n_issues`, `handled`, `handled_by`,
#'   `handled_at`.
#' @examples
#' \dontrun{
#' # Everything needing attention across the system
#' eri_logs(status = "error")
#'
#' # The backlog for one dataset
#' eri_logs("uga", "oncho", "surveillance")
#'
#' # Scope to a single measure (five-axis)
#' eri_logs("uga", "oncho", "programmatic", data_type = "treatment")
#' }
#' @export
eri_logs <- function(country = NULL, disease = NULL, data_source = NULL,
                     data_type = NULL, status = NULL, operation = NULL,
                     analyst = NULL, since = NULL, include_handled = FALSE,
                     data_con = NULL) {
  data_con <- .eri_logs_con(data_con)
  dirs     <- .eri_logs_dirs(data_con, country, disease, data_source, data_type)

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
    country     = vapply(rows, function(r) .eri_na_chr(r$country),     character(1L)),
    disease     = vapply(rows, function(r) .eri_na_chr(r$disease),     character(1L)),
    data_source = vapply(rows, function(r) .eri_na_chr(r$data_source), character(1L)),
    data_type   = vapply(rows, function(r) .eri_na_chr(r$data_type),   character(1L)),
    period      = vapply(rows, function(r) .eri_na_chr(r$period),      character(1L)),
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
#' Same single-editor caveat as [eri_dq_flag_resolve()]: this is a read-modify-write
#' with no optimistic-concurrency protection, so two people resolving the *same*
#' log entry around the same time can silently clobber one another.
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

  # If the DA already worked through this entry's individual flags via
  # eri_dq_flag_resolve() and didn't pass an explicit note here, summarize
  # those per-flag decisions instead of leaving the whole-entry note blank.
  if (is.null(note)) note <- .eri_dq_flags_summary(entry$flags)

  entry$triage <- list(
    handled    = TRUE,
    handled_by = .eri_analyst_id(data_con),
    handled_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    note       = if (is.null(note)) NA_character_ else note
  )

  yaml::write_yaml(entry, tmp)
  .eri_blob_write(data_con, tmp, log_path)
  unlink(tmp)

  cli::cli_alert_success("Marked {.path {basename(log_path)}} handled.")
  invisible(TRUE)
}

#' @keywords internal
.eri_dq_flags_summary <- function(flags) {
  if (is.null(flags) || length(flags) == 0L) return(NULL)
  statuses <- vapply(flags, function(f) f$status %||% "open", character(1L))
  if (all(statuses == "open")) return(NULL)
  counts <- table(statuses)
  parts  <- paste0(counts, " ", gsub("_", " ", names(counts)))
  paste(parts, collapse = ", ")
}

#### eri_dq_flag_resolve ####

#' Triage a single DQ flag within a logged `eri_dq_log()` entry
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Works through **one flag at a time** rather than an entire DQ-log entry:
#' marks a specific flag `"not_important"`, `"fixed"`, or `"noted"`, with an
#' optional note, so a DA can triage a multi-flag entry (e.g. one CMR measure
#' with several issues) issue by issue instead of all-or-nothing. Distinct
#' from [eri_logs_resolve()], which closes out the *whole* entry (and marks
#' it `handled`, dropping it from the open backlog / unblocking
#' [eri_approve_cmr()]) -- resolving every individual flag here does not by
#' itself mark the entry handled; call [eri_logs_resolve()] afterward for
#' that (it will auto-summarize from the per-flag decisions if you don't pass
#' your own note).
#'
#' **Known limitation: single-editor assumption.** This does a read-modify-write
#' of the whole log YAML with no optimistic-concurrency check (no ETag/retry,
#' unlike the metadata-store writes in `catalog.R`/`odk_registry.R`/`artifacts.R`).
#' If two people resolve different flags in the *same* log entry around the same time, the second
#' write can silently overwrite the first. Fine for the current one-DA-per-
#' country-workbook CMR pilot; revisit before assuming it's safe for two people
#' triaging the same measure's flags concurrently.
#'
#' @param flag_id `chr` A flag identifier from [eri_cmr_dq_report()] (or built
#'   by hand as `paste0(log_path, "::", index)`, where `index` is the flag's
#'   1-based position within that log entry).
#' @param status `chr` One of `"not_important"`, `"fixed"`, or `"noted"`.
#' @param note `chr` or `NULL` What you did or decided for this specific flag.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, `TRUE`.
#' @examples
#' \dontrun{
#' flags <- eri_cmr_dq_report("sdn", "202605")
#' eri_dq_flag_resolve(flags$flag_id[1], "fixed", note = "corrected district spelling upstream")
#' eri_dq_flag_resolve(flags$flag_id[2], "not_important", note = "known template quirk")
#' }
#' @export
eri_dq_flag_resolve <- function(flag_id, status = c("not_important", "fixed", "noted"),
                                note = NULL, data_con = NULL) {
  status <- match.arg(status)

  # Validate flag_id before touching Azure at all -- a malformed id shouldn't
  # trigger a connection attempt (and, worse, the interactive browser-auth
  # fallback in a non-interactive context) before failing.
  # Split on the LAST "::" (greedy .*), not the first, in case log_path ever
  # contained the separator itself.
  m <- regmatches(flag_id, regexec("^(.*)::(.*)$", flag_id))[[1]]
  if (length(m) != 3L) {
    cli::cli_abort(c(
      "{.arg flag_id} must be {.code \"{{log_path}}::{{index}}\"}, got {.val {flag_id}}.",
      "i" = "Get valid ids from {.fn eri_cmr_dq_report}."
    ))
  }
  log_path <- m[2]
  index    <- suppressWarnings(as.integer(m[3]))
  if (is.na(index)) {
    cli::cli_abort("Could not parse a flag index from {.val {flag_id}}.")
  }

  data_con <- .eri_logs_con(data_con)

  tmp <- tempfile(fileext = ".yaml")
  entry <- tryCatch({
    .eri_blob_read(data_con, log_path, tmp)
    yaml::read_yaml(tmp)
  }, error = function(e) {
    cli::cli_abort("Could not read log {.path {log_path}}: {conditionMessage(e)}")
  })

  if (is.null(entry$flags) || !any(vapply(entry$flags, function(f) !is.null(f$index), logical(1L)))) {
    cli::cli_abort(c(
      "{.path {log_path}} has no per-flag indices to resolve.",
      "i" = "This entry predates per-flag triage (written before {.fn eri_dq_log} started assigning them), or isn't a {.val dq_flags} entry at all -- use {.fn eri_logs_resolve} to close out the whole entry instead."
    ))
  }
  match_at <- which(vapply(entry$flags, function(f) isTRUE(f$index == index), logical(1L)))
  if (length(match_at) == 0L) {
    cli::cli_abort("No flag with index {index} found in {.path {log_path}}.")
  }

  entry$flags[[match_at[1]]]$status      <- status
  entry$flags[[match_at[1]]]$note        <- if (is.null(note)) NA_character_ else note
  entry$flags[[match_at[1]]]$resolved_by <- .eri_analyst_id(data_con)
  entry$flags[[match_at[1]]]$resolved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  yaml::write_yaml(entry, tmp)
  .eri_blob_write(data_con, tmp, log_path)
  unlink(tmp)

  cli::cli_alert_success("Flag {index} in {.path {basename(log_path)}} marked {.val {status}}.")
  invisible(TRUE)
}
