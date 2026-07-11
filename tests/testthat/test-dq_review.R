#### Tests for eri_dq_review() and its internal helpers ####

# Returns a function that yields the next element of `responses` on each call,
# ignoring its arguments -- the standard "scripted decision sequence" pattern
# for testing the interactive loop by mocking .eri_prompt_menu()/.eri_prompt_line().
scripted <- function(responses) {
  i <- 0L
  function(...) {
    i <<- i + 1L
    if (i > length(responses)) stop("scripted responses exhausted at call ", i)
    responses[[i]]
  }
}

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
    .eri_prompt_menu = scripted(list(2L, 1L)),  # "Print report", then "Approve"
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_true(printed)
  expect_true(approved)
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
  issue = "not an allowed value", status = "open"
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
    .eri_prompt_menu = scripted(list(3L, 5L)),
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
    .eri_prompt_menu = scripted(list(1L, 2L, 5L, 1L)),
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
    .eri_prompt_menu = scripted(list(1L, 1L, 2L, 1L, 5L)),
    .eri_prompt_line = scripted(list(tmp)),  # the local workbook path prompt
    .package = "erifunctions"
  )

  eri_dq_review("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_match(split_called_with, "_fixed", fixed = TRUE)
  # exactly one fetch up front, one more from the explicit re-run -- "fix in
  # source" itself (unlike a re-run) must not trigger an extra DQ check
  expect_equal(dq_report_calls, 2L)
})
