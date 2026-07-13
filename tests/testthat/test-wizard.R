#### Tests for eri_do() and its internal helpers ####
#
# scripted() (the interactive-menu mocking helper) lives in helper-scripted.R, shared with
# test-guide.R/test-dq_review.R. Every test below mocks EVERY live-Azure-touching function the
# code path it exercises could reach (get_azure_storage_connection, eri_upload, eri_stage_cmr,
# eri_split_cmr, eri_cutover_status, .eri_dq_review_loop, .eri_logs_con) -- see
# feedback_test_mock_infinite_loop's lesson (memory, docs-site redesign phase 7): a mocked
# interactive-loop test that leaves a real function reachable will actually run it, not just hang.

test_that("eri_do refuses to run non-interactively", {
  expect_error(eri_do(), "interactive-only")
})

test_that(".eri_prompt_pick_country returns the picked code, and NULL on cancel", {
  country_map <- list(eth = "eth", uga = "uga", sdn = "sdn")

  local_mocked_bindings(.eri_prompt_menu = scripted(list(2L)), .package = "erifunctions")
  expect_equal(.eri_prompt_pick_country(country_map), "uga")

  local_mocked_bindings(.eri_prompt_menu = scripted(list(0L)), .package = "erifunctions")
  expect_null(.eri_prompt_pick_country(country_map))
})

test_that(".eri_wizard_confirm maps menu choice 1 to TRUE and anything else to FALSE", {
  local_mocked_bindings(.eri_prompt_menu = scripted(list(1L)), .package = "erifunctions")
  expect_true(.eri_wizard_confirm("Go ahead?"))

  local_mocked_bindings(.eri_prompt_menu = scripted(list(2L)), .package = "erifunctions")
  expect_false(.eri_wizard_confirm("Go ahead?"))

  local_mocked_bindings(.eri_prompt_menu = scripted(list(0L)), .package = "erifunctions")
  expect_false(.eri_wizard_confirm("Go ahead?"))
})

test_that(".eri_wizard_step reports ok=TRUE with the value on success, ok=FALSE on error, without raising", {
  ok_result <- .eri_wizard_step(function() 42L)
  expect_true(ok_result$ok)
  expect_equal(ok_result$value, 42L)

  expect_no_error(bad_result <- .eri_wizard_step(function() stop("boom")))
  expect_false(bad_result$ok)
  expect_null(bad_result$value)
})

test_that(".eri_wizard_detect_period matches eri_split_cmr()'s own leading-YYYYMM_ convention, nothing looser", {
  expect_equal(.eri_wizard_detect_period("202406_uga_cmr.xlsx"), "202406")
  # No trailing underscore -- eri_split_cmr()'s own regex requires "^\\d{6}(?=_)", so this must NOT match.
  expect_true(is.na(.eri_wizard_detect_period("uga_cmr_2024_06.xlsx")))
  expect_true(is.na(.eri_wizard_detect_period("cmr-example.xlsx")))
})

test_that(".eri_wizard_pick_period offers the detected period and accepts a confirmed 'yes'", {
  local_mocked_bindings(.eri_prompt_menu = scripted(list(1L)), .package = "erifunctions")  # "Yes"
  expect_equal(.eri_wizard_pick_period("202406_uga_cmr.xlsx"), "202406")
})

test_that(".eri_wizard_pick_period falls back to a validated typed period when detection fails or is declined", {
  local_mocked_bindings(
    .eri_prompt_line = scripted(list("202406")),
    .package = "erifunctions"
  )
  expect_equal(.eri_wizard_pick_period("cmr-example.xlsx"), "202406")
})

test_that(".eri_wizard_pick_period re-asks on an invalid typed period instead of accepting it", {
  local_mocked_bindings(
    .eri_prompt_line = scripted(list("not-a-period", "202406")),
    .package = "erifunctions"
  )
  expect_equal(.eri_wizard_pick_period("cmr-example.xlsx"), "202406")
})

test_that(".eri_wizard_pick_period returns NA (cancel) on a blank typed period", {
  local_mocked_bindings(
    .eri_prompt_line = scripted(list("")),
    .package = "erifunctions"
  )
  expect_true(is.na(.eri_wizard_pick_period("cmr-example.xlsx")))
})

test_that(".eri_derive_cmr_destination matches the real rb-expansion registry entry eri_stage_cmr() itself reads", {
  dest <- .eri_derive_cmr_destination("uga", "202406", "uga_cmr_2024_06.xlsx")
  expect_equal(dest, "health-rb-country-expansion-dev/raw/filled_templates/uga/202406/uga_cmr_2024_06.xlsx")
})

test_that(".eri_prompt_pick_file falls back to a typed path when the dialog is unavailable/cancelled", {
  # .eri_wizard_raw_file_dialog() -- NOT file.choose()/rstudioapi::selectFile() directly -- is
  # mocked here on purpose: those are real, blocking GUI calls that can't be safely intercepted
  # via local_mocked_bindings() (base-package locking), so no test may ever let one run for real.
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("x", tmp)
  local_mocked_bindings(
    .eri_wizard_raw_file_dialog = function(...) NULL,
    .eri_prompt_line = function(...) tmp,
    .package = "erifunctions"
  )
  expect_equal(.eri_prompt_pick_file("Where is the file?"), tmp)
})

test_that(".eri_prompt_pick_file returns NULL when the DA cancels the typed-path fallback", {
  local_mocked_bindings(
    .eri_wizard_raw_file_dialog = function(...) NULL,
    .eri_prompt_line = function(...) "",
    .package = "erifunctions"
  )
  expect_null(.eri_prompt_pick_file("Where is the file?"))
})

test_that(".eri_prompt_pick_file re-asks when the picked/typed path doesn't exist, and succeeds on the next real one", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("x", tmp)
  attempt <- scripted(list("C:/does/not/exist.xlsx", tmp))
  local_mocked_bindings(
    .eri_wizard_raw_file_dialog = function(...) NULL,
    .eri_prompt_line = function(...) attempt(),
    .package = "erifunctions"
  )
  expect_equal(.eri_prompt_pick_file("Where is the file?"), tmp)
})

test_that(".eri_wizard_detect_cmr_progress returns NULL (not an error) when eri_cmr_last_plan() has nothing recorded", {
  local_mocked_bindings(
    eri_cmr_last_plan = function(...) stop("no plan recorded for this period"),
    .package = "erifunctions"
  )
  expect_null(.eri_wizard_detect_cmr_progress("uga", "202406", structure(list(), class = "mock_data_con")))
})

test_that(".eri_wizard_should_mirror_cmr mirrors when any constituent stream isn't yet cutover-eligible", {
  plan <- tibble::tibble(disease = c("oncho", "sch"), data_type = c("treatment", "treatment"))
  local_mocked_bindings(
    eri_cutover_status = function(country, disease, data_source, data_type, ...) {
      list(eligible = disease == "oncho")  # sch not yet eligible
    },
    .package = "erifunctions"
  )
  expect_true(.eri_wizard_should_mirror_cmr("uga", plan))
})

test_that(".eri_wizard_should_mirror_cmr does not mirror once every constituent stream is eligible", {
  plan <- tibble::tibble(disease = c("oncho", "sch"), data_type = c("treatment", "treatment"))
  local_mocked_bindings(
    eri_cutover_status = function(...) list(eligible = TRUE),
    .package = "erifunctions"
  )
  expect_false(.eri_wizard_should_mirror_cmr("uga", plan))
})

test_that(".eri_wizard_should_mirror_cmr defaults to mirroring (the safe direction) when the status check errors", {
  plan <- tibble::tibble(disease = "oncho", data_type = "treatment")
  local_mocked_bindings(
    eri_cutover_status = function(...) stop("no connection"),
    .package = "erifunctions"
  )
  expect_true(.eri_wizard_should_mirror_cmr("uga", plan))
})

test_that(".eri_flow_cmr runs upload -> stage -> split -> DQ-review-loop in order with the derived path/period/mirror flag, and nothing else", {
  withr::local_options(rlang_interactive = TRUE)

  calls <- list()
  record <- function(name, ...) calls[[length(calls) + 1L]] <<- list(name = name, args = list(...))

  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_file    = function(...) "C:/fake/202406_uga_cmr.xlsx",
    .eri_wizard_pick_period  = function(...) "202406",
    .eri_wizard_confirm      = function(...) TRUE,
    .eri_wizard_detect_cmr_progress = function(...) NULL,  # nothing staged yet this session
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    get_azure_storage_connection = function(...) structure(list(), class = "mock_projects_con"),
    eri_upload = function(local_path, file_loc, azcontainer) {
      record("upload", local_path = local_path, file_loc = file_loc)
      invisible(NULL)
    },
    eri_stage_cmr = function(country, period, data_con, ...) {
      record("stage", country = country, period = period)
      invisible(NULL)
    },
    eri_split_cmr = function(path, country, period, data_con = NULL, dry_run = FALSE, mirror_pipeline = NULL, ...) {
      record("split", dry_run = dry_run, mirror_pipeline = mirror_pipeline)
      tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                     dest = "a", n_rows = 1L)
    },
    .eri_wizard_should_mirror_cmr = function(...) TRUE,
    .eri_dq_review_loop = function(country, period, plan, data_con) {
      record("dq_review_loop", country = country, period = period)
      "approved"
    },
    .package = "erifunctions"
  )

  expect_invisible(.eri_flow_cmr())

  names_called <- vapply(calls, function(c) c$name, character(1))
  expect_equal(names_called, c("upload", "stage", "split", "split", "dq_review_loop"))

  upload_call <- calls[[1]]$args
  expect_equal(upload_call$local_path, "C:/fake/202406_uga_cmr.xlsx")
  expect_equal(upload_call$file_loc,
              "health-rb-country-expansion-dev/raw/filled_templates/uga/202406/202406_uga_cmr.xlsx")

  stage_call <- calls[[2]]$args
  expect_equal(stage_call$country, "uga")
  expect_equal(stage_call$period, "202406")

  dry_run_call <- calls[[3]]$args
  expect_true(dry_run_call$dry_run)

  real_split_call <- calls[[4]]$args
  expect_false(real_split_call$dry_run)
  expect_equal(real_split_call$mirror_pipeline, "rb-expansion")

  loop_call <- calls[[5]]$args
  expect_equal(loop_call$country, "uga")
  expect_equal(loop_call$period, "202406")
})

test_that(".eri_flow_cmr stops cleanly (no further calls) when the DA cancels the country pick", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) NULL,
    eri_upload = function(...) stop("must not be called -- DA cancelled before any mutation"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_cmr())
})

test_that(".eri_flow_cmr stops cleanly when the DA declines the final 'go ahead' confirmation", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_file    = function(...) "C:/fake/202406_uga_cmr.xlsx",
    .eri_wizard_pick_period  = function(...) "202406",
    .eri_wizard_detect_cmr_progress = function(...) NULL,
    .eri_wizard_confirm      = function(...) FALSE,  # declines "Go ahead?"
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    eri_upload = function(...) stop("must not be called -- DA declined before any mutation"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_cmr())
})

test_that(".eri_flow_cmr offers to resume into DQ review when this country/period was already split", {
  withr::local_options(rlang_interactive = TRUE)
  existing_plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                                  dest = "a", n_rows = 1L)
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_file    = function(...) "C:/fake/202406_uga_cmr.xlsx",
    .eri_wizard_pick_period  = function(...) "202406",
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    .eri_wizard_detect_cmr_progress = function(...) existing_plan,
    .eri_wizard_confirm = function(...) TRUE,  # accepts the "already split, resume?" offer
    .eri_dq_review_loop = function(country, period, plan, data_con) {
      expect_equal(nrow(plan), 1L)  # the EXISTING plan, not a freshly-split one
      "approved"
    },
    eri_upload    = function(...) stop("must not upload -- already split, resuming instead"),
    eri_stage_cmr = function(...) stop("must not stage -- already split, resuming instead"),
    eri_split_cmr = function(...) stop("must not split -- already split, resuming instead"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_cmr())
})

#### Phase B: surveillance ingest ####

test_that(".eri_prompt_pick_or_type returns a picked value, a typed 'Other', or NA on cancel", {
  known <- c("malaria", "oncho")

  local_mocked_bindings(.eri_prompt_menu = scripted(list(2L)), .package = "erifunctions")
  expect_equal(.eri_prompt_pick_or_type("Disease?", known, "Type it: "), "oncho")

  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(3L)),  # "Other (type it)" -- the item after the 2 known values
    .eri_prompt_line = scripted(list("Ebola")),
    .package = "erifunctions"
  )
  expect_equal(.eri_prompt_pick_or_type("Disease?", known, "Type it: "), "ebola")  # lowercased

  local_mocked_bindings(.eri_prompt_menu = scripted(list(0L)), .package = "erifunctions")
  expect_true(is.na(.eri_prompt_pick_or_type("Disease?", known, "Type it: ")))
})

test_that(".eri_wizard_prompt_country_code validates the typed code and re-asks on a bad one", {
  local_mocked_bindings(.eri_prompt_line = scripted(list("sdn")), .package = "erifunctions")
  expect_equal(.eri_wizard_prompt_country_code(), "sdn")

  local_mocked_bindings(
    .eri_prompt_line = scripted(list("123", "sdn")),
    .package = "erifunctions"
  )
  expect_equal(.eri_wizard_prompt_country_code(), "sdn")

  local_mocked_bindings(.eri_prompt_line = scripted(list("")), .package = "erifunctions")
  expect_true(is.na(.eri_wizard_prompt_country_code()))
})

test_that(".eri_wizard_should_mirror_ingest is FALSE outright for a country never registered for hsp-mal", {
  # uga is registered for rb-expansion (CMR), NOT hsp-mal -- eri_ingest() would abort if the wizard
  # ever passed mirror_pipeline = "hsp-mal" for it, so this must never even check cutover status.
  local_mocked_bindings(
    eri_cutover_status = function(...) stop("must not be called -- uga isn't registered for hsp-mal"),
    .package = "erifunctions"
  )
  expect_false(.eri_wizard_should_mirror_ingest("uga", "malaria", "surveillance", "case"))
})

test_that(".eri_wizard_should_mirror_ingest checks cutover status for a country that IS registered", {
  local_mocked_bindings(
    eri_cutover_status = function(...) list(eligible = FALSE),
    .package = "erifunctions"
  )
  expect_true(.eri_wizard_should_mirror_ingest("dr", "malaria", "surveillance", "case"))

  local_mocked_bindings(
    eri_cutover_status = function(...) list(eligible = TRUE),
    .package = "erifunctions"
  )
  expect_false(.eri_wizard_should_mirror_ingest("dr", "malaria", "surveillance", "case"))
})

test_that(".eri_flow_ingest runs ingest -> approve in order with the collected values, and nothing else", {
  withr::local_options(rlang_interactive = TRUE)
  calls <- list()
  record <- function(name, ...) calls[[length(calls) + 1L]] <<- list(name = name, args = list(...))

  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_pick_or_type = local({
      i <- 0L
      function(prompt, known, type_prompt) {
        i <<- i + 1L
        c("malaria", "surveillance", "case")[[i]]  # disease, data_source, data_type in call order
      }
    }),
    .eri_prompt_pick_file = function(...) "C:/fake/linelist.csv",
    .eri_wizard_confirm = function(...) TRUE,
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    .eri_wizard_should_mirror_ingest = function(...) FALSE,
    eri_ingest = function(path, country, disease, data_source, data_type, data_con, mirror_pipeline) {
      record("ingest", path = path, country = country, disease = disease,
             data_source = data_source, data_type = data_type, mirror_pipeline = mirror_pipeline)
      invisible(NULL)
    },
    eri_logs = function(...) tibble::tibble(),  # nothing needs review
    .eri_prompt_line = function(...) "2024-01",
    eri_approve = function(country, disease, data_source, period, data_type, azcontainer) {
      record("approve", country = country, period = period)
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  expect_invisible(.eri_flow_ingest())

  names_called <- vapply(calls, function(c) c$name, character(1))
  expect_equal(names_called, c("ingest", "approve"))

  ingest_call <- calls[[1]]$args
  expect_equal(ingest_call$country, "uga")
  expect_equal(ingest_call$disease, "malaria")
  expect_equal(ingest_call$data_source, "surveillance")
  expect_equal(ingest_call$data_type, "case")
  expect_null(ingest_call$mirror_pipeline)

  approve_call <- calls[[2]]$args
  expect_equal(approve_call$country, "uga")
  expect_equal(approve_call$period, "2024-01")
})

test_that(".eri_flow_ingest stops cleanly (no approve) when open log entries need review and the DA declines", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_pick_or_type = local({
      i <- 0L
      function(...) { i <<- i + 1L; c("malaria", "surveillance", "case")[[i]] }
    }),
    .eri_prompt_pick_file = function(...) "C:/fake/linelist.csv",
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    .eri_wizard_should_mirror_ingest = function(...) FALSE,
    eri_ingest = function(...) invisible(NULL),
    eri_logs = function(...) tibble::tibble(log_path = "uga/malaria/surveillance/case/logs/x.yaml"),
    # First confirm ("Go ahead?") = TRUE, second ("Approve anyway?") = FALSE.
    .eri_wizard_confirm = local({
      i <- 0L
      function(...) { i <<- i + 1L; i == 1L }
    }),
    eri_approve = function(...) stop("must not approve -- DA declined with open flags outstanding"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_ingest())
})

test_that("eri_do's top menu routes to the CMR flow and exits cleanly", {
  withr::local_options(rlang_interactive = TRUE)
  cmr_ran <- FALSE
  local_mocked_bindings(
    .eri_flow_cmr = function() { cmr_ran <<- TRUE; invisible(NULL) },
    .eri_prompt_menu = scripted(list(1L, 4L)),  # CMR flow, then Exit
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
  expect_true(cmr_ran)
})

test_that("eri_do's top menu routes to the surveillance ingest flow and exits cleanly", {
  withr::local_options(rlang_interactive = TRUE)
  ingest_ran <- FALSE
  local_mocked_bindings(
    .eri_flow_ingest = function() { ingest_ran <<- TRUE; invisible(NULL) },
    .eri_prompt_menu = scripted(list(2L, 4L)),  # ingest flow, then Exit
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
  expect_true(ingest_ran)
})

test_that("eri_do's top menu routes to the DQ-review shortcut with a picked country/period", {
  withr::local_options(rlang_interactive = TRUE)
  reviewed <- NULL
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_wizard_pick_period  = function(...) "202406",
    eri_dq_review = function(country, period) { reviewed <<- c(country, period); invisible(NULL) },
    .eri_prompt_menu = scripted(list(3L, 4L)),  # DQ review shortcut, then Exit
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
  expect_equal(reviewed, c("uga", "202406"))
})

test_that("eri_do exits immediately from the top menu with no navigation", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(0L)),  # ESC/cancel
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
})
