#### Cutover ledger — record + evaluate the hsp-mal cutover gate (ADR-0015, superseded) ####
#
# ADR-0015's streak-based cutover gate is superseded by ADR-0027: there is no parallel
# run to generate per-period evidence for, so nothing calls `eri_cutover_check()`
# anymore and the streak this file computes will not accrue. The ledger and this code
# are kept in place rather than removed, because they are still load-bearing in one
# way: `eri_do()` derives whether it dual-writes to the legacy pipeline
# (`mirror_pipeline`) from `eri_cutover_status()$eligible` (see
# `.eri_wizard_should_mirror_cmr()` / `.eri_wizard_should_mirror_ingest()` in
# `R/wizard.R`). A streak that never accrues means `eligible` is always `FALSE`, which
# means the wizard keeps mirroring — the correct, fail-safe behaviour until
# erifunctions writes the BI outputs directly (ADR-0027 Stages 2–3). `eri_cutover_check()`
# / `eri_compare()` remain relevant for the one-time BI-output correctness comparison
# ADR-0027 §4 calls for before cutover; it's the *recurring streak* framing that's dead,
# not the comparison engine itself.
#
# `eri_cutover_check()` runs the cutover-standard `eri_compare()` for one stream ×
# period and records the outcome to `_cutover/cutover_log.yaml`. `eri_cutover_status()`
# reads the ledger and computes the consecutive-equivalence streak against N. The
# equivalence standard (strict_schema = FALSE) is encoded here so it can't drift
# from the policy in ADR-0015. The ledger reuses the concurrency-safe metadata
# write path (ADR-0002) and the verified actor identity (ADR-0003).

.ERI_CUTOVER_PATH <- "_cutover/cutover_log.yaml"

#' @keywords internal
.eri_cutover_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

# Stream identity as a short "country/disease/data_source[/data_type]" label.
#' @keywords internal
.eri_cutover_label <- function(country, disease, data_source, data_type) {
  parts <- c(country, disease, data_source,
             if (!is.null(data_type) && !is.na(data_type)) data_type)
  paste(parts, collapse = "/")
}

#### eri_cutover_check ####

#' Compare a stream's period and record it in the cutover ledger
#'
#' @description
#' **The streak-based cutover gate this fed (ADR-0015) is superseded by
#' [ADR-0027](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0027-erifunctions-owns-bi-output-contract.md).**
#' There is no ongoing parallel run generating per-period evidence to record, and
#' nothing currently calls this function. It is kept, not removed, because
#' [eri_do()] derives whether it dual-writes to the legacy pipeline from
#' [eri_cutover_status()]'s streak — see that function's `@description` for why a
#' streak that never grows is the correct, fail-safe outcome right now. The
#' comparison engine itself (`eri_compare()`) stays relevant for the one-time
#' BI-output correctness check ADR-0027 calls for before cutover; this function is
#' how that comparison would be run and recorded when the time comes.
#'
#' Runs the **cutover-standard** comparison — `eri_compare(new, old, by,
#' strict_schema = FALSE, tolerance, ignore)` — for one data stream's `period` and
#' appends the outcome to `_cutover/cutover_log.yaml` in the `data/` blob.
#'
#' `strict_schema = FALSE` is fixed (not exposed): the cutover gate requires
#' value/row parity but tolerates extra columns the new pipeline adds. The `by`
#' keys and `tolerance` are recorded with the entry so the bar is auditable.
#'
#' To **accept** a legitimately-expected difference (ADR-0015), record the period
#' with that difference excluded — pass the differing column to `ignore`, or widen
#' `tolerance` — so the period reconciles under the relaxed standard, which is
#' itself recorded in the ledger entry (visible and attributable, not hidden).
#'
#' @param new,old The new (`data/staged`) and reference (legacy `projects/intermediate`)
#'   datasets — data frames or Azure blob paths, as in [eri_compare()].
#' @param country,disease,data_source `chr` The stream's axes.
#' @param period `chr` The period being checked (e.g. `"2024_06"`, `"2024-W01"`).
#' @param by `chr` Key column(s) uniquely identifying a row (required — the gate
#'   needs per-cell reconciliation).
#' @param data_type `chr` or `NULL` The measure, where it splits the stream.
#' @param tolerance `num` Absolute numeric tolerance for the comparison. Default `0`.
#' @param ignore `chr` or `NULL` Columns to exclude from the comparison.
#' @param record `lgl` Append the outcome to the ledger? Default `TRUE`.
#' @param data_con Azure container for the `data/` blob (the ledger). If `NULL`, connects automatically.
#' @param new_con,old_con Passed to [eri_compare()] when `new`/`old` are blob paths.
#' @returns The [eri_compare()] result (an `eri_comparison`), invisibly.
#' @examples
#' \dontrun{
#' eri_cutover_check(
#'   new = "uga/oncho/programmatic/treatment/staged/2024_06.parquet",
#'   old = "health-rb-country-expansion-dev/intermediate/uga/2024_06.parquet",
#'   country = "uga", disease = "oncho", data_source = "programmatic",
#'   data_type = "treatment", period = "2024_06", by = c("admin2", "period")
#' )
#' }
#' @seealso [eri_cutover_status()] for the streak, [eri_compare()] for the engine.
#' @export
eri_cutover_check <- function(new, old, country, disease, data_source, period, by,
                              data_type = NULL, tolerance = 0, ignore = NULL,
                              record = TRUE, data_con = NULL,
                              new_con = NULL, old_con = NULL) {
  for (a in c("country", "disease", "data_source", "period")) {
    v <- get(a)
    if (!is.character(v) || length(v) != 1L || is.na(v) || !nzchar(v)) {
      cli::cli_abort("{.arg {a}} must be a single non-empty string.")
    }
  }
  if (is.null(by) || !length(by)) {
    cli::cli_abort("{.arg by} is required - the cutover gate needs per-cell reconciliation.")
  }

  cmp <- eri_compare(new, old, by = by, strict_schema = FALSE, tolerance = tolerance,
                     ignore = ignore, new_con = new_con, old_con = old_con)
  s     <- cmp$summary
  label <- .eri_cutover_label(country, disease, data_source, data_type)

  entry <- list(
    country            = country,
    disease            = disease,
    data_source        = data_source,
    data_type          = if (is.null(data_type)) NA_character_ else data_type,
    period             = period,
    equivalent         = isTRUE(cmp$equivalent),
    n_added            = as.integer(s$n_added),
    n_dropped          = as.integer(s$n_dropped),
    n_value_mismatches = if (is.na(s$n_value_mismatches)) 0L else as.integer(s$n_value_mismatches),
    n_cols_added       = length(s$cols_added),
    n_cols_dropped     = length(s$cols_dropped),
    n_type_mismatch    = as.integer(s$n_type_mismatch),
    by                 = as.list(as.character(by)),
    tolerance          = tolerance
  )

  if (isTRUE(record)) {
    data_con <- .eri_cutover_con(data_con)
    entry$recorded_by <- .eri_analyst_id(data_con)
    entry$recorded_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    .eri_yaml_update(data_con, .ERI_CUTOVER_PATH, function(log) {
      if (is.null(log$entries)) log$entries <- list()
      log$entries <- c(log$entries, list(entry))
      log
    }, default = list(entries = list()))
  }

  rec_txt <- if (isTRUE(record)) " - recorded" else ""
  nv      <- entry$n_value_mismatches
  if (isTRUE(cmp$equivalent)) {
    cli::cli_alert_success("{label} [{period}]: equivalent{rec_txt}.")
  } else {
    cli::cli_alert_danger(
      "{label} [{period}]: not equivalent ({entry$n_added} added, {entry$n_dropped} dropped, ",
      "{nv} value mismatch{?es}){rec_txt}."
    )
  }
  invisible(cmp)
}

#### eri_cutover_status ####

#' Report a stream's cutover readiness from the ledger
#'
#' @description
#' **This function's `eligible` result is load-bearing beyond its own name.**
#' [eri_do()] calls it internally (`.eri_wizard_should_mirror_cmr()` /
#' `.eri_wizard_should_mirror_ingest()` in `R/wizard.R`) to decide whether to
#' dual-write a stream to the legacy contractor pipeline as it processes a
#' submission. ADR-0015's streak-based cutover gate this was built for is
#' superseded by
#' [ADR-0027](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0027-erifunctions-owns-bi-output-contract.md):
#' nothing currently records new entries (see [eri_cutover_check()]), so the streak
#' this reports will not grow. That is intentional, not a bug to chase — an
#' `eligible = FALSE` that never flips keeps [eri_do()] mirroring, which is the
#' correct behaviour until erifunctions writes the BI outputs directly (Stages 2–3).
#' If you're reading this to decide whether to *raise* `n` or otherwise force
#' eligibility: don't — that decision belongs to ADR-0027's stage plan, not this
#' function's caller.
#'
#' Reads `_cutover/cutover_log.yaml`, takes the most recent entry per `period` for
#' the stream, and computes the **streak**: the number of consecutive most-recent
#' periods that are `equivalent`. A stream is *eligible* for cutover when the streak
#' reaches `n`. Periods are ordered by the **data `period`** (which for a stream uses
#' one consistent, lexically-sortable label), and re-checking a period updates its
#' standing — so backfilling an earlier period is handled correctly.
#'
#' @param country,disease,data_source `chr` The stream's axes.
#' @param data_type `chr` or `NULL` The measure, where it splits the stream.
#' @param n `int` Consecutive equivalent periods required for eligibility. Default `3`.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, a list with `eligible` (lgl), `streak` (int), `n`, and
#'   `periods` (a tibble of `period`, `equivalent`, the delta counts, and `recorded_at`,
#'   in checked order).
#' @examples
#' \dontrun{
#' eri_cutover_status("uga", "oncho", "programmatic", data_type = "treatment")
#' }
#' @seealso [eri_cutover_check()] to record a period.
#' @export
eri_cutover_status <- function(country, disease, data_source, data_type = NULL,
                               n = 3, data_con = NULL) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
    cli::cli_abort("{.arg n} must be a single positive integer.")
  }
  n        <- as.integer(n)
  dt       <- if (is.null(data_type)) NA_character_ else data_type
  label    <- .eri_cutover_label(country, disease, data_source, data_type)
  data_con <- .eri_cutover_con(data_con)
  log      <- .eri_yaml_read_versioned(data_con, .ERI_CUTOVER_PATH,
                                       default = list(entries = list()))$data
  entries  <- log$entries %||% list()

  stream <- Filter(function(e) {
    identical(e$country, country) && identical(e$disease, disease) &&
      identical(e$data_source, data_source) &&
      identical(e$data_type %||% NA_character_, dt)
  }, entries)

  empty <- tibble::tibble(period = character(), equivalent = logical(),
                          n_added = integer(), n_dropped = integer(),
                          n_value_mismatches = integer(), recorded_at = character())

  if (length(stream) == 0L) {
    cli::cli_inform("No cutover checks recorded for {.val {label}} yet.")
    return(invisible(list(eligible = FALSE, streak = 0L, n = n, periods = empty)))
  }

  # Latest entry per period (re-checks win, by recorded_at), then order the
  # periods by the *data period* itself (ADR-0015 §2) so the streak is over data
  # periods, not check time — robust against backfilling an earlier period after
  # a later one. A stream uses one consistent (zero-padded / ISO) period format,
  # which sorts lexically.
  periods <- sort(unique(vapply(stream, function(e) as.character(e$period), character(1L))))
  latest  <- lapply(periods, function(p) {
    es  <- Filter(function(e) identical(as.character(e$period), p), stream)
    ats <- vapply(es, function(e) as.character(e$recorded_at %||% ""), character(1L))
    es[[order(ats, decreasing = TRUE)[[1L]]]]  # most-recently recorded for this period
  })

  eqv <- vapply(latest, function(e) isTRUE(e$equivalent), logical(1L))
  streak <- 0L
  for (v in rev(eqv)) if (v) streak <- streak + 1L else break
  eligible <- streak >= n

  tbl <- tibble::tibble(
    period             = vapply(latest, function(e) as.character(e$period), character(1L)),
    equivalent         = eqv,
    n_added            = vapply(latest, function(e) as.integer(e$n_added %||% NA_integer_), integer(1L)),
    n_dropped          = vapply(latest, function(e) as.integer(e$n_dropped %||% NA_integer_), integer(1L)),
    n_value_mismatches = vapply(latest, function(e) as.integer(e$n_value_mismatches %||% NA_integer_), integer(1L)),
    recorded_at        = vapply(latest, function(e) as.character(e$recorded_at %||% NA_character_), character(1L))
  )

  cli::cli_h3("Cutover status - {label}")
  cli::cli_text("Streak: {.strong {streak}} of {n} consecutive equivalent period{?s}.")
  if (eligible) {
    cli::cli_alert_success("Eligible - {n} consecutive equivalent periods met. Cutover is a human call.")
  } else {
    cli::cli_alert_info("Not yet eligible ({streak}/{n}).")
  }
  recent <- utils::tail(tbl, 5L)
  marks  <- paste0(recent$period, " ", ifelse(recent$equivalent, "✔", "✖"))
  cli::cli_text("Recent: {paste(marks, collapse = ' · ')}")

  invisible(list(eligible = eligible, streak = streak, n = n, periods = tbl))
}
