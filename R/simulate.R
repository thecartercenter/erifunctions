#### eri_inject_anomalies — dirty clean data for the Phase-3 simulation harness ####
#
# Existing staged/raw files are largely already clean, so a parallel-run
# simulation that feeds them straight through never exercises the DQ and
# reconciliation paths. `eri_inject_anomalies()` perturbs a clean data frame with
# controllable, reproducible anomalies so `run_dq_checks()`, the `add_anomaly_*`
# *detectors*, and `eri_compare()` all get a real workout. This is the injection
# side — the inverse of the detectors in `R/dq.R`.

.ERI_ANOMALY_TYPES <- c("missing", "outlier", "negative", "typo", "duplicate", "drop")

#' Inject controllable anomalies into a clean dataset
#'
#' Perturbs a data frame with a chosen set of realistic, reproducible anomalies —
#' the simulation-harness counterpart to the `add_anomaly_*` detectors. Use it to
#' stand in dirty "new data" for otherwise-clean staged files so the data-quality
#' and reconciliation paths (`run_dq_checks()`, [eri_compare()]) are genuinely
#' exercised (roadmap Phase 3).
#'
#' Anomaly types:
#' * `missing` — set cells to `NA`.
#' * `outlier` — replace numeric cells with an extreme value.
#' * `negative` — make numeric cells implausibly negative (e.g. negative counts).
#' * `typo` — perturb character/factor cells (case, stray characters, whitespace).
#' * `duplicate` — duplicate whole rows.
#' * `drop` — remove whole rows.
#'
#' The result carries an `"eri_anomalies"` attribute: a tibble logging every
#' injection (`type`, `row`, `column`, `original`, `new`) — the ground truth a
#' simulation can check detection against. `row` is the row index in the input
#' `data`. This attribute is **in-session only**: it is dropped the moment the
#' frame is written to Parquet or passed through most `dplyr` verbs, so capture it
#' before staging the dirty data. `duplicate` rows are appended, then `drop`
#' removes original rows, so the logged row indices stay valid.
#'
#' When the dirty data is destined for [eri_compare()], pass `cols` to keep the
#' cell-level types off the join keys — corrupting a key changes row-matching
#' rather than producing a detectable value anomaly.
#'
#' @param data A data frame to perturb.
#' @param types `chr` Which anomalies to inject. Any of
#'   `r paste(.ERI_ANOMALY_TYPES, collapse = ", ")`. Defaults to all.
#' @param n `int` How many anomalies to inject **per type** (cells for
#'   cell-level types, rows for `duplicate`/`drop`). Capped at what's available.
#'   Default `1`.
#' @param cols `chr` or `NULL` Restrict the cell-level types (`missing`,
#'   `outlier`, `negative`, `typo`) to these columns. `NULL` (default) auto-picks
#'   eligible columns per type (numeric for `outlier`/`negative`,
#'   character/factor for `typo`, any for `missing`).
#' @param seed `int` or `NULL` Optional RNG seed for a reproducible perturbation
#'   (set locally; the global RNG state is left untouched).
#' @returns `data` with anomalies injected, plus an `"eri_anomalies"` attribute
#'   (a tibble of what was changed).
#' @examples
#' clean <- data.frame(
#'   id = 1:10, cases = c(5, 8, 3, 6, 9, 4, 7, 2, 5, 8), site = letters[1:10]
#' )
#' dirty <- eri_inject_anomalies(clean, types = c("missing", "outlier"), n = 2, seed = 1)
#' attr(dirty, "eri_anomalies")
#' @seealso [eri_compare()] to reconcile, [run_dq_checks()] to detect.
#' @export
eri_inject_anomalies <- function(data,
                                 types = c("missing", "outlier", "negative",
                                           "typo", "duplicate", "drop"),
                                 n = 1L, cols = NULL, seed = NULL) {
  if (!is.data.frame(data)) cli::cli_abort("{.arg data} must be a data frame.")
  if (nrow(data) == 0L)     cli::cli_abort("{.arg data} has no rows to perturb.")
  bad <- setdiff(types, .ERI_ANOMALY_TYPES)
  if (length(bad)) {
    valid <- .ERI_ANOMALY_TYPES
    cli::cli_abort(c("Unknown anomaly type{?s}: {.val {bad}}.",
                     "i" = "Valid types: {.val {valid}}."))
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
    cli::cli_abort("{.arg n} must be a single positive integer.")
  }
  n <- as.integer(n)
  if (!is.null(cols)) {
    miss <- setdiff(cols, names(data))
    if (length(miss)) cli::cli_abort("{.arg cols} not in {.arg data}: {.val {miss}}.")
  }

  run <- function() .eri_inject_impl(data, types, n, cols)
  res <- if (is.null(seed)) run() else withr::with_seed(seed, run())

  log <- res$log
  if (nrow(log) == 0L) {
    cli::cli_warn("No anomalies injected (no eligible columns/rows for the requested types).")
  } else {
    counts <- table(factor(log$type, levels = .ERI_ANOMALY_TYPES))
    counts <- counts[counts > 0]
    parts  <- paste0(as.integer(counts), " ", names(counts))
    cli::cli_alert_info("Injected {nrow(log)} anomal{?y/ies}: {parts}.")
  }

  out <- res$data
  attr(out, "eri_anomalies") <- log
  out
}

# Worker: apply each requested type to a working copy, accumulating a log.
# Cell-level types run first on the original rows; duplicate then drop run last
# so row-count changes don't disturb the recorded row indices.
#' @keywords internal
.eri_inject_impl <- function(data, types, n, cols) {
  out  <- dplyr::as_tibble(data)
  orig <- out
  nm   <- names(orig)
  pick <- function(candidates) if (is.null(cols)) candidates else intersect(candidates, cols)

  num_cols <- pick(nm[vapply(orig, is.numeric, logical(1L))])
  chr_cols <- pick(nm[vapply(orig, function(x) is.character(x) || is.factor(x), logical(1L))])
  any_cols <- pick(nm)

  log <- list()
  add_log <- function(type, row, column, original, new) {
    log[[length(log) + 1L]] <<- tibble::tibble(
      type = type, row = as.integer(row), column = as.character(column),
      original = as.character(original), new = as.character(new)
    )
  }
  sample_rows <- function(k) sample.int(nrow(orig), min(k, nrow(orig)))

  # --- cell-level (operate on original rows; distinct cells per type) ---------
  for (type in intersect(c("missing", "outlier", "negative", "typo"), types)) {
    eligible <- switch(type,
      missing  = any_cols,
      outlier  = num_cols,
      negative = num_cols,
      typo     = chr_cols
    )
    if (length(eligible) == 0L) {
      cli::cli_warn("Skipping {.val {type}}: no eligible columns.")
      next
    }
    # Sample n *distinct* (column, row) cells so the log counts each once and
    # n is honoured up to the number of eligible cells.
    grid  <- expand.grid(col = eligible, rw = seq_len(nrow(orig)),
                         KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    cells <- grid[sample.int(nrow(grid), min(n, nrow(grid))), , drop = FALSE]
    for (k in seq_len(nrow(cells))) {
      col <- cells$col[[k]]; rw <- cells$rw[[k]]
      old <- orig[[col]][[rw]]
      new <- switch(type,
        missing  = NA,
        outlier  = { v <- as.numeric(old); if (is.na(v) || v == 0) 999999 else v * 1000 },
        negative = { v <- as.numeric(old); -abs(if (is.na(v)) 1 else v) - 1 },
        typo     = .eri_typo(as.character(old))
      )
      if (type == "typo" && is.factor(out[[col]])) out[[col]] <- as.character(out[[col]])
      # Preserve an integer column's type, so a numeric injection surfaces as a
      # value anomaly rather than a spurious int->double schema delta in
      # eri_compare() (ADR-0015 does not tolerate type mismatches).
      if (type %in% c("outlier", "negative") && is.integer(out[[col]])) {
        new <- as.integer(round(new))
      }
      out[[col]][[rw]] <- new
      add_log(type, rw, col, old, if (type == "missing") NA_character_ else new)
    }
  }

  # --- duplicate (append copies of original rows) -----------------------------
  if ("duplicate" %in% types) {
    rws <- sample_rows(n)
    out <- dplyr::bind_rows(out, orig[rws, , drop = FALSE])
    for (rw in rws) add_log("duplicate", rw, NA_character_, NA_character_, NA_character_)
  }

  # --- drop (remove original rows; appended duplicates stay) ------------------
  if ("drop" %in% types) {
    rws <- sample_rows(n)
    keep <- setdiff(seq_len(nrow(orig)), rws)
    extra <- if (nrow(out) > nrow(orig)) seq.int(nrow(orig) + 1L, nrow(out)) else integer(0)
    out <- out[c(keep, extra), , drop = FALSE]
    for (rw in rws) add_log("drop", rw, NA_character_, NA_character_, NA_character_)
  }

  log_tbl <- if (length(log)) dplyr::bind_rows(log) else tibble::tibble(
    type = character(), row = integer(), column = character(),
    original = character(), new = character()
  )
  list(data = out, log = log_tbl)
}

# Perturb a string into a plausible "typo": case flip, stray char, or whitespace.
#' @keywords internal
.eri_typo <- function(x) {
  if (is.na(x)) return("NA ")
  switch(sample.int(3L, 1L),
    toupper(x),
    paste0(x, " "),
    paste0(x, "?")
  )
}
