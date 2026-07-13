#### eri_do — the unified interactive pipeline wizard (Phase A: CMR) ####
#
# Design consult: docs/design/interactive-wizard-consult.md. Corrects the docs-site redesign's
# direction -- that work optimized *discoverability* (can a DA find the right guide); this optimizes
# *execution* (can a DA do the job without learning the tool). A DA answers names/decisions;
# eri_do() calls the existing, tested scriptable core in order. It never reimplements pipeline
# logic and it is never the only way in -- every function it calls stays fully usable directly, in
# a script or CI.
#
# Phase A ships one flow (CMR) end to end, proving the framework: pick a country, pick a local
# file, confirm the month, watch upload -> stage -> split happen, then hand off directly into
# eri_dq_review()'s existing loop (extracted as .eri_dq_review_loop(), R/dq_review.R) for triage and
# approval. Later phases add surveillance ingest / ODK / onboarding flows on the same helpers
# (.eri_prompt_pick_country(), .eri_prompt_pick_file(), .eri_wizard_step(), ...), and retire
# eri_guide()'s interactive wizard once every flow has a real home here -- not yet, this phase only
# adds a flow, it does not remove anything.
#
# Concrete R control flow, not a declarative flow schema (a `flow_map.yaml`/`kind:`-dispatch engine
# was in the original consult's design, but building a mini-DSL for a single consumer -- Phase A has
# exactly one flow -- is the premature abstraction this whole redesign has repeatedly avoided
# elsewhere. Once Phase B adds ingest/ODK as a second and third real consumer of the same shape,
# that's the point to extract a shared schema from what actually repeats, not before.)

# Builds a numbered pick-list from a named country_map (code = display name is backwards here --
# `.eri_pipeline_registry[[...]]$country_map` maps OUR code to the registry's own downstream code,
# so the DISPLAY uses names(country_map), the pick-list choice IS the code) and returns the picked
# code, or NULL on cancel/ESC. Never makes a DA type a country code.
#' @keywords internal
.eri_prompt_pick_country <- function(country_map, prompt = "Which country?") {
  codes <- names(country_map)
  if (length(codes) == 0L) {
    cli::cli_abort("No countries are registered for this pipeline yet.")
  }
  choice <- .eri_prompt_menu(prompt, toupper(codes))
  if (choice == 0L) return(NULL)
  codes[[choice]]
}

# The actual OS-level file dialog attempt (rstudioapi::selectFile() when available -- works over a
# remote RStudio Server session too -- else base R's file.choose(), a native OS dialog). Isolated
# into its own tiny function so tests can mock JUST this piece: file.choose()/rstudioapi::selectFile()
# are real, blocking, interactive GUI calls that base-package locking makes impossible to safely
# mock via local_mocked_bindings() -- a test that let one run for real in headless CI would either
# error unpredictably or hang waiting for a dialog that can never appear. Returns a path string, or
# NULL if unavailable/cancelled.
#' @keywords internal
.eri_wizard_raw_file_dialog <- function(prompt) {
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    tryCatch(rstudioapi::selectFile(caption = prompt), error = function(e) NULL)
  } else {
    tryCatch(file.choose(), error = function(e) NULL)
  }
}

# A local file picker built on .eri_wizard_raw_file_dialog(), falling back to a validated typed
# path as the last resort (headless Linux with no GUI, or the dialog was cancelled). Re-asks if the
# picked/typed path doesn't exist. Returns NULL on cancel.
#' @keywords internal
.eri_prompt_pick_file <- function(prompt) {
  cli::cli_alert_info(prompt)
  path <- .eri_wizard_raw_file_dialog(prompt)
  if (is.null(path) || !nzchar(path)) {
    path <- .eri_prompt_line("Or type/paste the full path to the file (blank to cancel): ")
    if (!nzchar(trimws(path))) return(NULL)
  }
  if (!file.exists(path)) {
    cli::cli_alert_danger("File not found: {.path {path}}")
    return(.eri_prompt_pick_file(prompt))
  }
  path
}

# A plain yes/no confirmation, built on .eri_prompt_menu() rather than a bespoke prompt -- keeps
# every menu in the wizard using the same two-choice ESC-means-no convention.
#' @keywords internal
.eri_wizard_confirm <- function(prompt) {
  .eri_prompt_menu(prompt, c("Yes", "No")) == 1L
}

# Runs one core-function call, catching an abort and turning it into a friendly message instead of
# a stack trace dumped at a non-developer -- never reimplements what the call does, just wraps it.
# Returns list(ok, value); callers check `ok` and stop the flow (not the whole R session) on
# failure. The scriptable core already narrates its own progress (R/console.R's convention, e.g.
# eri_stage_cmr()'s own "Staged: ..." line) -- this does not print a redundant success message.
#' @keywords internal
.eri_wizard_step <- function(fn) {
  tryCatch(
    list(ok = TRUE, value = fn()),
    error = function(e) {
      cli::cli_alert_danger("That step failed: {conditionMessage(e)}")
      list(ok = FALSE, value = NULL)
    }
  )
}

# Detects a period from the filename using the EXACT convention eri_split_cmr() itself already
# parses (a leading 6-digit YYYYMM followed by "_", e.g. "202406_uga_cmr.xlsx") -- reusing this
# regex verbatim rather than a looser guess keeps the wizard's confirmation and the core's own
# auto-detection from ever silently disagreeing. Returns NA_character_ if the filename doesn't
# follow that convention (a DA's downloaded file often won't -- confirmation/fallback handles it).
#' @keywords internal
.eri_wizard_detect_period <- function(filename) {
  detected <- regmatches(filename, regexpr("^\\d{6}(?=_)", filename, perl = TRUE))
  if (length(detected) == 0L) return(NA_character_)
  detected
}

# Collects a confirmed YYYYMM period: offers the filename-detected value if there is one, else
# asks directly, re-prompting until it matches 6 digits or the DA cancels (blank).
#' @keywords internal
.eri_wizard_pick_period <- function(filename) {
  detected <- .eri_wizard_detect_period(filename)
  if (!is.na(detected)) {
    if (.eri_wizard_confirm(paste0(
      "I read the period as ", detected, " from the file. Is that the reporting month?"
    ))) {
      return(detected)
    }
  }
  repeat {
    typed <- .eri_prompt_line("Reporting period, as YYYYMM (e.g. 202406; blank to cancel): ")
    if (!nzchar(trimws(typed))) return(NA_character_)
    if (grepl("^\\d{6}$", trimws(typed))) return(trimws(typed))
    cli::cli_alert_warning("That doesn't look like YYYYMM (six digits) -- try again.")
  }
}

# Builds the projects-blob destination path the exact same way eri_stage_cmr() itself expects to
# find it (raw/filled_templates/{country}/{period}/{filename}) -- reading the SAME registry entry,
# so the wizard and the core can't drift into two different conventions.
#' @keywords internal
.eri_derive_cmr_destination <- function(country, period, filename) {
  reg <- .eri_pipeline_registry[["rb-expansion"]]
  paste(c(reg$project_folder, reg$raw_dir, country, period, filename), collapse = "/")
}

# Auto-detects whether this workbook's split should also mirror to the legacy hsp-mal-era
# contractor pipeline (mirror_pipeline = "rb-expansion" for CMR) -- the DA is never asked. Mirrors
# if ANY constituent disease/measure stream this workbook feeds hasn't yet proven ADR-0015 cutover
# parity (eri_cutover_status()$eligible); an unrecorded/unknown stream defaults to mirroring, the
# safe direction (an extra legacy copy never loses data; a missing one breaks the parallel run).
# eri_cutover_status() narrates its own status report to the console (cli_h3()/cli_alert_*) for a
# script author calling it directly -- that's noise inside the wizard, which only needs the
# boolean, so it's suppressed here specifically, not changed for any other caller.
#' @keywords internal
.eri_wizard_should_mirror_cmr <- function(country, plan) {
  any(vapply(seq_len(nrow(plan)), function(i) {
    st <- tryCatch(
      suppressMessages(
        eri_cutover_status(country, plan$disease[[i]], "programmatic", plan$data_type[[i]])
      ),
      error = function(e) list(eligible = FALSE)
    )
    !isTRUE(st$eligible)
  }, logical(1)))
}

# If this country/period was already split in an earlier session (interrupted mid-pipeline, or
# just re-run), offer to resume straight into DQ review instead of re-uploading/re-staging/
# re-splitting from scratch -- the interrupt-safety the wizard needs, for free, because the core
# it calls already persists every step and eri_cmr_last_plan() can always reconstruct it.
#' @keywords internal
.eri_wizard_detect_cmr_progress <- function(country, period, data_con) {
  tryCatch(eri_cmr_last_plan(country, period, data_con = data_con), error = function(e) NULL)
}

# The CMR flow: upload -> stage -> split (with auto-detected mirroring) -> hand off to the existing
# eri_dq_review() loop for triage and approval. Every mutation is one already-tested scriptable-core
# call (eri_upload(), eri_stage_cmr(), eri_split_cmr(), .eri_dq_review_loop()); this function only
# collects inputs and calls them in order.
#' @keywords internal
.eri_flow_cmr <- function() {
  cli::cli_h1("Bring this month's country report into the system")

  reg     <- .eri_pipeline_registry[["rb-expansion"]]
  country <- .eri_prompt_pick_country(reg$country_map, "Which country filed the report?")
  if (is.null(country)) return(invisible(NULL))

  data_con <- .eri_logs_con(NULL)

  local_path <- .eri_prompt_pick_file("Where is the filled Excel on your computer?")
  if (is.null(local_path)) return(invisible(NULL))
  filename <- basename(local_path)

  period <- .eri_wizard_pick_period(filename)
  if (is.na(period)) return(invisible(NULL))

  existing_plan <- .eri_wizard_detect_cmr_progress(country, period, data_con)
  if (!is.null(existing_plan) && nrow(existing_plan) > 0L) {
    if (.eri_wizard_confirm(paste0(
      "Looks like ", toupper(country), " / ", period, " was already split in an earlier session. ",
      "Skip straight to reviewing it?"
    ))) {
      status <- .eri_dq_review_loop(country, period, existing_plan, data_con)
      .eri_flow_cmr_closing(status, country, period)
      return(invisible(NULL))
    }
  }

  dest <- .eri_derive_cmr_destination(country, period, filename)
  cli::cli_h3("Ready to bring this in")
  cli::cli_bullets(c(
    "*" = "Country: {.strong {toupper(country)}}",
    "*" = "Month:   {.strong {period}}",
    "*" = "File:    {.strong {filename}}"
  ))
  cli::cli_alert_info("I'll upload it, stage it, and split it into per-disease measures. Then we'll review data quality.")
  if (!.eri_wizard_confirm("Go ahead?")) return(invisible(NULL))

  projects_con <- suppressMessages(get_azure_storage_connection(storage_name = "projects"))

  up <- .eri_wizard_step(function() eri_upload(local_path, dest, azcontainer = projects_con))
  if (!up$ok) return(invisible(NULL))

  # Thread the SAME projects_con/data_con opened above through every remaining call -- otherwise
  # each one opens its own default connection, extra live-Azure round-trips a DA sitting at the
  # wizard shouldn't pay for.
  st <- .eri_wizard_step(function() {
    eri_stage_cmr(country, period, projects_con = projects_con, data_con = data_con)
  })
  if (!st$ok) return(invisible(NULL))

  # Dry-run first: the routing plan (which diseases/measures this workbook feeds) is only known by
  # actually reading it, and the mirror decision needs that plan -- so it can't be made before this
  # point. Nothing is written by the dry run.
  preview <- .eri_wizard_step(function() {
    eri_split_cmr(local_path, country, period = period, data_con = data_con,
                  projects_con = projects_con, dry_run = TRUE)
  })
  if (!preview$ok) return(invisible(NULL))
  if (isTRUE(.eri_wizard_should_mirror_cmr(country, preview$value))) {
    cli::cli_alert_info("This country is still in the parallel run, so I'll also send the raw file to the legacy pipeline.")
    mirror_pipeline <- "rb-expansion"
  } else {
    mirror_pipeline <- NULL
  }

  sp <- .eri_wizard_step(function() {
    eri_split_cmr(local_path, country, period = period, data_con = data_con,
                  projects_con = projects_con, mirror_pipeline = mirror_pipeline)
  })
  if (!sp$ok) return(invisible(NULL))
  plan <- sp$value

  cli::cli_h3("Now let's check data quality")
  status <- .eri_dq_review_loop(country, period, plan, data_con)
  .eri_flow_cmr_closing(status, country, period)
  invisible(NULL)
}

#' @keywords internal
.eri_flow_cmr_closing <- function(status, country, period) {
  if (status %in% c("approved", "force_approved")) {
    cli::cli_alert_success(
      "Done. This month's {toupper(country)} report is approved and in the catalog."
    )
    cli::cli_bullets(c(
      "i" = "Query it with {.fn eri_query} or see it in {.code eri_catalog_query(country = \"{country}\")}."
    ))
  } else {
    cli::cli_alert_info(
      "Left {toupper(country)} / {period} as-is -- run {.fn eri_do} again any time to pick up where you left off."
    )
  }
}

#' Bring a monthly report into the system, interactively (the guided console front door)
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A menu-driven wizard that carries a Data Analyst through an entire pipeline run -- which
#' country, which file, which month -- and calls the existing scriptable core on their behalf.
#' Never asks for a function name or an Azure path. `mirror_pipeline` is auto-detected from
#' [eri_cutover_status()] and never asked about. Every mutation is one already-tested function
#' ([eri_upload()], [eri_stage_cmr()], [eri_split_cmr()]), and data quality review/approval hands
#' off directly into the same loop [eri_dq_review()] uses -- nothing here is reimplemented, and
#' every function this calls stays fully usable directly in a script or CI.
#'
#' Currently covers bringing in a monthly CMR report end to end. Surveillance ingest, ODK sync, and
#' new-program onboarding are planned as the same framework grows (see
#' `docs/design/interactive-wizard-consult.md`).
#'
#' **Interactive only.** In a script or CI, use the scriptable core directly: [eri_upload()],
#' [eri_stage_cmr()], [eri_split_cmr()], [eri_cmr_dq_report()], [eri_approve_cmr()].
#'
#' @returns Invisibly, `NULL`. Every effect happens through the scriptable core it calls.
#' @examples
#' \dontrun{
#' eri_do()
#' }
#' @seealso [eri_dq_review()] for the data-quality review loop this hands off into,
#'   [eri_cutover_status()] for the mirroring criterion this checks automatically.
#' @export
eri_do <- function() {
  if (!rlang::is_interactive()) {
    cli::cli_abort(c(
      "{.fn eri_do} is interactive-only.",
      "i" = "In scripts/CI use the scriptable core directly: {.fn eri_upload}, {.fn eri_stage_cmr}, {.fn eri_split_cmr}, {.fn eri_cmr_dq_report}, {.fn eri_approve_cmr}."
    ))
  }

  repeat {
    choice <- .eri_prompt_menu("What are you trying to do?", c(
      "Bring this month's country report (CMR) into the system",
      "Review & approve something already staged (DQ review)",
      "Exit"
    ))
    if (choice == 0L || choice == 3L) break

    if (choice == 1L) {
      .eri_flow_cmr()
    } else if (choice == 2L) {
      country <- .eri_prompt_pick_country(.eri_pipeline_registry[["rb-expansion"]]$country_map,
                                          "Which country?")
      if (!is.null(country)) {
        period <- .eri_wizard_pick_period("")
        if (!is.na(period)) eri_dq_review(country, period)
      }
    }
  }

  invisible(NULL)
}
