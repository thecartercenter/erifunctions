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
#' @param context `list` or `NULL` Optional named list scoping the ticket to a
#'   specific dataset or object (e.g.
#'   `list(country = "sdn", disease = "oncho", data_source = "programmatic",
#'   data_type = "treatment", period = "202605", schema = "sdn_oncho_programmatic_treatment")`).
#'   Stored as a sub-block on the ticket, not new formal arguments, so any area
#'   can scope its tickets differently without a signature change. `NULL`
#'   (default) omits it entirely — a ticket with no `context` looks exactly
#'   like one filed before this feature existed.
#' @param attachment `chr` or `NULL` Optional path to a local file to attach —
#'   e.g. a full schema override for a `dq` ticket. Uploaded to
#'   `_feedback/attachments/{token}/{basename}` in the `data/` blob **before**
#'   the ticket is logged, so a failed *upload* never leaves a ticket
#'   referencing a file that isn't actually there. The reverse is a known,
#'   accepted, low-probability gap: if the upload succeeds but the log append
#'   then fails (e.g. exhausts its concurrency retries), the blob is left
#'   orphaned with no ticket pointing at it — you'll see the error (nothing
#'   silently succeeds for you), but there's no automatic cleanup sweep for
#'   the orphaned attachment. `NULL` (default): no attachment.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The logged ticket (invisibly), as a named list.
#' @examples
#' \dontrun{
#' # System-wide feedback
#' eri_feedback("The onboarding guide's Week 1 felt too fast.")
#'
#' # Feedback about a specific section
#' eri_feedback("ODK sync timed out on the big LF form.", area = "odk")
#'
#' # Scoped to a dataset, with an attachment (see eri_dq_schema_submit() for
#' # the DA-facing wrapper that packages this automatically for schema edits)
#' eri_feedback("District list is missing a valid admin name.", area = "dq",
#'              context = list(country = "sdn", disease = "oncho"),
#'              attachment = "sdn_oncho_programmatic_treatment.yaml")
#' }
#' @seealso [eri_feedback_list()] to read the backlog, [eri_dq_schema_submit()]
#'   for the DQ-schema-specific wrapper.
#' @export
eri_feedback <- function(message, area = "general", context = NULL, attachment = NULL,
                          data_con = NULL) {
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
  if (!is.null(context) && !is.list(context)) {
    cli::cli_abort("{.arg context} must be a named list, or {.code NULL}.")
  }
  if (!is.null(context)) {
    # list()'s constructor keeps a NULL-valued element (unlike assigning NULL
    # into an existing list, which removes it), and yaml::write_yaml() renders
    # that as a literal `~`. Scrub centrally, here, rather than leaving every
    # caller to rediscover this -- context is meant to be a general mechanism
    # other areas reuse (e.g. eri_dq_schema_submit()'s research-lane calls,
    # which have no data_type), not a one-off worked around by one caller.
    context <- Filter(Negate(is.null), context)
  }
  if (!is.null(attachment)) {
    if (!is.character(attachment) || length(attachment) != 1L || is.na(attachment)) {
      cli::cli_abort("{.arg attachment} must be a single path, or {.code NULL}.")
    }
    if (!file.exists(attachment)) {
      cli::cli_abort("{.arg attachment} not found: {.path {attachment}}")
    }
  }

  data_con <- .eri_feedback_con(data_con)
  author   <- .eri_analyst_id(data_con)

  # Upload the attachment BEFORE the log append: a failed upload aborts here,
  # before any ticket exists, rather than leaving a ticket whose `attachment`
  # field points at a blob that was never actually written. Keyed by a token
  # generated up front (timestamp + a short random suffix) rather than the
  # ticket's own auto-increment id -- that id is only assigned inside the log
  # mutate below (racing with other filers), so it isn't known yet, and tying
  # the attachment path to it would mean either uploading after the log write
  # (the ordering this comment says to avoid) or risking a mismatch on retry.
  attachment_path <- NULL
  if (!is.null(attachment)) {
    token <- paste0(
      format(Sys.time(), "%Y%m%dT%H%M%OS3Z", tz = "UTC"), "-",
      paste(sample(c(0:9, letters), 4L, replace = TRUE), collapse = "")
    )
    attachment_path <- paste0("_feedback/attachments/", token, "/", basename(attachment))
    .eri_blob_write(data_con, attachment, attachment_path)
  }

  # The committed ticket is captured here; the auto-increment id is computed
  # inside the mutate against the freshly-read log so parallel filings each get a
  # distinct id even under a write race (ADR-0002).
  ticket <- NULL
  .eri_yaml_update(data_con, .ERI_FEEDBACK_PATH, function(log) {
    if (is.null(log$entries)) log$entries <- list()
    ids <- vapply(log$entries, function(e) as.integer(e$id %||% 0L), integer(1L))
    next_id <- if (length(ids)) max(ids, 0L) + 1L else 1L
    entry <- list(
      id           = next_id,
      submitted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      submitted_by = author,
      area         = area,
      status       = "submitted",
      message      = trimws(message)
    )
    # Only present on the entry when actually used, so a ticket filed without
    # them is byte-for-byte the same shape a pre-this-feature ticket would be.
    if (!is.null(context))         entry$context    <- context
    if (!is.null(attachment_path)) entry$attachment <- attachment_path
    ticket <<- entry
    log$entries <- c(log$entries, list(entry))
    log
  }, default = list(entries = list()))

  id_label <- paste0("#", ticket$id)
  cli::cli_alert_success(
    "Feedback logged as {.field {id_label}} · area {.val {area}} · status {.val submitted}."
  )
  if (!is.null(attachment_path)) {
    cli::cli_alert_info("Attachment: {.path {attachment_path}}")
  }
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
#'   `status`, `message`, `context` (a list-column: `NULL` or a named list per
#'   ticket), `attachment` (blob path, or `NA` if none).
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
    message      = character(),
    context      = list(),
    attachment   = character()
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
    message      = vapply(entries, function(e) .na_chr(e$message),      character(1L)),
    context      = lapply(entries, function(e) e$context %||% NULL),
    attachment   = vapply(entries, function(e) .na_chr(e$attachment),   character(1L))
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
  id_num <- suppressWarnings(as.numeric(id))
  if (length(id) != 1L || is.na(id_num) || id_num != round(id_num) || id_num < 1) {
    cli::cli_abort("{.arg id} must be a single positive integer ticket id.")
  }
  id       <- as.integer(id_num)
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
  # unknown id aborts (propagating out of .eri_yaml_update without writing). The
  # `default` below only satisfies the shared signature -- a status change
  # presupposes the log exists, and an absent log aborts on "no id" anyway.
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
    "Ticket {.field {id_label}}: {.val {from}} → {.val {status}} (by {.val {actor}})."
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

#### eri_feedback_report ####

.ERI_FEEDBACK_OPEN   <- c("submitted", "planned", "in_progress")
.ERI_FEEDBACK_CLOSED <- c("fixed", "declined")

# A ticket's status, normalised: NULL or NA falls back to "submitted" (matches
# how eri_feedback_board() defends against odd statuses).
#' @keywords internal
.eri_feedback_status_of <- function(e) {
  s <- e$status %||% "submitted"
  if (length(s) != 1L || is.na(s)) "submitted" else tolower(s)
}

# Parse an ISO-8601 "...Z" timestamp to POSIXct (UTC); NA on empty/unparseable.
# Tightly matches what eri_feedback() writes; both sides of the window comparison
# are absolute POSIXct instants, so the digest cutoff is timezone-independent.
#' @keywords internal
.eri_parse_ts <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x) || !nzchar(x)) return(as.POSIXct(NA))
  suppressWarnings(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
}

# The closing note = the note on the ticket's most recent history transition.
#' @keywords internal
.eri_feedback_last_note <- function(e) {
  h <- e$history
  if (is.null(h) || length(h) == 0L) return(NA_character_)
  note <- h[[length(h)]]$note
  if (is.null(note) || length(note) == 0L || is.na(note)) NA_character_ else as.character(note)
}

# Split the entries into the report's three buckets relative to a `since` cutoff.
#' @keywords internal
.eri_feedback_buckets <- function(entries, since_days) {
  cutoff    <- Sys.time() - since_days * 86400
  status_of <- .eri_feedback_status_of

  ord <- function(es, ts_field, decreasing) {
    if (length(es) == 0L) return(es)
    ts <- as.numeric(vapply(es, function(e) {
      t <- .eri_parse_ts(e[[ts_field]] %||% e$submitted_at %||% "")
      if (is.na(t)) 0 else as.numeric(t)
    }, numeric(1L)))
    es[order(ts, decreasing = decreasing)]
  }

  is_new <- vapply(entries, function(e) {
    ts <- .eri_parse_ts(e$submitted_at %||% ""); !is.na(ts) && ts >= cutoff
  }, logical(1L))
  is_closed_recent <- vapply(entries, function(e) {
    status_of(e) %in% .ERI_FEEDBACK_CLOSED && {
      ts <- .eri_parse_ts(e$updated_at %||% e$submitted_at %||% "")
      !is.na(ts) && ts >= cutoff
    }
  }, logical(1L))
  is_open <- vapply(entries, function(e) status_of(e) %in% .ERI_FEEDBACK_OPEN, logical(1L))

  # Open backlog ordered by lifecycle stage, then id.
  open <- entries[is_open]
  if (length(open) > 0L) {
    stage <- match(vapply(open, status_of, character(1L)), .ERI_FEEDBACK_STATUSES)
    ids   <- vapply(open, function(e) as.integer(e$id %||% 0L), integer(1L))
    open  <- open[order(stage, ids)]
  }

  list(
    new    = ord(entries[is_new],           "submitted_at", decreasing = TRUE),
    closed = ord(entries[is_closed_recent], "updated_at",   decreasing = TRUE),
    open   = open
  )
}

#' Write a weekly feedback report (HTML or markdown)
#'
#' Renders the feedback backlog from `_feedback/feedback_log.yaml` to a
#' self-contained file: a status **board**, then a weekly digest — **new** tickets
#' filed within `since_days`, tickets **closed** (fixed/declined) within
#' `since_days` with their closing note, and the **open** backlog in lifecycle
#' order. Built for a quick standing review so the team stays current (ADR-0014).
#'
#' @param file `chr` or `NULL` Output path. If `NULL`, writes
#'   `feedback-report-<date>.<ext>` in the working directory (a same-day re-run
#'   overwrites it).
#' @param format `chr` `"html"` (default, self-contained, open in a browser) or
#'   `"md"` (GitHub-flavoured markdown).
#' @param since_days `num` The digest window in days. Default `7` (a weekly report).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The output file path (invisibly).
#' @examples
#' \dontrun{
#' eri_feedback_report()                       # feedback-report-<today>.html
#' eri_feedback_report(format = "md", since_days = 14)
#' }
#' @seealso [eri_feedback_board()] for the console summary, [eri_feedback_status()] to triage.
#' @export
eri_feedback_report <- function(file = NULL, format = c("html", "md"),
                                since_days = 7, data_con = NULL) {
  format <- match.arg(format)
  if (!is.numeric(since_days) || length(since_days) != 1L || is.na(since_days) || since_days < 0) {
    cli::cli_abort("{.arg since_days} must be a single non-negative number.")
  }

  data_con <- .eri_feedback_con(data_con)
  # Read the raw entries (not eri_feedback_list()): the report needs `updated_at`
  # and the nested `history` list, which the flat list tibble deliberately omits.
  log      <- .eri_yaml_read_versioned(data_con, .ERI_FEEDBACK_PATH,
                                       default = list(entries = list()))$data
  entries  <- log$entries %||% list()

  ext  <- if (format == "html") "html" else "md"
  if (is.null(file)) {
    file <- file.path(getwd(), paste0("feedback-report-", format(Sys.Date()), ".", ext))
  }

  content <- if (format == "html") {
    .eri_feedback_render_html(entries, since_days)
  } else {
    .eri_feedback_render_md(entries, since_days)
  }
  writeLines(content, file, useBytes = TRUE)

  n_open <- sum(vapply(entries, function(e) {
    .eri_feedback_status_of(e) %in% .ERI_FEEDBACK_OPEN
  }, logical(1L)))
  cli::cli_alert_success(
    "Feedback report ({length(entries)} ticket{?s} · {n_open} open) written to {.path {file}}."
  )
  invisible(file)
}

# Shared bits ------------------------------------------------------------------

#' @keywords internal
.eri_feedback_counts <- function(entries) {
  statuses <- vapply(entries, .eri_feedback_status_of, character(1L))
  vapply(.ERI_FEEDBACK_STATUSES, function(s) sum(statuses == s), integer(1L))
}

#' @keywords internal
.eri_html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x
}

# HTML renderer ----------------------------------------------------------------
#
# Deliberately hand-rolled rather than reusing eri_report_html(): that helper
# hard-requires a Quarto install (so a one-line standing report would fail for a
# user without Quarto) and its section/table/figure model doesn't fit a
# status-bucketed digest. The CSS below uses the Carter Center *org* palette
# (navy #001737 / green #00873f) for a shared artifact — intentionally not the
# package's eri_brand_colors(), which brands data products.
#' @keywords internal
.eri_feedback_render_html <- function(entries, since_days) {
  esc      <- .eri_html_escape
  gen      <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
  counts   <- .eri_feedback_counts(entries)
  n_total  <- length(entries)
  n_open   <- sum(counts[.ERI_FEEDBACK_OPEN])

  css <- paste(
    "body{font-family:'Source Sans 3',system-ui,Segoe UI,Roboto,sans-serif;color:#1c2638;",
    "max-width:960px;margin:2rem auto;padding:0 1.2rem;line-height:1.45}",
    "h1{font-family:'Source Serif 4',Georgia,serif;color:#001737;margin-bottom:.2rem}",
    "h2{font-family:'Source Serif 4',Georgia,serif;color:#001737;margin-top:2rem;",
    "border-bottom:1px solid #dde6ef;padding-bottom:.3rem}",
    ".meta{color:#5b6678;margin-bottom:1rem}",
    ".board{display:flex;gap:.5rem;flex-wrap:wrap;margin:1rem 0}",
    ".chip{border-radius:999px;padding:.25rem .7rem;font-size:.85rem;font-weight:600;",
    "background:#f3f6fa;border:1px solid #dde6ef;color:#1c2638}",
    ".chip b{color:#001737}",
    ".chip.fixed{background:#e7f5ec;border-color:#cfe6d6;color:#00873f}",
    "table{border-collapse:collapse;width:100%;margin:.5rem 0;font-size:.92rem}",
    "th,td{text-align:left;padding:.45rem .6rem;border-bottom:1px solid #eef2f7;vertical-align:top}",
    "th{color:#5b6678;font-size:.78rem;text-transform:uppercase;letter-spacing:.04em}",
    "td.id{font-variant-numeric:tabular-nums;color:#135aa6;font-weight:700;white-space:nowrap}",
    ".tag{font-size:.74rem;font-weight:700;border-radius:6px;padding:.1rem .4rem;background:#eef2f7;color:#41617f}",
    ".empty{color:#5b6678;font-style:italic}",
    sep = ""
  )

  row <- function(cells) paste0("<tr>", paste0(cells, collapse = ""), "</tr>")
  td  <- function(x, cls = "") paste0("<td", if (nzchar(cls)) paste0(" class='", cls, "'") else "", ">", x, "</td>")
  th  <- function(xs) paste0("<tr>", paste0("<th>", xs, "</th>", collapse = ""), "</tr>")

  fmt_date <- function(x) { d <- substr(x %||% "", 1L, 10L); if (is.na(d) || !nzchar(d)) "—" else d }

  tbl_new <- function(es) {
    if (length(es) == 0L) return("<p class='empty'>Nothing new this week.</p>")
    rows <- vapply(es, function(e) row(c(
      td(paste0("#", e$id), "id"), td(paste0("<span class='tag'>", esc(e$area), "</span>")),
      td(esc(e$message)), td(esc(e$submitted_by)), td(fmt_date(e$submitted_at))
    )), character(1L))
    paste0("<table>", th(c("Ticket", "Area", "Feedback", "From", "Filed")),
           paste0(rows, collapse = ""), "</table>")
  }
  tbl_closed <- function(es) {
    if (length(es) == 0L) return("<p class='empty'>Nothing closed this week.</p>")
    rows <- vapply(es, function(e) {
      note <- .eri_feedback_last_note(e); note <- if (is.na(note)) "—" else esc(note)
      row(c(
        td(paste0("#", e$id), "id"), td(paste0("<span class='tag'>", esc(tolower(e$status)), "</span>")),
        td(esc(e$message)), td(note), td(fmt_date(e$updated_at %||% e$submitted_at))
      ))
    }, character(1L))
    paste0("<table>", th(c("Ticket", "Status", "Feedback", "Note", "When")),
           paste0(rows, collapse = ""), "</table>")
  }
  tbl_open <- function(es) {
    if (length(es) == 0L) return("<p class='empty'>Nothing open — backlog clear.</p>")
    rows <- vapply(es, function(e) row(c(
      td(paste0("#", e$id), "id"), td(paste0("<span class='tag'>", esc(tolower(e$status %||% "submitted")), "</span>")),
      td(paste0("<span class='tag'>", esc(e$area), "</span>")), td(esc(e$message)),
      td(fmt_date(e$submitted_at)), td(fmt_date(e$updated_at))
    )), character(1L))
    paste0("<table>", th(c("Ticket", "Status", "Area", "Feedback", "Filed", "Updated")),
           paste0(rows, collapse = ""), "</table>")
  }

  if (n_total == 0L) {
    body <- "<p class='empty'>No feedback logged yet.</p>"
  } else {
    b <- .eri_feedback_buckets(entries, since_days)
    chips <- paste0(vapply(.ERI_FEEDBACK_STATUSES, function(s) {
      cls <- if (s == "fixed") "chip fixed" else "chip"
      paste0("<span class='", cls, "'><b>", counts[[s]], "</b> ", s, "</span>")
    }, character(1L)), collapse = "")
    body <- paste0(
      "<div class='board'>", chips, "</div>",
      "<h2>New this week (", length(b$new), ")</h2>", tbl_new(b$new),
      "<h2>Closed this week (", length(b$closed), ")</h2>", tbl_closed(b$closed),
      "<h2>Open backlog (", length(b$open), ")</h2>", tbl_open(b$open)
    )
  }

  paste0(
    "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>",
    "<title>ERI feedback backlog</title>",
    "<link href='https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@600;700&",
    "family=Source+Sans+3:wght@400;600;700&display=swap' rel='stylesheet'>",
    "<style>", css, "</style></head><body>",
    "<h1>ERI feedback backlog</h1>",
    "<p class='meta'>Generated ", gen, " · ", n_total, " ticket", if (n_total == 1L) "" else "s",
    " · ", n_open, " open · last ", since_days, " days highlighted</p>",
    body, "</body></html>"
  )
}

# Markdown renderer ------------------------------------------------------------

#' @keywords internal
.eri_feedback_render_md <- function(entries, since_days) {
  gen     <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
  counts  <- .eri_feedback_counts(entries)
  n_total <- length(entries)
  n_open  <- sum(counts[.ERI_FEEDBACK_OPEN])

  # Escape only the table-structural characters (pipes/newlines) so a message
  # can't break the row. Inline markdown in a message (e.g. `*`, backticks) is
  # left as-is by design — md output is plaintext, so this is fidelity not safety.
  cell <- function(x) {
    x <- as.character(x %||% "")
    x <- gsub("\\|", "\\\\|", x); x <- gsub("[\r\n]+", " ", x)
    if (!nzchar(x)) "—" else x
  }
  fmt_date <- function(x) { d <- substr(x %||% "", 1L, 10L); if (is.na(d) || !nzchar(d)) "—" else d }
  mdrow <- function(cells) paste0("| ", paste0(cells, collapse = " | "), " |")

  header <- c(
    "# ERI feedback backlog",
    "",
    paste0("_Generated ", gen, " · ", n_total, " ticket", if (n_total == 1L) "" else "s",
           " · ", n_open, " open · last ", since_days, " days highlighted_"),
    ""
  )

  if (n_total == 0L) return(c(header, "_No feedback logged yet._"))

  b <- .eri_feedback_buckets(entries, since_days)
  board <- paste0("**Board:** ",
    paste0(vapply(.ERI_FEEDBACK_STATUSES, function(s) paste0("**", counts[[s]], "** ", s),
                  character(1L)), collapse = " · "))

  sec_new <- if (length(b$new) == 0L) "_Nothing new this week._" else c(
    mdrow(c("#", "Area", "Feedback", "From", "Filed")),
    mdrow(rep("---", 5L)),
    vapply(b$new, function(e) mdrow(c(paste0("#", e$id), cell(e$area), cell(e$message),
                                      cell(e$submitted_by), fmt_date(e$submitted_at))), character(1L))
  )
  sec_closed <- if (length(b$closed) == 0L) "_Nothing closed this week._" else c(
    mdrow(c("#", "Status", "Feedback", "Note", "When")),
    mdrow(rep("---", 5L)),
    vapply(b$closed, function(e) mdrow(c(paste0("#", e$id), cell(tolower(e$status)), cell(e$message),
                                         cell(.eri_feedback_last_note(e)),
                                         fmt_date(e$updated_at %||% e$submitted_at))), character(1L))
  )
  sec_open <- if (length(b$open) == 0L) "_Nothing open — backlog clear._" else c(
    mdrow(c("#", "Status", "Area", "Feedback", "Filed", "Updated")),
    mdrow(rep("---", 6L)),
    vapply(b$open, function(e) mdrow(c(paste0("#", e$id), cell(tolower(e$status %||% "submitted")),
                                       cell(e$area), cell(e$message),
                                       fmt_date(e$submitted_at), fmt_date(e$updated_at))), character(1L))
  )

  c(header, board, "",
    paste0("## New this week (", length(b$new), ")"),    "", sec_new, "",
    paste0("## Closed this week (", length(b$closed), ")"), "", sec_closed, "",
    paste0("## Open backlog (", length(b$open), ")"),    "", sec_open)
}
