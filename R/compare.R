#### eri_compare — reconcile two datasets (Phase 3 cutover validation) ####
#
# During the parallel run, `eri_ingest()` writes to `data/staged` while the
# opt-in `mirror_pipeline` dual-write still produces the legacy hsp-mal output in
# `projects/intermediate`. `eri_compare()` reconciles the two so we can show
# parity (or precise deltas) and gate the cutover on evidence (Phase 3). The
# engine is a pure data-frame diff; the Azure paths are just a convenience that
# reads each side with `eri_read()` first.

# Resolve a `new`/`old` argument that is either a data frame or a blob path.
#' @keywords internal
.eri_compare_resolve <- function(x, arg, con, default_storage) {
  if (is.data.frame(x)) return(x)
  if (is.character(x) && length(x) == 1L && nzchar(x)) {
    if (is.null(con)) {
      con <- suppressMessages(get_azure_storage_connection(storage_name = default_storage))
    }
    out <- eri_read(x, azure = TRUE, azcontainer = con)
    if (!is.data.frame(out)) {
      cli::cli_abort("{.arg {arg}} path {.path {x}} did not read as a table.")
    }
    return(out)
  }
  cli::cli_abort("{.arg {arg}} must be a data frame or a single Azure blob path.")
}

# Element-wise equality of two columns, NA-aware and numeric-tolerant.
# NA == NA is equal; NA vs a value is not; numerics within `tolerance` are equal;
# everything else compares by string value (so 1L vs "1" is equal in content).
#' @keywords internal
.eri_vals_equal <- function(a, b, tolerance) {
  both_na <- is.na(a) & is.na(b)
  one_na  <- xor(is.na(a), is.na(b))
  if (is.numeric(a) && is.numeric(b)) {
    eq <- abs(a - b) <= tolerance
  } else {
    eq <- as.character(a) == as.character(b)
  }
  eq[is.na(eq)] <- FALSE
  (eq & !one_na) | both_na
}

#' Reconcile two datasets and report the differences
#'
#' Compares a `new` dataset against an `old` one and reports schema, row, and
#' value differences. Built for the Phase 3 cutover: prove `eri_ingest()`'s
#' `data/staged` output matches the legacy `projects/intermediate` (hsp-mal)
#' output during the parallel run, so the switch-over rests on evidence.
#'
#' With key columns (`by`) it reconciles row-for-row: which keys were added or
#' dropped, and — for keys present in both — exactly which cells differ. Without
#' `by` it still reports the schema diff and set-based row membership, but cannot
#' pinpoint per-cell value changes.
#'
#' @param new A data frame, or a single Azure blob path read with [eri_read()]
#'   (defaults to the `data` blob). The candidate / new-pipeline output.
#' @param old A data frame, or a single Azure blob path read with [eri_read()]
#'   (defaults to the `projects` blob). The reference / legacy output.
#' @param by `chr` or `NULL` Key column(s) that uniquely identify a row in both
#'   datasets. Required for per-cell value reconciliation; must be unique.
#' @param ignore `chr` or `NULL` Columns to drop from both sides before comparing
#'   (e.g. a run timestamp that is expected to differ).
#' @param tolerance `num` Absolute tolerance for numeric columns; `|new - old|`
#'   within `tolerance` counts as equal. Default `0` (exact).
#' @param new_con,old_con Azure containers used only when `new`/`old` are paths.
#'   If `NULL`, connect automatically (`new` → `data` blob, `old` → `projects` blob).
#' @returns An `eri_comparison` object (a list) with `equivalent` (logical),
#'   `summary`, `schema` (`added`/`dropped`/`type_mismatch`), `rows`
#'   (`added`/`dropped` key tibbles), and `values` (a tibble of per-cell
#'   mismatches). Has a `print()` method.
#' @examples
#' a <- data.frame(id = 1:3, n = c(10, 20, 30), site = c("x", "y", "z"))
#' b <- data.frame(id = 1:3, n = c(10, 21, 30), site = c("x", "y", "z"))
#' eri_compare(a, b, by = "id")            # one value mismatch on id 2
#'
#' \dontrun{
#' # New staged output vs the legacy mirror, read straight from the blobs
#' eri_compare(
#'   new = "uga/oncho/programmatic/treatment/staged/2024_06.parquet",
#'   old = "health-rb-country-expansion-dev/intermediate/uga/2024_06.parquet",
#'   by  = c("admin2", "period")
#' )
#' }
#' @export
eri_compare <- function(new, old, by = NULL, ignore = NULL, tolerance = 0,
                        new_con = NULL, old_con = NULL) {
  if (!is.numeric(tolerance) || length(tolerance) != 1L || is.na(tolerance) || tolerance < 0) {
    cli::cli_abort("{.arg tolerance} must be a single non-negative number.")
  }

  data_storage     <- Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
  projects_storage <- Sys.getenv("ERIFUNCTIONS_STORAGE_NAME")
  new <- .eri_compare_resolve(new, "new", new_con, data_storage)
  old <- .eri_compare_resolve(old, "old", old_con, projects_storage)

  if (length(ignore)) {
    new <- new[, setdiff(names(new), ignore), drop = FALSE]
    old <- old[, setdiff(names(old), ignore), drop = FALSE]
  }

  cols_new <- names(new)
  cols_old <- names(old)
  common   <- intersect(cols_new, cols_old)

  # --- schema -----------------------------------------------------------------
  type_of <- function(df, cols) vapply(cols, function(c) class(df[[c]])[[1L]], character(1L))
  tn <- type_of(new, common); to <- type_of(old, common)
  type_mismatch <- tibble::tibble(
    column   = common[tn != to],
    new_type = tn[tn != to],
    old_type = to[tn != to]
  )
  schema <- list(
    added         = setdiff(cols_new, cols_old),   # columns only in `new`
    dropped       = setdiff(cols_old, cols_new),   # columns only in `old`
    type_mismatch = type_mismatch
  )

  empty_key_tbl <- tibble::tibble()
  rows   <- list(added = empty_key_tbl, dropped = empty_key_tbl)
  values <- tibble::tibble(column = character(), new = character(), old = character())

  if (is.null(by)) {
    # Set-based membership on the common columns (no per-cell diff without a key).
    if (length(common) > 0L) {
      nc <- dplyr::distinct(dplyr::as_tibble(new[, common, drop = FALSE]))
      oc <- dplyr::distinct(dplyr::as_tibble(old[, common, drop = FALSE]))
      rows$added   <- dplyr::anti_join(nc, oc, by = common)
      rows$dropped <- dplyr::anti_join(oc, nc, by = common)
    }
    n_added <- nrow(rows$added); n_dropped <- nrow(rows$dropped)
    n_matched <- NA_integer_; n_val_mismatch <- NA_integer_; n_val_rows <- NA_integer_
    cli::cli_inform(c("i" = "No {.arg by} keys given - reporting schema + row membership only.",
                      "*" = "Pass {.arg by} to reconcile values cell-by-cell."))
  } else {
    miss_new <- setdiff(by, cols_new); miss_old <- setdiff(by, cols_old)
    if (length(miss_new) || length(miss_old)) {
      cli::cli_abort(c(
        "Key columns in {.arg by} not found in both datasets.",
        "i" = if (length(miss_new)) "Missing from {.arg new}: {.val {miss_new}}." else NULL,
        "i" = if (length(miss_old)) "Missing from {.arg old}: {.val {miss_old}}." else NULL
      ))
    }
    if (anyDuplicated(new[, by, drop = FALSE]) || anyDuplicated(old[, by, drop = FALSE])) {
      cli::cli_abort(c(
        "{.arg by} does not uniquely identify rows.",
        "i" = "Per-cell reconciliation needs a unique key; add columns to {.arg by}."
      ))
    }

    val_cols <- setdiff(common, by)
    new_t <- dplyr::as_tibble(new)
    old_t <- dplyr::as_tibble(old)

    rows$added   <- dplyr::anti_join(new_t, old_t, by = by)   # full rows only in `new`
    rows$dropped <- dplyr::anti_join(old_t, new_t, by = by)   # full rows only in `old`

    matched <- dplyr::inner_join(
      new_t[, c(by, val_cols), drop = FALSE],
      old_t[, c(by, val_cols), drop = FALSE],
      by = by, suffix = c(".__new", ".__old")
    )
    n_matched <- nrow(matched)

    mismatch_chunks <- list()
    for (col in val_cols) {
      a <- matched[[paste0(col, ".__new")]]
      b <- matched[[paste0(col, ".__old")]]
      bad <- !.eri_vals_equal(a, b, tolerance)
      if (any(bad)) {
        keycols <- matched[bad, by, drop = FALSE]
        mismatch_chunks[[col]] <- tibble::as_tibble(c(
          as.list(keycols),
          list(column = col,
               new = as.character(a[bad]),
               old = as.character(b[bad]))
        ))
      }
    }
    if (length(mismatch_chunks)) values <- dplyr::bind_rows(mismatch_chunks)

    n_added <- nrow(rows$added); n_dropped <- nrow(rows$dropped)
    n_val_mismatch <- nrow(values)
    n_val_rows <- if (n_val_mismatch > 0L) nrow(dplyr::distinct(values[, by, drop = FALSE])) else 0L
  }

  equivalent <- length(schema$added) == 0L && length(schema$dropped) == 0L &&
    nrow(schema$type_mismatch) == 0L && n_added == 0L && n_dropped == 0L &&
    (is.na(n_val_mismatch) || n_val_mismatch == 0L)

  structure(
    list(
      equivalent = equivalent,
      summary = list(
        n_new = nrow(new), n_old = nrow(old), n_matched = n_matched,
        n_added = n_added, n_dropped = n_dropped,
        n_value_mismatches = n_val_mismatch, n_rows_with_value_mismatch = n_val_rows,
        cols_added = schema$added, cols_dropped = schema$dropped,
        n_type_mismatch = nrow(schema$type_mismatch),
        keyed = !is.null(by), tolerance = tolerance
      ),
      schema = schema,
      rows   = rows,
      values = values
    ),
    class = "eri_comparison"
  )
}

#' @export
print.eri_comparison <- function(x, ...) {
  s <- x$summary
  if (isTRUE(x$equivalent)) {
    cli::cli_alert_success("Equivalent: {s$n_new} matching row{?s}; no schema or value differences.")
    return(invisible(x))
  }

  cli::cli_alert_danger("Not equivalent.")
  if (s$keyed) {
    cli::cli_text("Rows: {s$n_new} new · {s$n_old} old · {s$n_matched} matched · ",
                  "{s$n_added} added · {s$n_dropped} dropped")
  } else {
    cli::cli_text("Rows: {s$n_new} new · {s$n_old} old · ",
                  "{s$n_added} only in new · {s$n_dropped} only in old")
  }

  sch_bits <- c(
    if (length(s$cols_added))   "+{length(s$cols_added)} column{?s} ({.val {s$cols_added}})" else NULL,
    if (length(s$cols_dropped)) "-{length(s$cols_dropped)} column{?s} ({.val {s$cols_dropped}})" else NULL,
    if (s$n_type_mismatch)      "{s$n_type_mismatch} type mismatch{?es}" else NULL
  )
  if (length(sch_bits)) cli::cli_text("Schema: ", paste(sch_bits, collapse = " · "))

  if (isTRUE(s$keyed) && !is.na(s$n_value_mismatches) && s$n_value_mismatches > 0L) {
    cols <- unique(x$values$column)
    cli::cli_text("Values: {s$n_value_mismatches} cell mismatch{?es} across ",
                  "{s$n_rows_with_value_mismatch} row{?s} ",
                  "({cli::qty(length(cols))}column{?s}: {.val {cols}})")
  }
  cli::cli_alert_info("Inspect {.code $rows$added}, {.code $rows$dropped}, {.code $values}, {.code $schema}.")
  invisible(x)
}
