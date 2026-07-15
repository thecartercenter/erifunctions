#### Tests for eri_dq_review() and its internal helpers ####
#
# scripted() (the interactive-menu mocking helper) lives in helper-scripted.R, shared with
# test-guide.R.

test_that("eri_dq_review refuses to run non-interactively", {
  expect_error(eri_dq_review("sdn", "202605"), "interactive-only")
})

test_that("eri_dq_review offers approve when clean, and approves on request", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  approved <- FALSE
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    eri_approve_cmr = function(...) { approved <<- TRUE },
    .eri_prompt_menu = scripted(list(1L)),  # "Approve"
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_true(approved)
})

test_that("eri_dq_review's loop returns 'approved'/'force_approved'/'exited', for R/wizard.R's flow hand-off", {
  # eri_dq_review() itself still returns invisibly (unchanged console behavior); assigning the
  # call captures the status .eri_dq_review_loop() now reports, which R/wizard.R's CMR flow reads
  # to decide whether to print its own "done" message.
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    eri_approve_cmr = function(...) invisible(NULL),
    .eri_prompt_menu = scripted(list(1L)),  # "Approve"
    .package = "erifunctions"
  )

  status <- eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_equal(status, "approved")
})

test_that("eri_dq_review's loop returns 'exited' when the DA exits from the clean menu", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    .eri_prompt_menu = scripted(list(4L)),  # "Exit"
    .package = "erifunctions"
  )

  status <- eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_equal(status, "exited")
})

test_that("eri_dq_review's 'print report' loops back to the same menu instead of exiting", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  printed <- FALSE
  approved <- FALSE
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    eri_approve_cmr = function(...) { approved <<- TRUE },
    .eri_dq_review_print_report = function(...) { printed <<- TRUE },
    .eri_prompt_menu = scripted(list(3L, 1L)),  # "Print report", then "Approve"
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_true(printed)
  expect_true(approved)
})

test_that("eri_dq_review's 'add a note' option logs a standalone note and loops back to the same menu", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  noted <- NULL
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    eri_dq_review_note = function(country, period, note, ...) {
      noted <<- list(country = country, period = period, note = note)
    },
    # "Nothing outstanding" menu: "Add a note", then "Exit"
    .eri_prompt_menu = scripted(list(2L, 4L)),
    .eri_prompt_line = scripted(list("Narrative section matches the data -- no discrepancy.")),
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_equal(noted$country, "sdn")
  expect_equal(noted$period, "202605")
  expect_equal(noted$note, "Narrative section matches the data -- no discrepancy.")
})

test_that("eri_dq_review's 'add a note' cancels cleanly on a blank note", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  note_logged <- FALSE
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    eri_dq_review_note = function(...) { note_logged <<- TRUE },
    .eri_prompt_menu = scripted(list(2L, 4L)),
    .eri_prompt_line = scripted(list("")),   # blank -- cancels
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_false(note_logged)
})

test_that("eri_dq_review exiting from the clean menu does not approve", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  approved <- FALSE
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) tibble::tibble(
      sheet = character(0), disease = character(0), data_type = character(0),
      log_path = character(0), flag_id = character(0), row = integer(0),
      excel_row = integer(0), column = character(0), value = character(0),
      issue = character(0), status = character(0)
    ),
    eri_approve_cmr = function(...) { approved <<- TRUE },
    .eri_prompt_menu = scripted(list(0L)),  # ESC / declined
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_false(approved)
})

flagged_tbl <- tibble::tibble(
  sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
  log_path = "sdn/oncho/programmatic/treatment/logs/dq.yaml",
  flag_id = "sdn/oncho/programmatic/treatment/logs/dq.yaml::1",
  row = 1L, excel_row = 7L, column = "district", value = "Kordofn",
  issue = "not an allowed value", status = "open", note = NA_character_
)

test_that("eri_dq_review marking the only flag not_important closes out the entry so approve can proceed", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  dq_report_calls <- 0L
  flag_resolved <- FALSE
  resolved_entries <- character(0)
  approved <- FALSE

  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    # Fetched exactly once -- eri_dq_review() applies the not_important
    # decision to its own in-memory copy rather than re-fetching (a
    # re-fetch would just re-derive the same "open" flag from the
    # still-unchanged staged data). This mock asserts that directly.
    eri_cmr_dq_report  = function(...) { dq_report_calls <<- dq_report_calls + 1L; flagged_tbl },
    eri_dq_flag_resolve = function(flag_id, status, note = NULL, data_con = NULL) {
      flag_resolved <<- TRUE
      expect_equal(status, "not_important")
    },
    eri_logs_resolve = function(log_path, ...) { resolved_entries <<- c(resolved_entries, log_path) },
    eri_approve_cmr = function(...) { approved <<- TRUE },
    # main menu: "Work through flags"; then within the flag: "Mark not important";
    # then back at the main menu (now clean): "Approve"
    .eri_prompt_menu = scripted(list(1L, 3L, 1L)),
    .eri_prompt_line = scripted(list("known template quirk")),  # the optional note
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_true(flag_resolved)
  expect_true(approved)
  # the entry was closed out (auto-summary) before the approve was attempted
  expect_true("sdn/oncho/programmatic/treatment/logs/dq.yaml" %in% resolved_entries)
  # and none of that required a second DQ check against Azure
  expect_equal(dq_report_calls, 1L)
})

test_that("eri_dq_review's force-approve requires a justification and a matching typed confirmation", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  forced_call <- NULL
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) flagged_tbl,
    eri_approve_cmr = function(country, period, plan = NULL, data_con = NULL, force = FALSE, justification = NULL) {
      forced_call <<- list(force = force, justification = justification)
    },
    # main menu: "Force-approve anyway"
    .eri_prompt_menu = scripted(list(3L)),
    .eri_prompt_line = scripted(list("Known quirk, confirmed with country.", "202605")),
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_true(forced_call$force)
  expect_equal(forced_call$justification, "Known quirk, confirmed with country.")
})

test_that("eri_dq_review cancels the force-approve when the typed confirmation doesn't match", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  approve_called <- FALSE
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) flagged_tbl,
    eri_approve_cmr = function(...) { approve_called <<- TRUE },
    # main menu: "Force-approve anyway", then "Exit" (since the cancelled force-approve loops back)
    .eri_prompt_menu = scripted(list(3L, 6L)),
    .eri_prompt_line = scripted(list("Justification.", "wrong period")),
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_false(approve_called)
})

test_that("eri_dq_review's 'adjust the schema' path offers to submit at the end and honors the answer", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  submitted <- FALSE
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) flagged_tbl,
    eri_dq_schema_edit = function(...) "C:/fake/override/path.yaml",
    .eri_open_file     = function(...) invisible(NULL),
    eri_dq_schema_submit = function(...) { submitted <<- TRUE },
    # main menu: "Work through flags"; within the flag: "Adjust the schema";
    # then back at main menu: "Exit" (still flagged -- adjusting the schema
    # doesn't itself resolve the flag); then the end-of-session submit offer: "Yes"
    .eri_prompt_menu = scripted(list(1L, 2L, 6L, 1L)),
    .eri_prompt_line = scripted(list("optional ticket note")),
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_true(submitted)
})

test_that("eri_dq_review's 're-run' offers to re-split only after a 'fix in source' path is known, and updates the plan", {
  withr::local_options(rlang_interactive = TRUE)
  plan1 <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                          dest = "a", n_rows = 1L)
  plan2 <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                          dest = "b_fixed", n_rows = 1L)
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("x", tmp)  # just needs to exist

  split_called_with <- NULL
  dq_report_calls   <- 0L
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan1,
    eri_cmr_dq_report  = function(...) { dq_report_calls <<- dq_report_calls + 1L; flagged_tbl },
    eri_split_cmr = function(path, country, ...) { split_called_with <<- path; plan2 },
    .eri_open_file = function(...) invisible(NULL),
    # main menu (iter 1): "Work through flags"; the one flag's menu: "Fix in
    # source" (only one flag, so the walk ends and returns to the main loop);
    # main menu (iter 2, still the same mocked flag): "Re-run the DQ check";
    # re-run's own sub-menu: "Yes" (re-split); main menu (iter 3): "Exit"
    .eri_prompt_menu = scripted(list(1L, 1L, 2L, 1L, 6L)),
    .eri_prompt_line = scripted(list(tmp)),  # the local workbook path prompt
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_match(split_called_with, "_fixed", fixed = TRUE)
  # exactly one fetch up front, one more from the explicit re-run -- "fix in
  # source" itself (unlike a re-run) must not trigger an extra DQ check
  expect_equal(dq_report_calls, 2L)
})

test_that("eri_dq_review's re-run scopes the fresh DQ check to just the resplit measure, preserving another measure's in-session decision", {
  # The real bug this guards against: eri_cmr_dq_report() always writes a
  # brand-new "open" dq_flags entry for EVERY row of whatever plan it's
  # given. Passing the whole workbook plan to "Re-run" would silently
  # discard every other measure's in-session not_important/noted decisions
  # the moment any single measure gets re-checked.
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(
    sheet = c("RB Treatment", "SCH Treatment"), disease = c("oncho", "sch"),
    data_type = c("treatment", "treatment"), dest = c("a", "b"), n_rows = c(1L, 1L)
  )
  oncho_flag <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
    log_path = "sdn/oncho/programmatic/treatment/logs/dq.yaml",
    flag_id = "sdn/oncho/programmatic/treatment/logs/dq.yaml::1",
    row = 1L, excel_row = 7L, column = "district", value = "Kordofn",
    issue = "not an allowed value", status = "open"
  )
  sch_flag <- tibble::tibble(
    sheet = "SCH Treatment", disease = "sch", data_type = "treatment",
    log_path = "sdn/sch/programmatic/treatment/logs/dq.yaml",
    flag_id = "sdn/sch/programmatic/treatment/logs/dq.yaml::1",
    row = 1L, excel_row = 9L, column = "target_pop", value = "-5",
    issue = "negative value", status = "open"
  )
  both <- dplyr::bind_rows(oncho_flag, sch_flag)
  new_oncho_plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho",
                                   data_type = "treatment", dest = "a_fixed", n_rows = 1L)

  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("x", tmp)

  dq_report_calls <- list()
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(country, period, plan = NULL, ...) {
      dq_report_calls[[length(dq_report_calls) + 1L]] <<- plan
      if (is.null(plan) || nrow(plan) == 2L) both else oncho_flag  # first call: whole workbook; rerun call: scoped
    },
    eri_split_cmr = function(...) new_oncho_plan,
    .eri_open_file = function(...) invisible(NULL),
    eri_dq_flag_resolve = function(...) invisible(NULL),
    eri_logs_resolve = function(...) invisible(NULL),
    # main menu: "Work through flags"; oncho flag: "Fix in source"; sch flag:
    # "Mark not important" (with a note); main menu: "Re-run the DQ check";
    # re-run's own sub-menu: "Yes"; main menu: "Exit"
    .eri_prompt_menu = scripted(list(1L, 1L, 3L, 2L, 1L, 6L)),
    .eri_prompt_line = scripted(list(tmp, "known template quirk")),
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))

  expect_length(dq_report_calls, 2L)
  # the re-run's own eri_cmr_dq_report() call was scoped to ONLY the resplit
  # (oncho) measure -- sch was never touched by it
  rerun_plan <- dq_report_calls[[2]]
  expect_equal(nrow(rerun_plan), 1L)
  expect_equal(rerun_plan$disease, "oncho")
})

test_that("eri_dq_review_note writes a standalone log entry, not tied to any flag", {
  logged <- NULL
  local_mocked_bindings(
    .eri_write_log = function(op_log, data_con, log_dir) {
      logged <<- list(op_log = op_log, log_dir = log_dir)
      "sdn/rblf/cmr/logs/fake_note.yaml"
    },
    .package = "erifunctions"
  )

  path <- suppressWarnings(
    eri_dq_review_note("sdn", "202605", "Narrative matches the data.",
                       data_con = structure(list(), class = "mock"))
  )

  expect_equal(path, "sdn/rblf/cmr/logs/fake_note.yaml")
  expect_equal(logged$log_dir, "sdn/rblf/cmr/logs")
  expect_equal(logged$op_log$operation, "dq_review_note")
  expect_equal(logged$op_log$note, "Narrative matches the data.")
  expect_equal(logged$op_log$parameters, list(country = "sdn", period = "202605"))
  expect_equal(logged$op_log$status, "success")
})

test_that("eri_dq_review_note rejects a blank note", {
  expect_error(
    eri_dq_review_note("sdn", "202605", "", data_con = structure(list(), class = "mock")),
    "non-empty"
  )
  expect_error(
    eri_dq_review_note("sdn", "202605", "   ", data_con = structure(list(), class = "mock")),
    "non-empty"
  )
})

test_that(".eri_dq_review_fix_in_source forks even when the ORIGINAL filename contains '_fixed' not at the end", {
  tmp_dir <- withr::local_tempdir()
  # "_fixed" appears mid-name here, not as the working-copy suffix -- must
  # still be treated as an unforked original and copied, not opened directly.
  original <- file.path(tmp_dir, "202605_fixed_income_report.xlsx")
  writeLines("x", original)

  local_path_env <- new.env(parent = emptyenv())
  local_path_env$path <- NULL
  opened <- NULL
  local_mocked_bindings(
    .eri_prompt_line = function(...) original,
    .eri_open_file    = function(path, ...) { opened <<- path; invisible(path) },
    .package = "erifunctions"
  )

  f <- list(column = "x", excel_row = 1L, sheet = "s", issue = "i")
  .eri_dq_review_fix_in_source(f, local_path_env)

  expect_match(local_path_env$path, "_fixed\\.xlsx$")
  expect_false(identical(local_path_env$path, original))  # a real working copy was made
  expect_true(file.exists(local_path_env$path))
  expect_equal(opened, local_path_env$path)
})

test_that(".eri_dq_review_fix_in_source lets a blank path cancel back to the flag, instead of looping forever", {
  # Regression guard: this prompt used to be required = TRUE, which meant a
  # DA who picked "Fix in source" without the file path handy had no way out
  # -- every blank answer just re-prompted "This can't be blank" forever.
  local_path_env <- new.env(parent = emptyenv())
  local_path_env$path <- NULL
  opened <- NULL
  local_mocked_bindings(
    .eri_prompt_line = function(...) "",
    .eri_open_file    = function(path, ...) { opened <<- path; invisible(path) },
    .package = "erifunctions"
  )

  f <- list(column = "x", excel_row = 1L, sheet = "s", issue = "i")
  result <- .eri_dq_review_fix_in_source(f, local_path_env)

  expect_null(result)
  expect_null(local_path_env$path)   # nothing was set -- caller stays at the flag menu
  expect_null(opened)                # never tried to open a file
})

test_that(".eri_dq_review_fix_in_source prints the fix instructions as two separate bullets, not jammed onto one line", {
  tmp_dir  <- withr::local_tempdir()
  original <- file.path(tmp_dir, "workbook.xlsx")
  writeLines("x", original)
  local_path_env <- new.env(parent = emptyenv())
  local_path_env$path <- NULL
  local_mocked_bindings(
    .eri_prompt_line = function(...) original,
    .eri_open_file    = function(path, ...) invisible(path),
    .package = "erifunctions"
  )

  f <- list(column = "district", excel_row = 8L, sheet = "RB Treatment", issue = "not an allowed value")
  lines <- capture.output(.eri_dq_review_fix_in_source(f, local_path_env), type = "message")

  fix_line   <- grep("Fix district on Excel row 8", lines, value = TRUE)
  issue_line <- grep("Issue: not an allowed value$", lines, value = TRUE)
  expect_length(fix_line, 1L)
  expect_length(issue_line, 1L)
  # regression guard: a prior bug (cli_alert_info() instead of cli_bullets() on a
  # multi-element vector) glued both onto one line with no space between them
  expect_false(any(grepl("sheet\\.Issue:", lines)))
})

test_that(".eri_dq_review_print_report() prints a plain table, not a flextable's console diagnostic dump", {
  flags <- tibble::tibble(
    sheet = "RB Treatment", excel_row = 8L, column = "district", value = "Atlantis City",
    issue = "not an allowed value", status = "noted", note = "confirmed with the country lead"
  )
  local_mocked_bindings(
    eri_dq_export = function(...) invisible("x"),
    .package = "erifunctions"
  )

  lines <- capture.output(.eri_dq_review_print_report(flags, "atlantis", "202608"))

  # regression guard: a prior bug (print(eri_table(...)), a flextable) dumped
  # print.flextable()'s diagnostic summary outside a Viewer-capable session
  expect_false(any(grepl("a flextable object", lines)))
  expect_false(any(grepl("col_keys:", lines)))
  expect_true(any(grepl("Atlantis City", lines)))
})

test_that(".eri_dq_review_apply_local_resolutions writes both status and note into the flags tibble", {
  flags <- tibble::tibble(
    flag_id = c("a::1", "a::2"), status = c("open", "open"),
    note = c(NA_character_, NA_character_)
  )
  resolved <- list(
    "a::1" = list(status = "not_important", note = "known template quirk"),
    "a::2" = list(status = "noted", note = NA_character_)
  )

  out <- .eri_dq_review_apply_local_resolutions(flags, resolved)
  expect_equal(out$status, c("not_important", "noted"))
  expect_equal(out$note, c("known template quirk", NA_character_))
})

test_that(".eri_dq_review_apply_local_resolutions leaves flags alone when there's no note column", {
  flags <- tibble::tibble(flag_id = "a::1", status = "open")
  resolved <- list("a::1" = list(status = "not_important", note = "a note"))

  out <- .eri_dq_review_apply_local_resolutions(flags, resolved)
  expect_equal(out$status, "not_important")
  expect_false("note" %in% names(out))
})

test_that("eri_dq_review's 'print report' hands the in-session flags (with notes) to eri_dq_export", {
  withr::local_options(rlang_interactive = TRUE)
  plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                         dest = "a", n_rows = 1L)
  exported <- NULL
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) plan,
    eri_cmr_dq_report  = function(...) flagged_tbl,
    eri_dq_flag_resolve = function(...) invisible(NULL),
    eri_logs_resolve = function(...) invisible(NULL),
    eri_approve_cmr = function(...) invisible(NULL),
    eri_dq_export = function(flags, country, period, ...) { exported <<- flags; invisible("x") },
    # main menu: "Work through flags"; within the flag: "Mark noted" (with a note); back at the
    # now-clean "Nothing outstanding" menu: "Print report", then "Exit"
    .eri_prompt_menu = scripted(list(1L, 4L, 3L, 4L)),
    .eri_prompt_line = scripted(list("worth a second look")),
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))

  expect_false(is.null(exported))
  expect_true("note" %in% names(exported))
  expect_equal(exported$status, "noted")
  expect_equal(exported$note, "worth a second look")
})
