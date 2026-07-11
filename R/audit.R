#### eri_audit — chronological event-level audit trail ####
#
# Phase 5 of the pilot-feedback-driven DQ workflow redesign (see docs/roadmap.md's
# "DQ workflow redesign" entry). eri_logs() flattens one row per log FILE, which is
# right for a triage backlog (newest-first, "what needs my attention"); an audit
# trail needs one row per EVENT -- each flag's own resolution is an event with its
# own actor/timestamp, nested inside the dq_flags YAML, and a triage close-out is a
# separate event again. This file is the one place that explodes a log file's
# envelope into event rows; eri_audit() itself is otherwise just eri_logs()'s
# discovery (.eri_logs_dirs()) plus re-reading each YAML for detail.

# Explodes ONE parsed log YAML into zero or more audit-timeline event rows.
# Different operations carry different envelope shapes (the generic op-log
# envelope from .eri_write_log(), the dq_flags envelope with its nested
# per-flag records, eri_approve_cmr()'s dq_reviewed cross-references) -- this
# is the one place that knows how to turn each into timeline rows, so
# eri_audit() itself doesn't need to care.
#' @keywords internal
.eri_audit_events <- function(entry, log_path) {
  axes <- .eri_log_axes(entry, log_path)
  # Identity for the file this entry's operation actually ran against (Phase 1)
  # -- one hash per entry, not per event, since it describes the run/file the
  # whole entry is about. Carried onto every event row so a power user can
  # trace which exact bytes backed a given step without opening the raw YAML
  # via log_path -- the "walk a value back to its source bytes" half of the
  # audit story that source_hash was built for.
  source_hash <- entry$source_hash %||% NA_character_
  mk <- function(timestamp, event, actor, detail, forced = FALSE) {
    list(timestamp = .eri_na_chr(timestamp), event = event, actor = .eri_na_chr(actor),
         detail = if (is.null(detail)) NA_character_ else detail, log_path = log_path,
         country = axes$country, disease = axes$disease,
         data_source = axes$data_source, data_type = axes$data_type,
         period = axes$period, source_hash = source_hash, forced = isTRUE(forced))
  }

  events <- list()
  op <- entry$operation %||% NA_character_

  if (identical(op, "dq_flags")) {
    n_flags <- entry$n_flags %||% length(entry$flags %||% list())
    schema_bit <- if (!is.null(entry$schema_source) && !is.na(entry$schema_source)) {
      paste0(" (schema: ", entry$schema_source, ")")
    } else ""
    events[[length(events) + 1L]] <- mk(
      entry$timestamp, "dq_flags", entry$analyst,
      paste0(n_flags, " flag", if (identical(as.integer(n_flags), 1L)) "" else "s", schema_bit)
    )
    for (f in entry$flags %||% list()) {
      resolved_at <- f$resolved_at
      if (!is.null(resolved_at) && !is.na(resolved_at) && nzchar(resolved_at)) {
        note_bit <- if (!is.null(f$note) && !is.na(f$note) && nzchar(f$note)) paste0(" (", f$note, ")") else ""
        events[[length(events) + 1L]] <- mk(
          resolved_at, "flag_resolved", f$resolved_by,
          paste0("flag #", f$index %||% NA_integer_, " -> ", f$status %||% NA_character_, note_bit)
        )
      }
    }
  } else if (!is.null(entry$operation) || !is.null(entry$parameters) || !is.null(entry$steps)) {
    # Generic op-log envelope: eri_ingest, eri_stage_cmr, eri_split_cmr,
    # eri_approve, eri_approve_cmr, eri_split_cmr_dryrun, ... -- one event for
    # the whole entry (not one per internal `step`, which would fragment the
    # timeline into noise the vision doesn't ask for). Gated on the RAW
    # `entry$operation` here, not the `op` local (which %||%-coalesces a
    # missing operation to NA_character_, a non-NULL value) -- an entry with
    # none of these three fields at all (an unrecognized/malformed envelope)
    # falls through and produces no event, rather than a garbage all-NA row.
    ts <- entry$completed_at %||% entry$timestamp %||% entry$started_at
    detail <- NULL
    if (!is.null(entry$error)) {
      detail <- as.character(entry$error)
    } else if (identical(op, "eri_split_cmr") && !is.null(entry$plan)) {
      detail <- paste(
        vapply(entry$plan, function(p) {
          paste0(p$sheet %||% "?", " -> ", basename(p$dest %||% "?"), " (", p$n_rows %||% "?", " rows)")
        }, character(1L)),
        collapse = "; "
      )
    } else if (identical(op, "eri_approve_cmr")) {
      measures_bit <- if (!is.null(entry$measures)) paste(unlist(entry$measures), collapse = ", ") else NULL
      dq_bit <- if (!is.null(entry$dq_reviewed) && length(entry$dq_reviewed) > 0L) {
        paste0("dq_reviewed: ", paste(basename(unlist(entry$dq_reviewed)), collapse = ", "))
      } else NULL
      # A forced approval bypassed one or more outstanding measures -- surface
      # exactly what and why, since this is the event eri_audit() renders
      # prominently (see print.eri_audit_trail()).
      forced_bit <- if (isTRUE(entry$forced)) {
        bypassed_bit <- if (!is.null(entry$bypassed) && length(entry$bypassed) > 0L) {
          paste0("bypassed: ", paste(
            vapply(entry$bypassed, function(b) paste0(b$disease %||% "?", "/", b$data_type %||% "?",
                                                       " (", b$issue %||% "?", ")"),
                   character(1L)),
            collapse = ", "
          ))
        } else NULL
        paste(Filter(Negate(is.null), list(
          paste0("justification: ", entry$justification %||% "?"), bypassed_bit
        )), collapse = " -- ")
      } else NULL
      detail <- paste(Filter(Negate(is.null), list(measures_bit, dq_bit, forced_bit)), collapse = " -- ")
      if (!nzchar(detail)) detail <- NULL
    } else if (!is.null(entry$files) && length(entry$files) > 0L) {
      detail <- paste(basename(unlist(entry$files)), collapse = ", ")
    }
    events[[length(events) + 1L]] <- mk(ts, op %||% "operation", entry$analyst, detail,
                                        forced = isTRUE(entry$forced))
  }

  # A triage close-out (eri_logs_resolve()) can sit on ANY entry type above --
  # one more event, regardless of what the entry itself was. A forced bypass
  # (eri_logs_resolve(..., forced = TRUE), from eri_approve_cmr()'s force
  # path) gets its own event name and the `forced` marker -- it closed the
  # entry, but it was never actually reviewed, and that distinction matters.
  if (!is.null(entry$triage) && isTRUE(entry$triage$handled)) {
    is_forced <- isTRUE(entry$triage$forced)
    events[[length(events) + 1L]] <- mk(
      entry$triage$handled_at, if (is_forced) "log_resolved (forced bypass)" else "log_resolved",
      entry$triage$handled_by, entry$triage$note, forced = is_forced
    )
  }

  events
}

#' @keywords internal
.eri_audit_empty <- function() {
  out <- tibble::tibble(
    timestamp = character(), event = character(), actor = character(),
    detail = character(), log_path = character(), country = character(),
    disease = character(), data_source = character(), data_type = character(),
    period = character(), source_hash = character(), forced = logical()
  )
  class(out) <- c("eri_audit_trail", class(out))
  out
}

# Parses the ISO-8601 UTC timestamps this package's own writers emit
# ("%Y-%m-%dT%H:%M:%SZ", format(Sys.time(), ...)) to POSIXct for a genuine
# chronological sort. A raw string sort is only reliable while every
# timestamp shares identical precision: "." sorts before "Z" in ASCII, so a
# fractional-second stamp (a few other writers in this package already use
# one, e.g. feedback.R's %OS3Z) would otherwise sort BEFORE a whole-second
# stamp that is actually later. %OS accepts an optional fractional part, so
# this handles both forms; unparseable strings become NA and sort last.
#' @keywords internal
.eri_audit_parse_ts <- function(x) {
  suppressWarnings(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
}

#' Reconstruct a chronological audit trail for a dataset
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Walks every log entry across the given axes ([eri_logs()]'s own discovery
#' logic) and explodes each into one row per meaningful event --
#' a file staged, a CMR workbook split (with its routing plan), a DQ check run,
#' each individual flag resolved, a whole log entry closed out via
#' [eri_logs_resolve()], an approval -- into a single chronological timeline,
#' **oldest first** (a timeline reads forward; the triage backlog in
#' [eri_logs()] reads newest-first — different jobs, different order).
#'
#' [eri_approve_cmr()] already records which `dq_flags` entries backed each
#' approval (its `dq_reviewed` field); this is the function that cashes that
#' in — `log_path` stays on every row so a power user can still drill into the
#' raw YAML, but nobody should *have* to follow paths by hand to answer "what
#' happened to this dataset, and who signed off on it."
#'
#' A forced approval ([eri_approve_cmr()]'s `force = TRUE`) and the bypass
#' annotations it leaves on the measures it overrode both render prominently
#' here (`forced = TRUE`, printed in red) rather than folding in as an
#' ordinary event — the one thing in a trail that was *not* a genuine review.
#'
#' No CMR-specific entry point is needed: leaving `disease`/`data_source`/
#' `data_type` `NULL` (the default) already enumerates every disease/channel/
#' measure under `country` — for a CMR workbook that naturally includes the
#' `rblf/cmr` split/approve logs *and* every fanned-out measure's own logs.
#'
#' @param country `chr` Country code (e.g. `"sdn"`). Required — an audit trail
#'   with no country would try to reconstruct a system-wide timeline, which
#'   isn't the job this function is scoped for.
#' @param disease,data_source,data_type `chr` or `NULL` Narrow further; any
#'   left `NULL` is enumerated from the blob (same scoping as [eri_logs()]).
#' @param period `chr` or `NULL` Restrict to one reporting period. Matched as
#'   an exact string against the value recorded on each entry (the codebase
#'   has no single canonical period format across sources — CMR periods look
#'   like `"202605"`, surveillance periods like `"2024-01"`); if nothing
#'   matches but the scope did contain events, the message lists which
#'   periods were actually found, so a format mismatch is diagnosable.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble, **oldest first**, with columns `timestamp`, `event`,
#'   `actor`, `detail`, `log_path`, `country`, `disease`, `data_source`,
#'   `data_type`, `period`, `source_hash` (an MD5 identity hash of the source
#'   file the entry's operation ran against, when one was recorded — lets you
#'   trace which exact bytes are behind a given step without opening the raw
#'   YAML), `forced` (`lgl`; `TRUE` for a forced `eri_approve_cmr()` approval
#'   or a bypass annotation it left behind). Class `eri_audit_trail`; printing
#'   it renders a `cli`-formatted timeline — the tibble itself is still the
#'   API (filter, join, whatever you need).
#' @examples
#' \dontrun{
#' eri_audit("sdn", period = "202605")                      # a whole CMR period
#' eri_audit("sdn", "oncho", "programmatic", "treatment")   # one measure, all periods
#' }
#' @seealso [eri_logs()] for the newest-first triage backlog this reuses for
#'   discovery, [eri_logs_resolve()] and [eri_dq_flag_resolve()] for the
#'   events this timeline surfaces.
#' @export
eri_audit <- function(country, disease = NULL, data_source = NULL, data_type = NULL,
                      period = NULL, data_con = NULL) {
  data_con <- .eri_logs_con(data_con)
  dirs     <- .eri_logs_dirs(data_con, country, disease, data_source, data_type)

  if (length(dirs) == 0L) {
    cli::cli_inform("No log directories found.")
    return(.eri_audit_empty())
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
      rows <- c(rows, .eri_audit_events(entry, fp))
    }
  }

  if (length(rows) == 0L) {
    cli::cli_inform("No audit events found.")
    return(.eri_audit_empty())
  }

  out <- tibble::tibble(
    timestamp   = vapply(rows, function(r) .eri_na_chr(r$timestamp),   character(1L)),
    event       = vapply(rows, function(r) .eri_na_chr(r$event),       character(1L)),
    actor       = vapply(rows, function(r) .eri_na_chr(r$actor),       character(1L)),
    detail      = vapply(rows, function(r) .eri_na_chr(r$detail),      character(1L)),
    log_path    = vapply(rows, function(r) .eri_na_chr(r$log_path),    character(1L)),
    country     = vapply(rows, function(r) .eri_na_chr(r$country),     character(1L)),
    disease     = vapply(rows, function(r) .eri_na_chr(r$disease),     character(1L)),
    data_source = vapply(rows, function(r) .eri_na_chr(r$data_source), character(1L)),
    data_type   = vapply(rows, function(r) .eri_na_chr(r$data_type),   character(1L)),
    period      = vapply(rows, function(r) .eri_na_chr(r$period),      character(1L)),
    source_hash = vapply(rows, function(r) .eri_na_chr(r$source_hash), character(1L)),
    forced      = vapply(rows, function(r) isTRUE(r$forced),           logical(1L))
  )

  if (!is.null(period)) {
    # period is an exact string match with no cross-format normalization (the
    # codebase has no single canonical period format -- CMR periods look like
    # "202605", surveillance periods like "2024-01"). A silent zero-row result
    # would read identically to "genuinely nothing happened"; when candidate
    # events exist but none match, say what periods actually ARE present, so
    # a format mismatch is diagnosable rather than mistaken for an empty trail.
    available <- unique(stats::na.omit(out$period))
    out <- out[!is.na(out$period) & out$period == period, , drop = FALSE]
    if (nrow(out) == 0L && length(available) > 0L) {
      cli::cli_inform(c(
        "No events match period {.val {period}}.",
        "i" = "Periods found in this scope: {.val {available}}."
      ))
      return(.eri_audit_empty())
    }
  }

  out <- out[order(.eri_audit_parse_ts(out$timestamp)), , drop = FALSE]  # oldest first -- a timeline reads forward

  if (nrow(out) == 0L) {
    cli::cli_inform("No audit events match the specified filters.")
    return(.eri_audit_empty())
  }

  cli::cli_inform("{nrow(out)} event{?s} across {length(unique(out$log_path))} log{?s}.")
  class(out) <- c("eri_audit_trail", class(out))
  out
}

#' Print method for an `eri_audit_trail`
#'
#' Renders the timeline as a `cli`-formatted chronological list, grouped by
#' scope (country/disease/data_source/data_type/period) when that scope is
#' uniform across the trail. The tibble itself remains the API — this only
#' affects how it prints.
#'
#' @param x An `eri_audit_trail` object from [eri_audit()].
#' @param ... Unused; included for S3 method compatibility.
#' @returns Invisibly, `x`.
#' @export
print.eri_audit_trail <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_alert_info("No audit events.")
    return(invisible(x))
  }

  cli::cli_h1("Audit trail")
  scope <- unique(x[, c("country", "disease", "data_source", "data_type", "period")])
  for (i in seq_len(nrow(scope))) {
    s <- scope[i, ]
    parts <- c(s$country, s$disease, s$data_source, s$data_type,
               if (!is.na(s$period)) paste0("period ", s$period) else NA_character_)
    parts <- parts[!is.na(parts)]
    cli::cli_text("{.strong {paste(parts, collapse = ' / ')}}")
  }
  cli::cli_text("")

  for (i in seq_len(nrow(x))) {
    r      <- x[i, ]
    ts     <- if (!is.na(r$timestamp)) r$timestamp else "?"
    actor  <- if (!is.na(r$actor)) paste0(" (", r$actor, ")") else ""
    detail <- if (!is.na(r$detail) && nzchar(r$detail)) paste0(": ", r$detail) else ""
    event  <- r$event
    if (isTRUE(r$forced)) {
      # A forced approval or a forced-bypass annotation -- render prominently
      # (red, a "!" bullet) rather than folding it in as an ordinary event;
      # this is the one thing in the trail that was NOT a genuine review.
      line <- cli::col_red(paste0("[FORCED] ", ts, " -- ", event, actor, detail))
      cli::cli_bullets(c("!" = line))
    } else {
      cli::cli_bullets(c("*" = "{ts} -- {.strong {event}}{actor}{detail}"))
    }
  }
  invisible(x)
}
