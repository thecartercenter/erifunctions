#### eri_dq_review — the interactive front door over the scriptable DQ core ####
#
# Phase 7 of the pilot-feedback-driven DQ workflow redesign (see docs/roadmap.md's "DQ workflow
# redesign" entry). Everything here is pure orchestration: every mutation goes through a function
# already shipped and tested in Phases 2-6 (eri_cmr_dq_report(), eri_dq_flag_resolve(),
# eri_logs_resolve(), eri_dq_schema_edit(), eri_dq_schema_submit(), eri_split_cmr(),
# eri_approve_cmr()). The wrapper itself holds no state beyond one local, in-memory-only, per-call
# path cache (which local workbook file is being fixed this session) -- nothing here is persisted;
# closing the laptop and re-running eri_dq_review() picks up exactly where the log YAMLs say things
# are, because every decision below is written through immediately, not batched.
#
# CMR-only for now (per the design consult): the plan machinery (eri_cmr_last_plan(),
# eri_split_cmr()) is CMR-specific, and no other data shape has an analogous per-flag interactive
# workflow yet. Generalizing to eri_ingest()/ODK later only touches this orchestration layer, not
# the scriptable core it's built on.

# A cli_h3() header + utils::menu() -- returns the chosen 1-based index, or 0 for "back/exit/ESC"
# (utils::menu()'s own convention: 0 on cancelled selection). Never crashes on a declined choice;
# every caller below treats 0 as "go back," not an error.
#' @keywords internal
.eri_prompt_menu <- function(title, choices) {
  cli::cli_h3(title)
  utils::menu(choices)
}

# readline() with re-ask-on-blank when required = TRUE -- this is how the force-approve
# justification (and its typed-confirmation) are enforced without a separate validation step.
#' @keywords internal
.eri_prompt_line <- function(prompt, required = FALSE) {
  repeat {
    ans <- readline(prompt)
    if (!isTRUE(required) || nzchar(trimws(ans))) return(ans)
    cli::cli_alert_warning("This can't be blank.")
  }
}

# Opens `path` in the RStudio editor when available; otherwise prints a path cli renders as a
# clickable OSC-8 hyperlink in most modern terminals (VS Code, Windows Terminal, ...), so the
# "plain-console fallback" is usually still click-to-open. rstudioapi is Suggests-only -- the
# package's whole identity is script/CI-safe functions, so a hard dependency on an IDE shim would
# be the first convention violation.
#' @keywords internal
.eri_open_file <- function(path, line = NULL) {
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    rstudioapi::navigateToFile(path, line = line %||% -1L)
  } else {
    cli::cli_alert_info("Open this file to review/edit: {.file {path}}")
  }
  invisible(path)
}

# The Q2 sheet-grouped console report: a summary line, then one cli_h2()-headed table per sheet
# that still has open flags. Deliberately console-native (cli headers + a plain tibble print), not
# a flextable/gt -- the interactive loop lives in the console, and a flextable renders to the
# Viewer pane (nothing over SSH). Reused for both the main-loop display and the "print report" stub.
#' @keywords internal
.eri_dq_review_report <- function(flags, country, period) {
  cli::cli_h1("DQ review: {country} / {period}")
  if (nrow(flags) == 0L) {
    cli::cli_alert_success("No DQ flags across any measure -- all clean.")
    return(invisible(NULL))
  }
  open_flags <- flags[flags$status == "open", , drop = FALSE]
  n_sheets   <- length(unique(flags$sheet))
  if (nrow(open_flags) == 0L) {
    cli::cli_alert_success("{n_sheets} sheet{?s} checked -- all clean.")
    return(invisible(NULL))
  }
  sheets_with_open <- unique(open_flags$sheet)
  cli::cli_alert_danger(
    "{length(sheets_with_open)} of {n_sheets} sheet{?s} have open flags ({nrow(open_flags)} flag{?s} total)"
  )
  for (sh in sheets_with_open) {
    sub  <- open_flags[open_flags$sheet == sh, , drop = FALSE]
    meas <- paste0(sub$disease[[1]], "/", sub$data_type[[1]])
    cli::cli_h2("{sh} ({meas}) -- {nrow(sub)} open")
    print(as.data.frame(sub[, c("excel_row", "column", "value", "issue")]), row.names = FALSE)
  }
  invisible(NULL)
}

# "Print report" menu item: one plain-tibble table per sheet on the console for a quick eyeball --
# not eri_table()'s flextable (that renders to the Viewer pane, nothing over SSH/a plain console;
# same reasoning .eri_dq_review_report() above already follows) -- then eri_dq_export() writes the
# self-contained HTML handback file (with any in-session status/note triage already folded in via
# .eri_dq_review_apply_local_resolutions()).
#' @keywords internal
.eri_dq_review_print_report <- function(flags, country, period) {
  if (nrow(flags) == 0L) {
    cli::cli_alert_info("Nothing to report -- no DQ flags for {.val {country}} / {.val {period}}.")
    return(invisible(NULL))
  }
  for (sh in unique(flags$sheet)) {
    cols <- intersect(c("excel_row", "column", "value", "issue", "status", "note"), names(flags))
    sub  <- flags[flags$sheet == sh, cols, drop = FALSE]
    cli::cli_h3(sh)
    print(as.data.frame(sub), row.names = FALSE)
  }
  # Best-effort: a write failure (read-only cwd, locked file...) shouldn't eject the DA from an
  # otherwise-safe interactive session -- nothing here is lost, it's all already in the logs.
  tryCatch(
    eri_dq_export(flags, country = country, period = period),
    error = function(e) cli::cli_alert_warning("Could not write the DQ export file: {conditionMessage(e)}")
  )
  invisible(NULL)
}

# One flag's "fix in source" action. On the first such action this review session, forks a
# "_fixed" local copy of the workbook before any edit touches it (so the true-as-submitted file
# is always preserved, per the CMR guide's existing convention) and caches its path in
# `local_path_env` for the rest of the session -- an ordinary R environment used purely for
# reference-semantics within this one interactive call, never written anywhere, so it doesn't
# violate the "wrapper holds no state" rule (nothing here survives past the call returning).
#' @keywords internal
.eri_dq_review_fix_in_source <- function(f, local_path_env) {
  if (is.null(local_path_env$path)) {
    p <- .eri_prompt_line(
      "Path to the local source workbook for this period (or a '_fixed' copy you've already started, if you have one): ",
      required = TRUE
    )
    if (!file.exists(p)) {
      cli::cli_alert_danger("File not found: {.path {p}}")
      return(invisible(NULL))
    }
    # Anchored to the END of the filename stem (case-insensitive), not an
    # unanchored substring -- a real submission whose name happens to
    # contain "_fixed" somewhere (a facility code, a date) must still get
    # forked, not be mistaken for an already-forked working copy and handed
    # straight to the editor, which would silently break the "true-as-
    # submitted file is always preserved" guarantee this flow exists for.
    if (!grepl("_fixed$", tools::file_path_sans_ext(basename(p)), ignore.case = TRUE)) {
      ext        <- tools::file_ext(p)
      fixed_path <- paste0(tools::file_path_sans_ext(p), "_fixed", if (nzchar(ext)) paste0(".", ext) else "")
      if (file.exists(fixed_path)) {
        cli::cli_alert_info("Using an existing working copy: {.path {fixed_path}}")
      } else {
        file.copy(p, fixed_path)
        cli::cli_alert_success("Made a working copy: {.path {fixed_path}} (original preserved)")
      }
      p <- fixed_path
    }
    local_path_env$path <- p
  }
  # cli_bullets(), not cli_alert_info() -- cli_alert_info() only ever renders a single bullet;
  # handed a 2-element vector it glues both elements onto one line with no line break between
  # them instead of two separate "i" bullets.
  cli::cli_bullets(c(
    "i" = "Fix {.field {f$column}} on Excel row {.val {f$excel_row}} in the {.val {f$sheet}} sheet.",
    "i" = "Issue: {f$issue}"
  ))
  .eri_open_file(local_path_env$path)
  cli::cli_alert_info(
    "When you're done with this and any other fixes, choose {.val Re-run the DQ check} from the main menu -- it re-splits {.path {basename(local_path_env$path)}} and re-checks."
  )
  invisible(NULL)
}

# Walks one batch of open flags one at a time. Every decision (not_important/noted) persists
# immediately via eri_dq_flag_resolve() -- a dropped connection mid-review loses nothing, since
# per-flag status already lives in the log YAML. Returns list(touched, resolved): `touched` is
# the set of schema stems ("country|disease|data_source|data_type") touched via "Adjust the
# schema" this batch, so the caller can offer eri_dq_schema_submit() once at the end rather than
# after every single edit; `resolved` is a list keyed by flag_id, each element
# list(status, note), for flags marked not_important/noted, so the caller can update its own
# in-memory flags view (status AND note, for eri_dq_export()'s "if triaged" column) WITHOUT a
# fresh eri_cmr_dq_report() call -- re-deriving from the still-unchanged underlying data would
# just re-surface the exact same issue as a brand-new "open" flag (see .eri_dq_review_rerun(),
# the only place a fresh check should actually happen).
#' @keywords internal
.eri_dq_review_walk_flags <- function(open_flags, country, data_con, local_path_env) {
  touched  <- character(0)
  resolved <- list()
  for (i in seq_len(nrow(open_flags))) {
    f <- open_flags[i, ]
    cli::cli_h3("Flag {i}/{nrow(open_flags)}: {f$sheet} row {f$excel_row}")
    cli::cli_text("{.field {f$column}}: {.val {f$value}} -- {f$issue}")

    choice <- .eri_prompt_menu("What do you want to do with this flag?", c(
      "Fix in source (open/copy the workbook)",
      "Adjust the schema (alias, allowed value, range...)",
      "Mark not important",
      "Mark noted",
      "Skip to the next flag"
    ))
    if (choice == 0L || choice == 5L) next

    if (choice == 1L) {
      .eri_dq_review_fix_in_source(f, local_path_env)
    } else if (choice == 2L) {
      path <- eri_dq_schema_edit(country, f$disease, "programmatic", f$data_type, azcontainer = data_con)
      .eri_open_file(path)
      cli::cli_alert_info(
        "Edit {.path {path}}, save it, then come back -- this doesn't resolve the flag automatically; re-run the DQ check afterward to see if it clears."
      )
      touched <- union(touched, paste(country, f$disease, "programmatic", f$data_type, sep = "|"))
    } else if (choice %in% c(3L, 4L)) {
      status   <- if (choice == 3L) "not_important" else "noted"
      note_raw <- .eri_prompt_line("Note (optional): ")
      note     <- if (nzchar(trimws(note_raw))) note_raw else NA_character_
      eri_dq_flag_resolve(f$flag_id, status, note = if (is.na(note)) NULL else note, data_con = data_con)
      resolved[[f$flag_id]] <- list(status = status, note = note)
    }
  }
  list(touched = touched, resolved = resolved)
}

# Merges walk_flags()'s `resolved` (flag_id -> list(status, note)) into a flags tibble in-memory,
# so a not_important/noted decision (and any note typed for it) is reflected immediately in the
# wrapper's own view of "what's still open" without a network round-trip. A "Fix in
# source"/"Adjust schema" action does NOT appear here -- those flags correctly stay "open" until
# an explicit re-run actually verifies the underlying data changed.
#' @keywords internal
.eri_dq_review_apply_local_resolutions <- function(flags, resolved) {
  if (length(resolved) == 0L || nrow(flags) == 0L) return(flags)
  idx <- match(names(resolved), flags$flag_id)
  ok  <- !is.na(idx)
  if (!any(ok)) return(flags)
  matched <- resolved[ok]
  flags$status[idx[ok]] <- vapply(matched, function(r) r$status, character(1L))
  if ("note" %in% names(flags)) {
    flags$note[idx[ok]] <- vapply(matched, function(r) if (is.na(r$note)) NA_character_ else r$note,
                                  character(1L))
  }
  flags
}

# "Re-run the DQ check" menu item: if a local "fix in source" file is known this session, offers
# to re-split it (supersede_staged = TRUE, so the corrected file replaces the broken one rather
# than sitting alongside it -- ADR-0017). Returns list(plan, rechecked): `plan` is the FULL
# workbook plan with only the just-resplit measure(s)' routing rows replaced (every other
# measure's routing is kept, not discarded); `rechecked` is just those resplit rows, or NULL if
# nothing was resplit. The caller re-runs eri_cmr_dq_report() scoped to `rechecked` ONLY --
# passing the whole plan here would make eri_cmr_dq_report() write a brand-new "open" dq_flags
# entry for every measure, silently discarding every OTHER measure's in-session
# not_important/noted decisions the moment any single measure is re-checked.
#' @keywords internal
.eri_dq_review_rerun <- function(country, period, plan, data_con, local_path_env) {
  if (is.null(local_path_env$path)) {
    cli::cli_alert_info("No local fix known yet this session -- nothing to re-split or re-check.")
    return(list(plan = plan, rechecked = NULL))
  }
  choice <- .eri_prompt_menu(
    paste0("Re-split '", basename(local_path_env$path), "' and re-check just what it routes to?"),
    c("Yes", "No -- cancel")
  )
  if (choice != 1L) return(list(plan = plan, rechecked = NULL))

  new_plan <- eri_split_cmr(local_path_env$path, country, data_con = data_con, period = period,
                            supersede_staged = TRUE)
  key      <- function(p) paste(p$disease, p$data_type)
  plan     <- dplyr::bind_rows(plan[!(key(plan) %in% key(new_plan)), , drop = FALSE], new_plan)
  list(plan = plan, rechecked = new_plan)
}

# Force-approve, with the human friction the scriptable core deliberately doesn't add (batch use
# has to work there): a mandatory justification, then typing the period back to confirm. Returns
# TRUE if the approval went through (caller exits the loop), FALSE if cancelled or unconfirmed.
#' @keywords internal
.eri_dq_review_force_approve <- function(country, period, plan, data_con) {
  justification <- .eri_prompt_line(
    "Why should this be approved despite what's outstanding? (required): ", required = TRUE
  )
  confirm <- .eri_prompt_line(paste0("Type the period ('", period, "') to confirm force-approving: "))
  if (!identical(trimws(confirm), period)) {
    cli::cli_alert_danger("Confirmation did not match -- force-approve cancelled.")
    return(invisible(FALSE))
  }
  eri_approve_cmr(country, period, plan = plan, force = TRUE, justification = justification,
                 data_con = data_con)
  invisible(TRUE)
}

#' Interactively review and resolve a CMR workbook's DQ flags, then approve
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The interactive front door over the scriptable DQ core built in Phases 2-6 of the DQ workflow
#' redesign: [eri_cmr_dq_report()] for the combined flags tibble, [eri_dq_flag_resolve()] and
#' [eri_logs_resolve()] for triage, [eri_dq_schema_edit()]/[eri_dq_schema_submit()] for schema
#' fixes, [eri_split_cmr()] for re-running against a corrected workbook, and [eri_approve_cmr()]
#' (including its `force = TRUE` path) for the sign-off. Every mutation goes through one of those
#' functions immediately -- this wrapper holds no state of its own beyond one in-memory,
#' per-call path cache (which local workbook you're fixing this session), so closing the laptop
#' mid-review and running `eri_dq_review()` again later picks up exactly where the log YAMLs say
#' things are.
#'
#' The loop: clean -> offered approval; flagged -> work through flags one at a time (fix in the
#' source workbook, adjust the schema, or mark not-important/noted), re-run, force-approve, print
#' a report, or exit. CMR-only for now -- the plan machinery this dispatches to
#' ([eri_cmr_last_plan()], [eri_split_cmr()]) is CMR-specific; generalizing to other ingest shapes
#' later only touches this orchestration layer.
#'
#' **Interactive only.** In a script or CI, use the scriptable core directly:
#' [eri_cmr_dq_report()], [eri_dq_flag_resolve()], [eri_logs_resolve()], [eri_approve_cmr()].
#'
#' @param country `str` Country code (e.g. `"sdn"`).
#' @param period `str` Reporting period (e.g. `"202605"`).
#' @param plan `tibble` or `NULL` The plan from [eri_split_cmr()] / [eri_cmr_last_plan()]. `NULL`
#'   (default) looks it up via [eri_cmr_last_plan()].
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, `NULL`. Every effect happens through the scriptable core it calls, which is
#'   where the real return values (approvals, resolved flags, submitted tickets) live.
#' @examples
#' \dontrun{
#' eri_dq_review("sdn", "202605")
#' }
#' @seealso [eri_cmr_dq_report()], [eri_dq_flag_resolve()], [eri_logs_resolve()],
#'   [eri_approve_cmr()] for the scriptable core this orchestrates.
#' @export
eri_dq_review <- function(country, period, plan = NULL, data_con = NULL) {
  if (!rlang::is_interactive()) {
    cli::cli_abort(c(
      "{.fn eri_dq_review} is interactive-only.",
      "i" = "In scripts/CI use the scriptable core: {.fn eri_cmr_dq_report}, {.fn eri_dq_flag_resolve}, {.fn eri_logs_resolve}, {.fn eri_approve_cmr}."
    ))
  }

  data_con <- .eri_logs_con(data_con)
  if (is.null(plan)) plan <- eri_cmr_last_plan(country, period, data_con = data_con)

  invisible(.eri_dq_review_loop(country, period, plan, data_con))
}

# The main check -> fix -> re-check -> approve loop, extracted from eri_dq_review() so
# R/wizard.R's CMR flow can hand off into it directly with the plan it just built (no
# eri_cmr_last_plan() round-trip needed) instead of duplicating this control flow. eri_dq_review()
# itself is now a thin wrapper: resolve data_con/plan, then call this. No behavior change to
# eri_dq_review()'s exported signature or console output.
#
# Returns (invisibly) one of "approved" / "force_approved" / "exited" -- so a caller like the
# wizard knows whether the workbook actually got approved (and can print its own closing message)
# without having to re-derive that from eri_logs()/the catalog.
#' @keywords internal
.eri_dq_review_loop <- function(country, period, plan, data_con) {
  status <- "exited"

  local_path_env           <- new.env(parent = emptyenv())
  local_path_env$path      <- NULL
  touched_schemas          <- character(0)

  # Fetched once up front, then updated in-memory as flags are triaged --
  # NOT re-fetched every loop iteration. A fresh eri_cmr_dq_report() call
  # re-derives from whatever is currently staged; marking a flag
  # not_important/noted doesn't change the staged data, so an unconditional
  # re-check every iteration would just re-surface the identical issue as a
  # brand-new "open" flag, forever. A fresh check only happens where it
  # should: explicitly, via "Re-run the DQ check" (.eri_dq_review_rerun()).
  flags <- eri_cmr_dq_report(country, period, plan = plan, data_con = data_con)

  repeat {
    .eri_dq_review_report(flags, country, period)
    open_flags <- if (nrow(flags) > 0L) flags[flags$status == "open", , drop = FALSE] else flags

    if (nrow(open_flags) == 0L) {
      # Every flag has been individually triaged (not_important/noted) -- but
      # eri_dq_flag_resolve() only touches the per-flag status, never the
      # whole entry's own status/handled fields, which is what
      # eri_approve_cmr() actually checks. Close out every entry that had
      # flags (every log_path present here started as "needs_review" --
      # eri_cmr_dq_report() only returns rows for entries with n_flags > 0)
      # before offering to approve, or eri_approve_cmr() would immediately
      # re-block on exactly what was just finished. eri_logs_resolve() is
      # idempotent and auto-summarizes from the per-flag decisions.
      if (nrow(flags) > 0L) {
        for (lp in unique(flags$log_path)) {
          tryCatch(eri_logs_resolve(lp, data_con = data_con), error = function(e) NULL)
        }
      }
      choice <- .eri_prompt_menu("Nothing outstanding. What next?", c("Approve", "Print report", "Exit"))
      if (choice == 1L) {
        eri_approve_cmr(country, period, plan = plan, data_con = data_con)
        status <- "approved"
        break
      } else if (choice == 2L) {
        .eri_dq_review_print_report(flags, country, period)
        next
      } else {
        break
      }
    }

    choice <- .eri_prompt_menu(
      paste0(nrow(open_flags), " open flag(s) across the workbook. What do you want to do?"),
      c("Work through the open flags one at a time", "Re-run the DQ check",
        "Force-approve anyway", "Print report", "Exit")
    )
    if (choice == 1L) {
      result <- .eri_dq_review_walk_flags(open_flags, country, data_con, local_path_env)
      touched_schemas <- union(touched_schemas, result$touched)
      flags <- .eri_dq_review_apply_local_resolutions(flags, result$resolved)
    } else if (choice == 2L) {
      rerun <- .eri_dq_review_rerun(country, period, plan, data_con, local_path_env)
      plan  <- rerun$plan
      if (!is.null(rerun$rechecked) && nrow(rerun$rechecked) > 0L) {
        fresh <- eri_cmr_dq_report(country, period, plan = rerun$rechecked, data_con = data_con)
        key   <- function(p) paste(p$disease, p$data_type)
        if (nrow(flags) > 0L) flags <- flags[!(key(flags) %in% key(rerun$rechecked)), , drop = FALSE]
        flags <- dplyr::bind_rows(flags, fresh)
      }
    } else if (choice == 3L) {
      if (isTRUE(.eri_dq_review_force_approve(country, period, plan, data_con))) {
        status <- "force_approved"
        break
      }
    } else if (choice == 4L) {
      .eri_dq_review_print_report(flags, country, period)
    } else {
      break
    }
  }

  # Offer to submit any schema overrides touched this session, once, at the very end -- not after
  # every single edit, so a DA working through several flags against the same schema isn't asked
  # the same question repeatedly.
  for (stem in touched_schemas) {
    axes <- strsplit(stem, "|", fixed = TRUE)[[1]]
    ans  <- .eri_prompt_menu(
      paste0("Submit your schema edits for '", axes[2], "/", axes[4], "' for a maintainer to fold in?"),
      c("Yes", "No")
    )
    if (ans == 1L) {
      note <- .eri_prompt_line("Optional note for the ticket: ")
      eri_dq_schema_submit(axes[1], axes[2], axes[3], axes[4],
                           note = if (nzchar(trimws(note))) note else NULL, azcontainer = data_con)
    }
  }

  invisible(status)
}
