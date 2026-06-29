#### eri_feedback — in-package feedback / ticket log ####
#
# A durable, attributable backlog of feedback from DAs and Epis, kept in the
# `data/` blob as a single YAML log. `eri_feedback()` is the **capture** side:
# it appends a ticket with the verified author identity (ADR-0003) and a
# concurrency-safe write (ADR-0002). `eri_feedback_list()` reads it. The triage
# side -- `eri_feedback_status()` moves a ticket through the lifecycle (with an
# audit trail) and `eri_feedback_board()` summarises the backlog -- lives here
# too (ADR-0014). All writes go through `.eri_yaml_update()`.

.ERI_FEEDBACK_PATH <- "_feedback/feedback_log.yaml"

# Suggested `area` values. Free text is accepted (the log is meant to be easy to
# file into), but these are the sections we triage by; "general" = not specific.
.ERI_FEEDBACK_AREAS <- c(
  "general", "ingest", "dq", "catalog", "query", "odk", "cmr",
  "reporting", "research", "spatial", "auth", "docs", "other"
)

# The ticket status lifecycle. Unlike `area`, this IS a controlled set: a typo
# would make the board meaningless. Ordered for board/summary display; tickets
# are born "submitted" (see eri_feedback()).
.ERI_FEEDBACK_STATUSES <- c("submitted", "planned", "in_progress", "fixed", "declined")

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
  # Never reject feedback over a typo'd area, but nudge toward the triage
  # vocabulary so it self-converges (avoids "odk" vs "odk-sync" fragmentation).
  if (!area %in% .ERI_FEEDBACK_AREAS) {
    known_areas <- .ERI_FEEDBACK_AREAS
    cli::cli_inform(c(
      "i" = "Filing under a new area {.val {area}}.",
      "*" = "Known areas: {.val {known_areas}}."
    ))
  }

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
#' `data/` Azure blob into a tibble, in the order tickets were filed. Optional
#' filters narrow by `area` or `status`.
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

#### eri_feedback_status ####

#' Move a feedback ticket through the triage lifecycle
#'
#' Updates the `status` of one ticket in `_feedback/feedback_log.yaml` and records
#' an audit-trail entry of the transition (from, to, who, when, and an optional
#' note). This is the triage side of the feedback log (ADR-0014): file a ticket
#' with [eri_feedback()], then move it as you work it — typically
#' `submitted` -> `planned` -> `in_progress` -> `fixed` (or `declined`).
#'
#' The change records the **verified** signed-in actor (ADR-0003) and is
#' concurrency-safe (ADR-0002). The status is validated against the controlled
#' lifecycle; an unknown id aborts without writing.
#'
#' @param id `int` The ticket id (as shown by [eri_feedback()] / [eri_feedback_list()]).
#' @param status `chr` The new status. One of `r paste(.ERI_FEEDBACK_STATUSES, collapse = ", ")`.
#' @param note `chr` or `NULL` An optional one-line note recorded with the transition
#'   (e.g. a PR number or a reason for `declined`).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The updated ticket (invisibly), as a named list (including its `history`).
#' @examples
#' \dontrun{
#' eri_feedback_status(142, "planned")
#' eri_feedback_status(142, "fixed", note = "shipped in #251")
#' eri_feedback_status(7, "declined", note = "works as intended")
#' }
#' @seealso [eri_feedback()] to file, [eri_feedback_board()] to summarise.
#' @export
eri_feedback_status <- function(id, status, note = NULL, data_con = NULL) {
  if (length(id) != 1L || is.na(suppressWarnings(as.integer(id)))) {
    cli::cli_abort("{.arg id} must be a single ticket id (an integer).")
  }
  id       <- as.integer(id)
  id_label <- paste0("#", id)
  status   <- tolower(as.character(status))
  valid_statuses <- .ERI_FEEDBACK_STATUSES
  if (!status %in% valid_statuses) {
    cli::cli_abort(c(
      "{.arg status} {.val {status}} is not a valid status.",
      "i" = "Valid statuses: {.val {valid_statuses}}."
    ))
  }
  if (!is.null(note) && (length(note) != 1L || !is.character(note))) {
    cli::cli_abort("{.arg note} must be a single string or {.code NULL}.")
  }

  data_con <- .eri_feedback_con(data_con)
  actor    <- .eri_analyst_id(data_con)
  now      <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  # Find + update by id inside the mutate so the change is race-safe and an
  # unknown id aborts (propagating out of .eri_yaml_update without writing).
  updated <- NULL
  from    <- NULL
  .eri_yaml_update(data_con, .ERI_FEEDBACK_PATH, function(log) {
    entries <- log$entries %||% list()
    idx <- which(vapply(entries, function(e) identical(as.integer(e$id %||% NA_integer_), id),
                        logical(1L)))
    if (length(idx) == 0L) {
      cli::cli_abort(c(
        "No feedback ticket {.field {id_label}} found.",
        "i" = "List tickets with {.fn eri_feedback_list}."
      ))
    }
    e        <- entries[[idx[[1L]]]]
    from    <<- e$status %||% "submitted"
    e$status <- status
    e$updated_at <- now
    e$updated_by <- actor
    transition <- list(from = from, to = status, by = actor, at = now,
                       note = if (is.null(note)) NA_character_ else note)
    e$history <- c(e$history %||% list(), list(transition))
    entries[[idx[[1L]]]] <- e
    updated <<- e
    log$entries <- entries
    log
  }, default = list(entries = list()))

  cli::cli_alert_success(
    "Ticket {.field {id_label}}: {.val {from}} → {.val {status}} (by {actor})."
  )
  invisible(updated)
}

#### eri_feedback_board ####

#' Summarise the feedback backlog by status
#'
#' Prints a one-line-per-status count of the tickets in
#' `_feedback/feedback_log.yaml`, in lifecycle order — the triage-meeting view of
#' the board. Returns the full backlog tibble (as [eri_feedback_list()]) invisibly
#' so it can be piped or inspected.
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, the backlog tibble from [eri_feedback_list()].
#' @examples
#' \dontrun{
#' eri_feedback_board()
#' }
#' @seealso [eri_feedback_status()] to move a ticket, [eri_feedback_list()] for the rows.
#' @export
eri_feedback_board <- function(data_con = NULL) {
  data_con <- .eri_feedback_con(data_con)
  tbl <- suppressMessages(eri_feedback_list(data_con = data_con))

  if (nrow(tbl) == 0L) {
    cli::cli_inform("No feedback logged yet.")
    return(invisible(tbl))
  }

  counts <- vapply(.ERI_FEEDBACK_STATUSES,
                   function(s) sum(tbl$status == s, na.rm = TRUE), integer(1L))
  # Any statuses not in the known lifecycle (shouldn't happen, but don't hide them).
  other <- setdiff(unique(stats::na.omit(tbl$status)), .ERI_FEEDBACK_STATUSES)

  cli::cli_h3("Feedback board ({nrow(tbl)} ticket{?s})")
  for (s in .ERI_FEEDBACK_STATUSES) {
    cli::cli_text("{.strong {counts[[s]]}} {s}")
  }
  for (s in other) {
    n <- sum(tbl$status == s, na.rm = TRUE)
    cli::cli_text("{.strong {n}} {s} {.emph (unknown status)}")
  }
  invisible(tbl)
}
