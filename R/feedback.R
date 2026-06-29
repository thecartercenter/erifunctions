#### eri_feedback — in-package feedback / ticket log ####
#
# A durable, attributable backlog of feedback from DAs and Epis, kept in the
# `data/` blob as a single YAML log. `eri_feedback()` is the **capture** side:
# it appends a ticket with the verified author identity (ADR-0003) and a
# concurrency-safe write (ADR-0002). Reading is `eri_feedback_list()`. Updating a
# ticket's status (submitted -> planned -> fixed) is a separate triage feature
# built on top of this log; this file only writes and reads.

.ERI_FEEDBACK_PATH <- "_feedback/feedback_log.yaml"

# Suggested `area` values. Free text is accepted (the log is meant to be easy to
# file into), but these are the sections we triage by; "general" = not specific.
.ERI_FEEDBACK_AREAS <- c(
  "general", "ingest", "dq", "catalog", "query", "odk", "cmr",
  "reporting", "research", "spatial", "auth", "docs", "other"
)

# Resolve the data container from the arg or env vars (mirrors .eri_catalog_con).
#' @keywords internal
.eri_feedback_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#### eri_feedback ####

#' Log a piece of feedback to the shared ticket log
#'
#' Appends a ticket to `_feedback/feedback_log.yaml` in the `data/` Azure blob —
#' the team's lightweight internal backlog. Use it to flag anything: a bug, a
#' rough edge, a wish, or a general comment, either about the system as a whole
#' (`area = "general"`) or about a specific part of it (e.g. `area = "odk"`).
#'
#' Each ticket records **who** filed it (the verified signed-in identity, not a
#' self-declared name — ADR-0003) and **when**, and is given an auto-incrementing
#' id. Writes are concurrency-safe (ADR-0002), so two people filing at once never
#' clobber each other. New tickets start at `status = "submitted"`; moving a
#' ticket through triage (`planned`, `fixed`, ...) is handled by the separate
#' tracking workflow, not by this function.
#'
#' @param message `chr` The feedback itself. A single non-empty string.
#' @param area `chr` Which part of the system this is about. `"general"` (default)
#'   for system-wide feedback, or a specific section — suggested values:
#'   `r paste(setdiff(.ERI_FEEDBACK_AREAS, "general"), collapse = ", ")`. Free text
#'   is accepted; the value is lower-cased.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The logged ticket (invisibly), as a named list.
#' @examples
#' \dontrun{
#' # System-wide feedback
#' eri_feedback("The onboarding guide's Week 1 felt too fast.")
#'
#' # Feedback about a specific section
#' eri_feedback("ODK sync timed out on the big LF form.", area = "odk")
#' }
#' @seealso [eri_feedback_list()] to read the backlog.
#' @export
eri_feedback <- function(message, area = "general", data_con = NULL) {
  if (!is.character(message) || length(message) != 1L || is.na(message) ||
      !nzchar(trimws(message))) {
    cli::cli_abort("{.arg message} must be a single non-empty string.")
  }
  if (!is.character(area) || length(area) != 1L || is.na(area) || !nzchar(trimws(area))) {
    cli::cli_abort("{.arg area} must be a single non-empty string (e.g. {.val general}).")
  }
  area <- tolower(trimws(area))

  data_con <- .eri_feedback_con(data_con)
  author   <- .eri_analyst_id(data_con)

  # The committed ticket is captured here; the auto-increment id is computed
  # inside the mutate against the freshly-read log so parallel filings each get a
  # distinct id even under a write race (ADR-0002).
  ticket <- NULL
  .eri_yaml_update(data_con, .ERI_FEEDBACK_PATH, function(log) {
    if (is.null(log$entries)) log$entries <- list()
    ids <- vapply(log$entries, function(e) as.integer(e$id %||% 0L), integer(1L))
    next_id <- if (length(ids)) max(ids, 0L) + 1L else 1L
    ticket <<- list(
      id           = next_id,
      submitted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      submitted_by = author,
      area         = area,
      status       = "submitted",
      message      = trimws(message)
    )
    log$entries <- c(log$entries, list(ticket))
    log
  }, default = list(entries = list()))

  id_label <- paste0("#", ticket$id)
  cli::cli_alert_success(
    "Feedback logged as {.field {id_label}} · area {.val {area}} · status {.val submitted}."
  )
  invisible(ticket)
}

#### eri_feedback_list ####

#' List logged feedback
#'
#' Reads the team's feedback backlog from `_feedback/feedback_log.yaml` in the
#' `data/` Azure blob into a tibble, newest-filed last. Optional filters narrow by
#' `area` or `status`.
#'
#' @param area `chr` or `NULL` Filter to one section (e.g. `"odk"`). `NULL` = all.
#' @param status `chr` or `NULL` Filter by status (e.g. `"submitted"`). `NULL` = all.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns `id`, `submitted_at`, `submitted_by`, `area`,
#'   `status`, `message`.
#' @examples
#' \dontrun{
#' eri_feedback_list()
#' eri_feedback_list(area = "odk")
#' eri_feedback_list(status = "submitted")
#' }
#' @seealso [eri_feedback()] to file a ticket.
#' @export
eri_feedback_list <- function(area = NULL, status = NULL, data_con = NULL) {
  data_con <- .eri_feedback_con(data_con)
  log      <- .eri_yaml_read_versioned(data_con, .ERI_FEEDBACK_PATH,
                                       default = list(entries = list()))$data
  entries  <- log$entries %||% list()

  empty <- tibble::tibble(
    id           = integer(),
    submitted_at = character(),
    submitted_by = character(),
    area         = character(),
    status       = character(),
    message      = character()
  )

  if (length(entries) == 0L) {
    cli::cli_inform("No feedback logged yet.")
    return(empty)
  }

  if (!is.null(area)) {
    area <- tolower(area)
    entries <- Filter(function(e) identical(tolower(e$area %||% ""), area), entries)
  }
  if (!is.null(status)) {
    status <- tolower(status)
    entries <- Filter(function(e) identical(tolower(e$status %||% ""), status), entries)
  }

  if (length(entries) == 0L) {
    cli::cli_inform("No feedback matches the specified filters.")
    return(empty)
  }

  .na_chr <- function(x) if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x)
  .na_int <- function(x) if (is.null(x) || length(x) == 0L) NA_integer_  else as.integer(x)

  tibble::tibble(
    id           = vapply(entries, function(e) .na_int(e$id),           integer(1L)),
    submitted_at = vapply(entries, function(e) .na_chr(e$submitted_at), character(1L)),
    submitted_by = vapply(entries, function(e) .na_chr(e$submitted_by), character(1L)),
    area         = vapply(entries, function(e) .na_chr(e$area),         character(1L)),
    status       = vapply(entries, function(e) .na_chr(e$status),       character(1L)),
    message      = vapply(entries, function(e) .na_chr(e$message),      character(1L))
  )
}
