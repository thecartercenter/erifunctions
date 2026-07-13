#### eri_do — the unified interactive pipeline wizard (Phase A: CMR; Phase B: ingest; Phase C.1: ODK; Phase C.2: onboarding) ####
#
# Design consult: docs/design/interactive-wizard-consult.md. Corrects the docs-site redesign's
# direction -- that work optimized *discoverability* (can a DA find the right guide); this optimizes
# *execution* (can a DA do the job without learning the tool). A DA answers names/decisions;
# eri_do() calls the existing, tested scriptable core in order. It never reimplements pipeline
# logic and it is never the only way in -- every function it calls stays fully usable directly, in
# a script or CI.
#
# Phase A shipped the CMR flow end to end, proving the framework: pick a country, pick a local
# file, confirm the month, watch upload -> stage -> split happen, then hand off directly into
# eri_dq_review()'s existing loop (extracted as .eri_dq_review_loop(), R/dq_review.R) for triage and
# approval.
#
# Phase B adds surveillance ingest (.eri_flow_ingest()) on the same shared helpers
# (.eri_prompt_pick_country(), .eri_prompt_pick_file(), .eri_wizard_step(), ...) -- but NOT ODK,
# deliberately deferred: ingest's period is free-form text embedded in the staged filename (no fixed
# YYYYMM convention the way CMR has), and its DQ flags land in the generic eri_logs() backlog, not
# eri_cmr_dq_report()'s per-sheet shape eri_dq_review()'s loop is built for -- genuinely different
# enough to need its own careful treatment rather than being rushed in alongside a third flow. Its
# DQ step is therefore a summary + pointer at the existing scriptable triage tools
# (eri_logs()/eri_dq_flag_resolve()/eri_logs_resolve()), not a full interactive per-flag walker --
# that's real, but smaller, follow-on work, not built here.
#
# Phase C.1 adds ODK (.eri_flow_odk()): connect, discover the project/form (a DA rarely knows the
# numeric project id or exact xmlFormId by heart), register if not already, sync. This flow stops at
# "submissions are in research/raw/" rather than reaching all the way to eri_approve() the way
# CMR/ingest do -- there is no single stage-then-approve function for ODK data (da-odk-guide.Rmd's
# own approve step is a MANUAL eri_write() after ad hoc quality-checking), so completing that gap
# honestly is real, separate follow-on work, not something to fake here.
#
# Phase C.2 adds onboarding (.eri_flow_onboard()): scaffolds a NEW country/disease/data-type space
# via eri_onboard_country()/eri_onboard_cmr()/eri_onboard_disease() -- dry-run preview, confirm,
# write for real, then stop. Deliberately does NOT walk the DA through filling in the schema's TODO
# columns, validating, or submitting a PR -- da-onboard-guide.Rmd's own golden rule is "onboarding
# scaffolds; it doesn't finish for you," and those steps are real domain expertise (which columns
# this country's data actually has) no wizard should fabricate. The three eri_onboard_*() functions
# already print their own "Next steps" via cli_inform, so the flow doesn't re-print or paraphrase
# them -- one copy of that text, not two that can drift.
#
# Phase C.3 retired eri_guide() (deprecated + narrowed to a static lookup, R/guide.R) and re-audited
# the doc cut against what actually shipped in A-C.2, finding it much narrower than the consult
# estimated -- see docs/roadmap.md's Phase C.3 entry. Progress-detection polish is Phase D, not
# started.
#
# Concrete R control flow, not a declarative flow schema. The original consult proposed a
# `flow_map.yaml`/`kind:`-dispatch engine "once a second/third flow gives it real shape to
# generalize from" -- now that there are four (CMR: multi-step + a rich DQ loop; ingest: one call +
# a log-summary DQ step; ODK: discover-then-register-then-sync with no approve step at all;
# onboarding: three genuinely different scaffold shapes behind one menu), the evidence says
# otherwise: the flows don't share enough TOP-LEVEL shape to make a declarative schema worth
# building -- what's actually shared and reused is the low-level HELPER vocabulary
# (.eri_prompt_pick_file(), .eri_wizard_step(), .eri_wizard_confirm(), .eri_prompt_pick_or_type()),
# not a generic step sequence. That's the right level of reuse; a schema forcing these flows into
# one shape would be reuse for its own sake, not because the flows are actually alike.

# Shared disease pick-list for flows whose country/disease space has no backing registry
# (ADR-0012 deliberately leaves disease unregistered). One constant so the ingest and ODK flows
# can't silently diverge from each other.
.KNOWN_DISEASES <- c("malaria", "oncho", "lf", "sch", "sth")

# Both onboarding schema templates (eri_onboard_country()/eri_onboard_cmr()) take a language for
# their comments -- ERI's own countries include Francophone ones (Haiti), and the consult itself
# calls for "language from a pick-list" (interactive-wizard-consult.md). Returns "en"/"fr", or NA on
# cancel -- same escape-hatch convention as every other prompt in this file.
#' @keywords internal
.eri_wizard_prompt_language <- function() {
  choice <- .eri_prompt_menu("Schema comments in which language?", c("English", "French"))
  if (choice == 0L) return(NA_character_)
  c("en", "fr")[[choice]]
}

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

#### Phase B: surveillance ingest ####

# A pick-list with a trailing "Other (type it)" escape hatch, for open-ended-but-usually-known
# values (e.g. disease, which ADR-0012's data model deliberately does NOT register -- only
# data_source/data_type/format/layer are; disease stays free text so onboarding a new one is a data
# change, not a code change). Returns NA on cancel/ESC at either step.
#' @keywords internal
.eri_prompt_pick_or_type <- function(prompt, known, type_prompt) {
  choice <- .eri_prompt_menu(prompt, c(known, "Other (type it)"))
  if (choice == 0L) return(NA_character_)
  if (choice == length(known) + 1L) {
    typed <- .eri_prompt_line(type_prompt)
    return(if (nzchar(trimws(typed))) tolower(trimws(typed)) else NA_character_)
  }
  known[[choice]]
}

# Surveillance ingest has no country registry the way CMR's rb-expansion pipeline does (eri_ingest()
# is deliberately not country-locked -- it's what lets the DA guides demo on a fake atlantis
# country) -- so country is a validated typed prompt, not a pick-list. Re-asks until it looks like a
# real code (letters only) or the DA cancels (blank). Bounded 2-15 chars, not 2-4: real codes are
# short (sdn, uga), but the package's own sandbox demo country is "atlantis" (8 letters) -- a
# tighter cap would reject the exact case this prompt's own docs point to.
#' @keywords internal
.eri_wizard_prompt_country_code <- function() {
  repeat {
    typed <- .eri_prompt_line("Which country is this data for? (e.g. sdn; blank to cancel): ")
    if (!nzchar(trimws(typed))) return(NA_character_)
    code <- tolower(trimws(typed))
    if (grepl("^[a-z]{2,15}$", code)) return(code)
    cli::cli_alert_warning("Country codes are letters only (e.g. {.val sdn}, {.val atlantis}) -- try again.")
  }
}

# Same auto-detection posture as .eri_wizard_should_mirror_cmr(), for the general ingest pipeline's
# legacy mirror ("hsp-mal", currently registered for dr/ht only -- see .eri_pipeline_registry).
# Returns FALSE outright for a country that was never registered for this mirror at all (most
# countries), since eri_ingest() itself would abort passing mirror_pipeline for an unregistered
# country -- the wizard must never construct a call it knows will fail.
#' @keywords internal
.eri_wizard_should_mirror_ingest <- function(country, disease, data_source, data_type) {
  reg <- .eri_pipeline_registry[["hsp-mal"]]
  if (is.null(reg$country_map[[country]])) return(FALSE)
  st <- tryCatch(
    suppressMessages(eri_cutover_status(country, disease, data_source, data_type)),
    error = function(e) list(eligible = FALSE)
  )
  !isTRUE(st$eligible)
}

# The surveillance ingest flow: collect country/disease/channel/measure/file, confirm, then one
# eri_ingest() call does raw-archive + DQ-check + stage (unlike CMR's multi-step
# upload/stage/split -- eri_ingest() is a single call by design). Any DQ flags it logged are
# summarized with a pointer at the existing scriptable triage tools (eri_logs()/
# eri_dq_flag_resolve()/eri_logs_resolve()) rather than a full interactive walker -- see the file
# header for why that's deliberately smaller than the CMR flow's DQ stage. Approval's period is
# free text (eri_approve() matches it against the staged filename, no fixed convention to detect).
#' @keywords internal
.eri_flow_ingest <- function() {
  cli::cli_h1("Bring in a surveillance dataset")

  country <- .eri_wizard_prompt_country_code()
  if (is.na(country)) return(invisible(NULL))

  disease <- .eri_prompt_pick_or_type(
    "Which disease?", .KNOWN_DISEASES,
    "Disease (blank to cancel): "
  )
  if (is.na(disease)) return(invisible(NULL))

  dm <- .eri_data_model()
  data_source <- .eri_prompt_pick_or_type(
    "How did this data arrive?",
    # cmr/odk are transitional read-only tokens (ADR-0012) -- never offered for a new write.
    setdiff(names(dm$data_sources), c("cmr", "odk")),
    "Channel (blank to cancel): "
  )
  if (is.na(data_source)) return(invisible(NULL))

  data_type <- .eri_prompt_pick_or_type(
    "What does each row count?", names(dm$data_types),
    "Measure (blank to cancel): "
  )
  if (is.na(data_type)) return(invisible(NULL))

  local_path <- .eri_prompt_pick_file("Where is the file on your computer?")
  if (is.null(local_path)) return(invisible(NULL))

  cli::cli_h3("Ready to bring this in")
  cli::cli_bullets(c(
    "*" = "Country: {.strong {toupper(country)}}",
    "*" = "Disease: {.strong {disease}}",
    "*" = "Channel: {.strong {data_source}} / Measure: {.strong {data_type}}",
    "*" = "File:    {.strong {basename(local_path)}}"
  ))
  cli::cli_alert_info("I'll archive it, check data quality, and stage it for approval.")
  if (!.eri_wizard_confirm("Go ahead?")) return(invisible(NULL))

  data_con <- .eri_logs_con(NULL)
  mirror_pipeline <- if (isTRUE(.eri_wizard_should_mirror_ingest(country, disease, data_source, data_type))) {
    cli::cli_alert_info("This country is still in the parallel run, so I'll also send the raw file to the legacy pipeline.")
    "hsp-mal"
  } else {
    NULL
  }

  ing <- .eri_wizard_step(function() {
    eri_ingest(local_path, country, disease, data_source = data_source, data_type = data_type,
              data_con = data_con, mirror_pipeline = mirror_pipeline)
  })
  if (!ing$ok) return(invisible(NULL))

  open_logs <- tryCatch(
    eri_logs(country, disease, data_source, data_type, status = "needs_review", data_con = data_con),
    error = function(e) NULL
  )
  if (!is.null(open_logs) && nrow(open_logs) > 0L) {
    cli::cli_alert_warning("{nrow(open_logs)} log entr{?y/ies} need review before this can be approved.")
    cli::cli_bullets(c(
      "i" = "Run {.fn eri_logs} to see them, {.fn eri_dq_flag_resolve} to triage each flag, then {.fn eri_logs_resolve} to close the entry out."
    ))
    if (!.eri_wizard_confirm("Approve anyway? (only if you've already reviewed this)")) {
      cli::cli_alert_info("Left staged -- run {.fn eri_do} again once you've triaged the flags.")
      return(invisible(NULL))
    }
  }

  period <- .eri_prompt_line(
    "What period identifies this data? (used to find the staged file, e.g. '2024-01'; blank to cancel): "
  )
  if (!nzchar(trimws(period))) {
    cli::cli_alert_info("Left staged -- run {.fn eri_do} again any time to finish approving it.")
    return(invisible(NULL))
  }

  ap <- .eri_wizard_step(function() {
    eri_approve(country, disease, data_source, period, data_type = data_type, azcontainer = data_con)
  })
  if (ap$ok) {
    cli::cli_alert_success("Done. This dataset is approved and in the catalog.")
    cli::cli_bullets(c(
      "i" = "Query it with {.fn eri_query} or see it in {.code eri_catalog_query(country = \"{country}\")}."
    ))
  }
  invisible(NULL)
}

#### Phase C.1: ODK Central ####

# The ODK flow: connect, discover the project/form (a DA rarely knows the numeric project id or
# exact xmlFormId by heart -- list_odk_projects()/list_odk_forms() turn that into two pick-lists),
# register if this form isn't already tracked (using con$url as server_url -- init_odk_connection()
# already has it, no need to ask again -- and .KNOWN_COUNTRY_CODES, R/odk_registry.R's own
# registration-validation list, as the country pick-list -- ODK registration is genuinely
# country-locked, unlike ingest), then sync. Stops there: there is no single stage-then-approve
# function for ODK data (da-odk-guide.Rmd's own next step is a manual eri_write() after ad hoc
# quality-checking), so this flow honestly ends at "synced to raw/," not a fabricated approve step.
#' @keywords internal
.eri_flow_odk <- function() {
  cli::cli_h1("Pull in ODK survey submissions")

  con_result <- .eri_wizard_step(function() init_odk_connection())
  if (!con_result$ok) return(invisible(NULL))
  con <- con_result$value

  projects <- .eri_wizard_step(function() list_odk_projects(con = con))
  if (!projects$ok || nrow(projects$value) == 0L) {
    cli::cli_alert_warning("No ODK projects visible with this account.")
    return(invisible(NULL))
  }
  project_choice <- .eri_prompt_menu("Which ODK project?", projects$value$project)
  if (project_choice == 0L) return(invisible(NULL))
  project_id <- projects$value$project_id[[project_choice]]

  forms <- .eri_wizard_step(function() list_odk_forms(con = con, project_id = project_id))
  if (!forms$ok || nrow(forms$value) == 0L) {
    cli::cli_alert_warning("No forms found in that project.")
    return(invisible(NULL))
  }
  form_choice <- .eri_prompt_menu("Which form?", forms$value$name)
  if (form_choice == 0L) return(invisible(NULL))
  form_id <- forms$value$xmlFormId[[form_choice]]

  data_con   <- .eri_logs_con(NULL)
  registered <- tryCatch(eri_odk_list_registered(data_con = data_con), error = function(e) NULL)
  already    <- !is.null(registered) && nrow(registered) > 0L &&
    any(registered$project_id == project_id & registered$form_id == form_id &
          registered$server_url == con$url)

  if (!isTRUE(already)) {
    cli::cli_alert_info("This form isn't registered yet -- I need a country and disease to file it under.")
    country_map <- .KNOWN_COUNTRY_CODES
    names(country_map) <- .KNOWN_COUNTRY_CODES
    country <- .eri_prompt_pick_country(country_map, "Which country?")
    if (is.null(country)) return(invisible(NULL))

    disease <- .eri_prompt_pick_or_type(
      "Which disease?", .KNOWN_DISEASES,
      "Disease (blank to cancel): "
    )
    if (is.na(disease)) return(invisible(NULL))

    if (!.eri_wizard_confirm(sprintf("Register this form as %s/%s?", country, disease))) {
      return(invisible(NULL))
    }

    reg <- .eri_wizard_step(function() {
      eri_odk_register(project_id, form_id, country, disease,
                       server_url = con$url, con = con, data_con = data_con)
    })
    if (!reg$ok) return(invisible(NULL))
  }

  if (!.eri_wizard_confirm("Sync submissions now?")) return(invisible(NULL))

  sy <- .eri_wizard_step(function() eri_odk_sync(project_id, form_id, con = con, data_con = data_con))
  if (!sy$ok) return(invisible(NULL))

  cli::cli_alert_success("Done. Submissions are synced to research/raw/.")
  cli::cli_bullets(c(
    "i" = "Next: quality-check and stage this the same way as a surveillance extract -- see the surveillance ingest guide -- then eri_approve() it in.",
    "i" = "Run {.fn eri_do} again any time to sync new submissions."
  ))
  invisible(NULL)
}

#### Phase C.2: onboarding ####

# Onboarding's golden rule (da-onboard-guide.Rmd): "it scaffolds; it doesn't finish for you." The
# three eri_onboard_*() functions already write their own "Next steps" (open the file, fill in the
# TODOs, validate, submit via PR) via cli_inform -- the wizard must NOT re-print or paraphrase that,
# doing so risks the two copies drifting. Its job stops at the mechanical, no-judgment-call part:
# which kind, which names, dry-run preview, confirm, write for real. Filling in disease-specific
# schema columns is real domain expertise no wizard should fabricate.
#' @keywords internal
.eri_flow_onboard <- function() {
  cli::cli_h1("Onboard a new country, disease, or data type")

  kind <- .eri_prompt_menu("What are you setting up?", c(
    "Surveillance country/disease (case or aggregate reporting)",
    "CMR country (monthly Case Management Report)",
    "NTD disease (MDA + prevalence schemas, no country folders yet)"
  ))
  if (kind == 1L) {
    .eri_flow_onboard_surveillance()
  } else if (kind == 2L) {
    .eri_flow_onboard_cmr()
  } else if (kind == 3L) {
    .eri_flow_onboard_disease()
  }

  invisible(NULL)
}

# No country/disease registry to pick-list from here -- onboarding's entire purpose is standing up
# a space for a country/disease that ISN'T registered anywhere yet. Country code and full name are
# both free-typed; disease reuses the shared pick-list-plus-Other pattern.
#' @keywords internal
.eri_flow_onboard_surveillance <- function() {
  country <- .eri_wizard_prompt_country_code()
  if (is.na(country)) return(invisible(NULL))

  country_name <- .eri_prompt_line("Full country name (e.g. Uganda; blank to cancel): ")
  if (!nzchar(trimws(country_name))) return(invisible(NULL))

  disease <- .eri_prompt_pick_or_type(
    "Which disease?", .KNOWN_DISEASES,
    "Disease (blank to cancel): "
  )
  if (is.na(disease)) return(invisible(NULL))

  language <- .eri_wizard_prompt_language()
  if (is.na(language)) return(invisible(NULL))

  preview <- .eri_wizard_step(function() {
    eri_onboard_country(country, country_name, disease, language = language, dry_run = TRUE)
  })
  if (!preview$ok) return(invisible(NULL))

  if (!.eri_wizard_confirm("Write this schema template and create the Azure folders?")) {
    return(invisible(NULL))
  }

  result <- .eri_wizard_step(function() {
    eri_onboard_country(country, country_name, disease, language = language)
  })
  if (!result$ok) return(invisible(NULL))

  invisible(NULL)
}

# CMR's Azure folders are opt-in (create_dirs=FALSE by default) -- but the whole point of onboarding
# through the wizard is to stand up a space that's actually ready to receive a report, so this flow
# always asks for create_dirs = TRUE. A DA who only wants the local schema template can call
# eri_onboard_cmr() directly.
#' @keywords internal
.eri_flow_onboard_cmr <- function() {
  country <- .eri_wizard_prompt_country_code()
  if (is.na(country)) return(invisible(NULL))

  country_name <- .eri_prompt_line("Full country name (e.g. Uganda; blank to cancel): ")
  if (!nzchar(trimws(country_name))) return(invisible(NULL))

  language <- .eri_wizard_prompt_language()
  if (is.na(language)) return(invisible(NULL))

  preview <- .eri_wizard_step(function() {
    eri_onboard_cmr(country, country_name, language = language, create_dirs = TRUE, dry_run = TRUE)
  })
  if (!preview$ok) return(invisible(NULL))

  if (!.eri_wizard_confirm("Write this CMR schema template and create the Azure folders?")) {
    return(invisible(NULL))
  }

  result <- .eri_wizard_step(function() {
    eri_onboard_cmr(country, country_name, language = language, create_dirs = TRUE)
  })
  if (!result$ok) return(invisible(NULL))

  invisible(NULL)
}

# Local-only (no Azure folders at all -- eri_onboard_disease()'s own design, since NTD programs
# don't get a country/disease space until a surveillance or CMR onboard also runs). Argument order
# is disease-then-country, matching the real function signature exactly (easy to get backwards).
#' @keywords internal
.eri_flow_onboard_disease <- function() {
  disease <- .eri_prompt_pick_or_type(
    "Which disease?", .KNOWN_DISEASES,
    "Disease (blank to cancel): "
  )
  if (is.na(disease)) return(invisible(NULL))

  country <- .eri_wizard_prompt_country_code()
  if (is.na(country)) return(invisible(NULL))

  which_types <- .eri_prompt_menu("Which schema(s) do you need?", c(
    "Both (MDA + prevalence)",
    "MDA only",
    "Prevalence only"
  ))
  if (which_types == 0L) return(invisible(NULL))
  data_types <- switch(which_types, c("mda", "prevalence"), "mda", "prevalence")

  preview <- .eri_wizard_step(function() {
    eri_onboard_disease(disease, country, data_types = data_types, dry_run = TRUE)
  })
  if (!preview$ok) return(invisible(NULL))

  if (!.eri_wizard_confirm("Write these schema template(s)?")) return(invisible(NULL))

  result <- .eri_wizard_step(function() eri_onboard_disease(disease, country, data_types = data_types))
  if (!result$ok) return(invisible(NULL))

  invisible(NULL)
}

#' Bring a monthly report into the system, interactively (the guided console front door)
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A menu-driven wizard that carries a Data Analyst through an entire pipeline run -- which
#' country, which file, which reporting period -- and calls the existing scriptable core on their
#' behalf. Never asks for a function name or an Azure path. `mirror_pipeline` is auto-detected from
#' [eri_cutover_status()] and never asked about. Every mutation is one already-tested function
#' ([eri_upload()], [eri_stage_cmr()], [eri_split_cmr()], [eri_ingest()], [eri_approve()],
#' [eri_odk_register()], [eri_odk_sync()], [eri_onboard_country()], [eri_onboard_cmr()],
#' [eri_onboard_disease()]), and data quality review/approval hands off directly into the same loop
#' [eri_dq_review()] uses (for CMR) or points at the scriptable triage tools directly ([eri_logs()],
#' [eri_dq_flag_resolve()], for surveillance ingest) -- nothing here is reimplemented, and every
#' function this calls stays fully usable directly in a script or CI.
#'
#' Currently covers bringing in a monthly CMR report, bringing in a surveillance dataset
#' (CSV/Excel line-list), pulling in ODK survey submissions, and onboarding a new country, disease,
#' or data type, end to end. ODK sync stops at `research/raw/` -- there is no automated
#' stage-then-approve path for ODK data yet (the real guide shows a manual [eri_write()] step) --
#' and onboarding stops once the schema template(s) are written (and, for surveillance/CMR, the
#' Azure folders exist -- an NTD disease's MDA/prevalence schemas are local-only, by
#' [eri_onboard_disease()]'s own design) -- filling in the schema's disease-specific columns,
#' validating it, and submitting it via pull request stay a human, judgment-driven step (see
#' `vignettes/da-onboard-guide.Rmd`'s "onboarding scaffolds; it doesn't finish for you"). The wizard
#' is honest about handing off at both points rather than fabricating steps the underlying tooling
#' doesn't support or shouldn't automate.
#'
#' **Interactive only.** In a script or CI, use the scriptable core directly: [eri_upload()],
#' [eri_stage_cmr()], [eri_split_cmr()], [eri_cmr_dq_report()], [eri_approve_cmr()], [eri_ingest()],
#' [eri_approve()], [eri_odk_sync()], [eri_onboard_country()].
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
      "Bring in a surveillance dataset (a CSV/Excel line-list)",
      "Pull in ODK survey submissions",
      "Onboard a new country, disease, or data type",
      "Review & approve something already staged (DQ review)",
      "Exit"
    ))
    if (choice == 0L || choice == 6L) break

    if (choice == 1L) {
      .eri_flow_cmr()
    } else if (choice == 2L) {
      .eri_flow_ingest()
    } else if (choice == 3L) {
      .eri_flow_odk()
    } else if (choice == 4L) {
      .eri_flow_onboard()
    } else if (choice == 5L) {
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
