# Cross-sheet DQ consistency checks (ADR-0024)
#
# `consistency:` rules in a DQ schema (R/dq.R's add_anomaly_consistency())
# compare two columns of the SAME row of ONE already-loaded sheet -- they
# cannot express "population on the RB Treatment sheet must match population
# on the LF Treatment sheet", because those are two different staged
# datasets. `cross_consistency:` fills that gap: a declarative block on the
# CMR ROUTING schema (inst/schemas/cmr/{country}.yaml, not a per-measure DQ
# schema -- only the routing schema knows a whole workbook's sheet-to-measure
# map), evaluated by eri_cmr_dq_report() against the already-canonicalized
# per-sheet DQ output (post alias-resolution/type-coercion), never raw staged
# parquet (which still carries unresolved `#field-code` columns).
#
# Schema format:
#
# cross_consistency:
#   <rule_name>:
#     description: <chr>              # optional, human-readable
#     join_key: <chr>                 # canonical column, e.g. "district"
#     lhs:
#       agg: sum | unique | max | min | mean | n
#       missing_as: <num>             # optional; see below
#       sources:
#         - disease:   <chr>
#           data_type: <chr>
#           column:    <chr>
#           sheets:    [<chr>, ...]   # optional; restrict to these real CMR
#                                     # sheet names (e.g. training_type values)
#     rhs: { <same shape as lhs> }
#     op: "==" | "!=" | "<" | "<=" | ">" | ">=" | same_sign
#     tolerance: 0                    # optional, numeric; only used by ==/!=
#     message: <chr>                  # flag text
#
# Aggregation, per side, per join_key value:
#   sum/max/min/mean use na.rm = TRUE, but return NA (not 0) when EVERY value
#   for that key is NA -- "no data" is not the same as "zero".
#   `unique` asserts exactly one distinct non-NA value; more than one is
#   itself flagged (a within-sheet inconsistency, e.g. population varying
#   across treatment_round rows for the same district) and that key is
#   excluded from the cross-sheet comparison, not silently collapsed.
#
# A join_key value present on only one side is DROPPED from comparison
# (never flagged) unless that side declares `missing_as:`, in which case its
# value for that key is treated as `missing_as` -- this is what lets
# "district has treatment but zero training rows at all" correctly read as
# training = 0 and flag, while "LF only covers a subset of oncho's
# districts" (no missing_as on either side of that rule) never flags a
# coverage difference as a population mismatch.
#
# A rule (or a side's `sources`) that can't be resolved at all -- an
# unrecognized op/agg, a missing required field, or every source's
# (disease, data_type[, sheets]) matching zero available tables (e.g. a
# country with no CDD/CS/HW training tabs) -- is skipped, not an error: a
# `cli_warn` for a schema-authoring mistake (impossible to miss in the log,
# same posture as R/dq.R's range_when/range_overrides), a `cli_alert_info`
# for "legitimately not applicable this run".

# `%||%` is defined once in R/dq.R and shared package-wide.

.ERI_CROSS_OPS  <- c("<=", ">=", "==", "<", ">", "!=", "same_sign")
.ERI_CROSS_AGGS <- c("sum", "unique", "max", "min", "mean", "n")

#' @keywords internal
.eri_cross_empty_flags <- function() {
  tibble::tibble(row = integer(0), column = character(0),
                 value = character(0), issue = character(0))
}

#' @keywords internal
.eri_cross_reduce <- function(vals, agg) {
  switch(agg,
    sum  = if (all(is.na(vals))) NA_real_ else sum(vals, na.rm = TRUE),
    max  = if (all(is.na(vals))) NA_real_ else max(vals, na.rm = TRUE),
    min  = if (all(is.na(vals))) NA_real_ else min(vals, na.rm = TRUE),
    mean = if (all(is.na(vals))) NA_real_ else mean(vals, na.rm = TRUE),
    n    = sum(!is.na(vals))
  )
}

# Validate a rule's shape before attempting to run it. Warns (once, with every
# problem found) and returns FALSE on anything malformed, so a schema
# author's typo skips that ONE rule rather than either silently misbehaving
# or aborting the whole cross-check pass.
#' @keywords internal
.eri_cross_validate_rule <- function(rule_name, rule) {
  problems <- character(0)

  if (is.null(rule$join_key) || !is.character(rule$join_key) || length(rule$join_key) != 1L) {
    problems <- c(problems, "missing/invalid `join_key`")
  }
  for (side_name in c("lhs", "rhs")) {
    side <- rule[[side_name]]
    if (is.null(side) || is.null(side$sources) || length(side$sources) == 0L) {
      problems <- c(problems, paste0("`", side_name, "` has no `sources`"))
      next
    }
    for (src in side$sources) {
      if (is.null(src$disease) || is.null(src$data_type) || is.null(src$column)) {
        problems <- c(problems, paste0("`", side_name, "` has a source missing disease/data_type/column"))
      }
    }
  }
  op <- rule$op
  if (is.null(op) || length(op) != 1L || !op %in% .ERI_CROSS_OPS) {
    problems <- c(problems, paste0("unrecognized `op` ", if (is.null(op)) "(missing)" else paste0("'", op, "'")))
  }

  if (length(problems) > 0L) {
    valid_ops <- .ERI_CROSS_OPS
    cli::cli_warn(c(
      "Cross-consistency rule {.val {rule_name}} is malformed -- skipping it.",
      "i" = paste(problems, collapse = "; "),
      "i" = "Valid ops: {.val {valid_ops}}."
    ))
    return(FALSE)
  }
  TRUE
}

# Bind every matching (disease, data_type[, sheets]) source's (join_key,
# column) pair from `tables` into one long tibble(key, value). `tables` is a
# list of list(sheet=, disease=, data_type=, data=<canonical tibble>), one
# entry per CMR sheet -- exactly what eri_cmr_dq_report()'s loop already
# produces via run_dq_checks(). Returns NULL (with an info/warn already
# emitted) when nothing at all could be bound for this side.
#' @keywords internal
.eri_cross_bind_sources <- function(tables, sources, join_key, rule_name, side_label) {
  parts        <- list()
  missing_desc <- character(0)

  for (src in sources) {
    matches <- Filter(function(t) {
      identical(t$disease, src$disease) && identical(t$data_type, src$data_type) &&
        (is.null(src$sheets) || t$sheet %in% src$sheets)
    }, tables)

    if (!is.null(src$sheets)) {
      present <- unique(vapply(matches, function(m) m$sheet, character(1L)))
      absent  <- setdiff(src$sheets, present)
      if (length(absent) > 0L) {
        missing_desc <- c(missing_desc,
                          paste0(src$disease, "/", src$data_type, " [", paste(absent, collapse = ", "), "]"))
      }
    } else if (length(matches) == 0L) {
      missing_desc <- c(missing_desc, paste0(src$disease, "/", src$data_type))
    }

    for (m in matches) {
      d <- m$data
      if (!join_key %in% names(d)) {
        cli::cli_warn("Cross-consistency rule {.val {rule_name}}: {.val {m$sheet}} has no column {.val {join_key}} -- skipping that sheet for {side_label}.")
        next
      }
      if (!src$column %in% names(d)) {
        cli::cli_warn("Cross-consistency rule {.val {rule_name}}: {.val {m$sheet}} has no column {.val {src$column}} -- skipping that sheet for {side_label}.")
        next
      }
      parts[[length(parts) + 1L]] <- tibble::tibble(
        key   = as.character(d[[join_key]]),
        value = as.numeric(d[[src$column]])
      )
    }
  }

  if (length(missing_desc) > 0L) {
    cli::cli_alert_info(
      "Cross-consistency rule {.val {rule_name}} ({side_label}): no data for {paste(missing_desc, collapse = ', ')}{if (length(parts) > 0L) ' -- continuing with what is present' else ' -- skipping this rule'}."
    )
  }

  if (length(parts) == 0L) return(NULL)
  dplyr::bind_rows(parts)
}

# Reduce one side's bound (key, value) rows to one aggregated value per
# join_key. Returns list(values = tibble(key, value), flags = <non-constant
# flags from agg="unique">), or NULL (nothing left to resolve, already
# warned/informed) when the side can't be resolved at all.
#' @keywords internal
.eri_cross_side_values <- function(tables, side, join_key, rule_name, side_label) {
  bound <- .eri_cross_bind_sources(tables, side$sources, join_key, rule_name, side_label)
  if (is.null(bound)) return(NULL)

  agg <- side$agg %||% "sum"
  if (!agg %in% .ERI_CROSS_AGGS) {
    valid_aggs <- .ERI_CROSS_AGGS
    cli::cli_warn(c(
      "Cross-consistency rule {.val {rule_name}}'s {side_label} has an unrecognized {.field agg} {.val {agg}} -- skipping this rule.",
      "i" = "Valid aggregations: {.val {valid_aggs}}."
    ))
    return(NULL)
  }

  bound <- bound[!is.na(bound$key) & nzchar(trimws(bound$key)), , drop = FALSE]
  bound$key <- trimws(bound$key)

  flags <- .eri_cross_empty_flags()
  out   <- tibble::tibble(key = character(0), value = double(0))
  if (nrow(bound) == 0L) return(list(values = out, flags = flags))

  for (k in unique(bound$key)) {
    vals <- bound$value[bound$key == k]
    if (identical(agg, "unique")) {
      nonna <- unique(vals[!is.na(vals)])
      if (length(nonna) > 1L) {
        flags <- dplyr::bind_rows(flags, tibble::tibble(
          row = NA_integer_, column = join_key, value = k,
          issue = glue::glue(
            "cross_consistency [{rule_name}]: {side_label} is not constant for {join_key} \"{k}\" ({paste(nonna, collapse = ', ')}) -- excluded from comparison"
          )
        ))
        next
      }
      v <- if (length(nonna) == 1L) nonna else NA_real_
    } else {
      v <- .eri_cross_reduce(vals, agg)
    }
    out <- dplyr::bind_rows(out, tibble::tibble(key = k, value = as.double(v)))
  }
  list(values = out, flags = flags)
}

# Fill a side's per-key values over the full comparison keyset. A key ABSENT
# from `values_tbl` (never appeared on this side at all) is filled with
# `missing_as` when given; a key PRESENT but aggregated to NA (e.g. every raw
# value was NA) stays NA regardless -- these are deliberately different, see
# the file header.
#' @keywords internal
.eri_cross_fill <- function(values_tbl, missing_as, keys) {
  idx <- match(keys, values_tbl$key)
  v   <- values_tbl$value[idx]
  if (!is.null(missing_as)) v[is.na(idx)] <- missing_as
  v
}

#' @keywords internal
.eri_cross_compare <- function(lhs, rhs, op, tolerance) {
  switch(op,
    "<="        = lhs <= rhs,
    ">="        = lhs >= rhs,
    "=="        = abs(lhs - rhs) <= tolerance,
    "<"         = lhs <  rhs,
    ">"         = lhs >  rhs,
    "!="        = abs(lhs - rhs) > tolerance,
    # Deliberately `> 0`, not `!= 0`: a negative count reads the same as zero
    # here ("no activity"), by design -- catching a genuinely negative count
    # is each measure's own per-sheet DQ schema's job (e.g. treated_nonneg),
    # not this cross-sheet activity-presence check's.
    "same_sign" = (lhs > 0) == (rhs > 0)
  )
}

#' @keywords internal
.eri_cross_side_label <- function(side) {
  diseases <- unique(vapply(side$sources, function(s) s$disease %||% "?", character(1L)))
  dtypes   <- unique(vapply(side$sources, function(s) s$data_type %||% "?", character(1L)))
  cols     <- unique(vapply(side$sources, function(s) s$column %||% "?", character(1L)))
  paste0(paste(diseases, collapse = "+"), "/", paste(dtypes, collapse = "+"), " ", paste(cols, collapse = "+"))
}

#### .eri_cross_check_run ####

# The pure, testable core: no Azure, no schema loading. `tables` is a list of
# list(sheet=, disease=, data_type=, data=<canonical tibble>) -- one entry
# per CMR sheet, already run through run_dq_checks() by the caller. `rules`
# is the `cross_consistency` list from a CMR routing schema (possibly empty
# or NULL). Returns a flags tibble in the same row/column/value/issue shape
# every other DQ check in this package uses.
#' @keywords internal
.eri_cross_check_run <- function(tables, rules) {
  all_flags <- .eri_cross_empty_flags()
  rules <- rules %||% list()
  if (length(rules) == 0L) return(all_flags)

  for (rule_name in names(rules)) {
    rule <- rules[[rule_name]]
    if (!.eri_cross_validate_rule(rule_name, rule)) next

    join_key  <- rule$join_key
    op        <- rule$op
    tolerance <- rule$tolerance %||% 0

    lhs <- .eri_cross_side_values(tables, rule$lhs, join_key, rule_name, "lhs")
    if (is.null(lhs)) next
    rhs <- .eri_cross_side_values(tables, rule$rhs, join_key, rule_name, "rhs")
    if (is.null(rhs)) next

    all_flags <- dplyr::bind_rows(all_flags, lhs$flags, rhs$flags)

    all_keys <- union(lhs$values$key, rhs$values$key)
    if (length(all_keys) == 0L) next

    lhs_v <- .eri_cross_fill(lhs$values, rule$lhs$missing_as, all_keys)
    rhs_v <- .eri_cross_fill(rhs$values, rule$rhs$missing_as, all_keys)

    applicable <- !is.na(lhs_v) & !is.na(rhs_v)
    ok <- .eri_cross_compare(lhs_v, rhs_v, op, tolerance)

    bad <- which(applicable & !ok)
    if (length(bad) > 0L) {
      msg     <- rule$message %||% paste0(join_key, " mismatch between lhs and rhs")
      lhs_lbl <- .eri_cross_side_label(rule$lhs)
      rhs_lbl <- .eri_cross_side_label(rule$rhs)
      all_flags <- dplyr::bind_rows(all_flags, tibble::tibble(
        row    = NA_integer_,
        column = join_key,
        value  = all_keys[bad],
        issue  = glue::glue(
          "cross_consistency [{rule_name}]: {msg} ({lhs_lbl} = {signif(lhs_v[bad], 6)}, {rhs_lbl} = {signif(rhs_v[bad], 6)})"
        )
      ))
    }
  }
  all_flags
}

#### Resolver -- called from eri_cmr_dq_report() ####

# Top up `tables` with any sheet from this period's FULL last plan that isn't
# already present. eri_cmr_dq_report() is sometimes called with a scoped
# `plan` (e.g. a targeted re-check of one flagged measure during the review
# loop) -- without this, a cross rule referencing a sibling measure outside
# that scope would silently see it as absent. Always safe to call: a full
# workbook run already has every sheet, so this is a no-op past the one
# eri_cmr_last_plan() lookup.
#' @keywords internal
.eri_cross_load_missing <- function(country, period, tables, data_con) {
  full_plan <- tryCatch(eri_cmr_last_plan(country, period, data_con = data_con), error = function(e) NULL)
  if (is.null(full_plan) || nrow(full_plan) == 0L) return(tables)

  have <- vapply(tables, function(t) t$sheet, character(1L))
  missing <- full_plan[!full_plan$sheet %in% have, , drop = FALSE]
  if (nrow(missing) == 0L) return(tables)

  for (i in seq_len(nrow(missing))) {
    p <- missing[i, ]
    staged <- tryCatch(eri_read(p$dest, azcontainer = data_con), error = function(e) NULL)
    if (is.null(staged)) next
    schema <- tryCatch(
      load_dq_schema(country, p$disease, "programmatic", p$data_type, azcontainer = data_con),
      error = function(e) NULL
    )
    if (is.null(schema)) next
    result <- suppressMessages(run_dq_checks(staged, schema))
    tables[[length(tables) + 1L]] <- list(sheet = p$sheet, disease = p$disease,
                                          data_type = p$data_type, data = result$data)
  }
  tables
}

# Load the country's cross_consistency rules (if any) and evaluate them
# against `tables`, topping up from the full plan first. Returns NULL when
# the country's CMR routing schema has no cross_consistency block at all --
# the caller's cue to skip logging anything, not just "zero flags this run".
#' @keywords internal
.eri_cmr_cross_flags <- function(country, period, tables, data_con = NULL) {
  schema <- tryCatch(load_cmr_schema(country), error = function(e) NULL)
  rules  <- schema$cross_consistency %||% list()
  if (length(rules) == 0L) return(NULL)

  tables <- .eri_cross_load_missing(country, period, tables, data_con)
  .eri_cross_check_run(tables, rules)
}
