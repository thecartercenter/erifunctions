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

test_that(".eri_flow_cmr asks replace-vs-update when declining to resume, and threads 'replace' into supersede_staged", {
  withr::local_options(rlang_interactive = TRUE)
  existing_plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                                  dest = "a", n_rows = 1L)
  split_calls <- list()
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_file    = function(...) "C:/fake/202406_uga_cmr.xlsx",
    .eri_wizard_pick_period  = function(...) "202406",
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    get_azure_storage_connection = function(...) structure(list(), class = "mock_projects_con"),
    .eri_wizard_detect_cmr_progress = function(...) existing_plan,
    # "already split, resume?": No; replace-vs-update: "A correction that
    # replaces..."; final "Go ahead?": Yes
    .eri_prompt_menu = scripted(list(2L, 1L, 1L)),
    eri_upload    = function(...) invisible(NULL),
    eri_stage_cmr = function(...) invisible(NULL),
    eri_split_cmr = function(path, country, period, data_con = NULL, dry_run = FALSE,
                             mirror_pipeline = NULL, supersede_staged = FALSE, ...) {
      split_calls[[length(split_calls) + 1L]] <<- list(dry_run = dry_run, supersede_staged = supersede_staged)
      tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                     dest = "a", n_rows = 1L)
    },
    .eri_wizard_should_mirror_cmr = function(...) FALSE,
    .eri_dq_review_loop = function(...) "approved",
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_cmr())

  expect_length(split_calls, 2L)                    # dry-run preview, then the real split
  expect_true(split_calls[[1]]$dry_run)
  expect_false(split_calls[[2]]$dry_run)
  expect_true(split_calls[[2]]$supersede_staged)     # "replace" -> supersede_staged = TRUE
})

test_that(".eri_flow_cmr's replace-vs-update 'add as an update' does not supersede the earlier staged data", {
  withr::local_options(rlang_interactive = TRUE)
  existing_plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                                  dest = "a", n_rows = 1L)
  real_split_call <- NULL
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_file    = function(...) "C:/fake/202406_uga_cmr.xlsx",
    .eri_wizard_pick_period  = function(...) "202406",
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    get_azure_storage_connection = function(...) structure(list(), class = "mock_projects_con"),
    .eri_wizard_detect_cmr_progress = function(...) existing_plan,
    # "already split, resume?": No; replace-vs-update: "An update to add alongside..."; "Go ahead?": Yes
    .eri_prompt_menu = scripted(list(2L, 2L, 1L)),
    eri_upload    = function(...) invisible(NULL),
    eri_stage_cmr = function(...) invisible(NULL),
    eri_split_cmr = function(path, country, period, data_con = NULL, dry_run = FALSE,
                             mirror_pipeline = NULL, supersede_staged = FALSE, ...) {
      if (!dry_run) real_split_call <<- list(supersede_staged = supersede_staged)
      tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                     dest = "a", n_rows = 1L)
    },
    .eri_wizard_should_mirror_cmr = function(...) FALSE,
    .eri_dq_review_loop = function(...) "approved",
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_cmr())

  expect_false(is.null(real_split_call))
  expect_false(real_split_call$supersede_staged)
})

test_that(".eri_flow_cmr's replace-vs-update prompt cancels cleanly (no upload/stage/split)", {
  withr::local_options(rlang_interactive = TRUE)
  existing_plan <- tibble::tibble(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
                                  dest = "a", n_rows = 1L)
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_file    = function(...) "C:/fake/202406_uga_cmr.xlsx",
    .eri_wizard_pick_period  = function(...) "202406",
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    .eri_wizard_detect_cmr_progress = function(...) existing_plan,
    # "already split, resume?": No; replace-vs-update: "Cancel"
    .eri_prompt_menu = scripted(list(2L, 3L)),
    eri_upload    = function(...) stop("must not upload -- cancelled at the replace-vs-update prompt"),
    eri_stage_cmr = function(...) stop("must not stage -- cancelled at the replace-vs-update prompt"),
    eri_split_cmr = function(...) stop("must not split -- cancelled at the replace-vs-update prompt"),
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

  # The package's own sandbox demo country -- must not be rejected as "too long" (a real bug this
  # phase found: the regex was previously capped at 4 letters, which silently rejected the exact
  # code the prompt's own warning message cites as a valid example).
  local_mocked_bindings(.eri_prompt_line = scripted(list("atlantis")), .package = "erifunctions")
  expect_equal(.eri_wizard_prompt_country_code(), "atlantis")
})

test_that(".eri_wizard_prompt_language returns en/fr by menu choice, or NA on cancel", {
  local_mocked_bindings(.eri_prompt_menu = function(...) 1L, .package = "erifunctions")
  expect_equal(.eri_wizard_prompt_language(), "en")

  local_mocked_bindings(.eri_prompt_menu = function(...) 2L, .package = "erifunctions")
  expect_equal(.eri_wizard_prompt_language(), "fr")

  local_mocked_bindings(.eri_prompt_menu = function(...) 0L, .package = "erifunctions")
  expect_true(is.na(.eri_wizard_prompt_language()))
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

#### Phase C.1: ODK ####

test_that(".eri_flow_odk connects -> discovers -> registers -> syncs in order, and nothing else", {
  withr::local_options(rlang_interactive = TRUE)
  calls <- list()
  record <- function(name, ...) calls[[length(calls) + 1L]] <<- list(name = name, args = list(...))
  mock_con <- structure(list(url = "https://odk.example.org/"), class = "odk_connection")

  local_mocked_bindings(
    init_odk_connection = function(...) { record("connect"); mock_con },
    list_odk_projects = function(con) {
      record("list_projects")
      tibble::tibble(project_id = c(5L, 11L), project = c("Uganda", "testing"))
    },
    .eri_prompt_menu = local({
      i <- 0L
      function(title, choices) {
        i <<- i + 1L
        # 1st menu call: pick project "testing" (index 2); 2nd: pick the only form; the rest are
        # handled by mocking .eri_wizard_confirm() directly below, not via this generic menu mock.
        if (i == 1L) 2L else 1L
      }
    }),
    list_odk_forms = function(con, project_id) {
      record("list_forms", project_id = project_id)
      tibble::tibble(xmlFormId = "eri_test_river_prospection", name = "ERI Test, River Prospection")
    },
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    eri_odk_list_registered = function(...) tibble::tibble(project_id = integer(), form_id = character()),
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_or_type = function(...) "malaria",
    eri_odk_register = function(project_id, form_id, country, disease, server_url, con, data_con) {
      record("register", project_id = project_id, form_id = form_id, country = country,
             disease = disease, server_url = server_url)
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) TRUE,
    eri_odk_sync = function(project_id, form_id, con, data_con) {
      record("sync", project_id = project_id, form_id = form_id)
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  expect_invisible(.eri_flow_odk())

  names_called <- vapply(calls, function(c) c$name, character(1))
  expect_equal(names_called, c("connect", "list_projects", "list_forms", "register", "sync"))

  list_forms_call <- calls[[3]]$args
  expect_equal(list_forms_call$project_id, 11L)  # the SECOND project ("testing"), matching menu choice 2L

  register_call <- calls[[4]]$args
  expect_equal(register_call$project_id, 11L)
  expect_equal(register_call$form_id, "eri_test_river_prospection")
  expect_equal(register_call$country, "uga")
  expect_equal(register_call$disease, "malaria")
  expect_equal(register_call$server_url, "https://odk.example.org/")  # from con$url, never asked

  sync_call <- calls[[5]]$args
  expect_equal(sync_call$project_id, 11L)
  expect_equal(sync_call$form_id, "eri_test_river_prospection")
})

test_that(".eri_flow_odk skips registration when the form is already registered", {
  withr::local_options(rlang_interactive = TRUE)
  registered_check <- FALSE
  local_mocked_bindings(
    init_odk_connection = function(...) structure(list(url = "https://odk.example.org/"), class = "odk_connection"),
    list_odk_projects = function(...) tibble::tibble(project_id = 11L, project = "testing"),
    list_odk_forms = function(...) tibble::tibble(xmlFormId = "eri_test_river_prospection", name = "Test Form"),
    .eri_prompt_menu = scripted(list(1L, 1L)),
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    eri_odk_list_registered = function(...) {
      registered_check <<- TRUE
      tibble::tibble(project_id = 11L, form_id = "eri_test_river_prospection",
                     server_url = "https://odk.example.org/")
    },
    eri_odk_register = function(...) stop("must not register -- already registered"),
    .eri_wizard_confirm = function(...) TRUE,
    eri_odk_sync = function(...) invisible(NULL),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_odk())
  expect_true(registered_check)
})

test_that(".eri_flow_odk does not register when the DA declines the confirm prompt", {
  withr::local_options(rlang_interactive = TRUE)
  register_called <- FALSE
  sync_called <- FALSE
  local_mocked_bindings(
    init_odk_connection = function(...) structure(list(url = "https://odk.example.org/"), class = "odk_connection"),
    list_odk_projects = function(...) tibble::tibble(project_id = 11L, project = "testing"),
    list_odk_forms = function(...) tibble::tibble(xmlFormId = "eri_test_river_prospection", name = "Test Form"),
    .eri_prompt_menu = scripted(list(1L, 1L)),
    .eri_logs_con = function(...) structure(list(), class = "mock_data_con"),
    eri_odk_list_registered = function(...) tibble::tibble(project_id = integer(), form_id = character(),
                                                            server_url = character()),
    .eri_prompt_pick_country = function(...) "uga",
    .eri_prompt_pick_or_type = function(...) "malaria",
    eri_odk_register = function(...) { register_called <<- TRUE; invisible(NULL) },
    .eri_wizard_confirm = function(...) FALSE,
    eri_odk_sync = function(...) { sync_called <<- TRUE; invisible(NULL) },
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_odk())
  expect_false(register_called)
  expect_false(sync_called)
})

test_that(".eri_flow_odk stops cleanly (no sync) when the connection itself fails", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    init_odk_connection = function(...) stop("ODK username is required."),
    eri_odk_sync = function(...) stop("must not be called -- connection failed"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_odk())
})

test_that(".eri_flow_odk stops cleanly when there are no visible projects", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    init_odk_connection = function(...) structure(list(url = "https://odk.example.org/"), class = "odk_connection"),
    list_odk_projects = function(...) tibble::tibble(project_id = integer(), project = character()),
    list_odk_forms = function(...) stop("must not be called -- no projects to pick from"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_odk())
})

#### Phase C.2: onboarding ####

test_that(".eri_flow_onboard routes to the surveillance/CMR/disease sub-flows by menu choice", {
  withr::local_options(rlang_interactive = TRUE)
  ran <- character(0)
  local_mocked_bindings(
    .eri_flow_onboard_surveillance = function() { ran <<- c(ran, "surveillance"); invisible(NULL) },
    .eri_flow_onboard_cmr          = function() { ran <<- c(ran, "cmr"); invisible(NULL) },
    .eri_flow_onboard_disease      = function() { ran <<- c(ran, "disease"); invisible(NULL) },
    .package = "erifunctions"
  )
  local_mocked_bindings(.eri_prompt_menu = function(...) 1L, .package = "erifunctions")
  .eri_flow_onboard()
  local_mocked_bindings(.eri_prompt_menu = function(...) 2L, .package = "erifunctions")
  .eri_flow_onboard()
  local_mocked_bindings(.eri_prompt_menu = function(...) 3L, .package = "erifunctions")
  .eri_flow_onboard()
  local_mocked_bindings(.eri_prompt_menu = function(...) 0L, .package = "erifunctions")
  expect_invisible(.eri_flow_onboard())

  expect_equal(ran, c("surveillance", "cmr", "disease"))
})

test_that(".eri_flow_onboard_surveillance dry-runs, confirms, then writes for real -- in order", {
  withr::local_options(rlang_interactive = TRUE)
  calls <- list()
  record <- function(name, ...) calls[[length(calls) + 1L]] <<- list(name = name, args = list(...))
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_line = scripted(list("Atlantis")),
    .eri_prompt_pick_or_type = function(...) "malaria",
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_country = function(country_code, country_name, disease, language = "en", dry_run = FALSE) {
      record(if (dry_run) "dry_run" else "real", country_code = country_code,
             country_name = country_name, disease = disease, language = language)
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) TRUE,
    .package = "erifunctions"
  )

  expect_invisible(.eri_flow_onboard_surveillance())

  names_called <- vapply(calls, function(c) c$name, character(1))
  expect_equal(names_called, c("dry_run", "real"))
  expect_equal(calls[[2]]$args$country_code, "atlantis")
  expect_equal(calls[[2]]$args$country_name, "Atlantis")
  expect_equal(calls[[2]]$args$disease, "malaria")
})

test_that(".eri_flow_onboard_surveillance does not write for real when the DA declines", {
  withr::local_options(rlang_interactive = TRUE)
  real_called <- FALSE
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_line = scripted(list("Atlantis")),
    .eri_prompt_pick_or_type = function(...) "malaria",
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_country = function(..., dry_run = FALSE) {
      if (!dry_run) real_called <<- TRUE
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) FALSE,
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_surveillance())
  expect_false(real_called)
})

test_that(".eri_flow_onboard_surveillance cancels cleanly on a blank country name", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_line = scripted(list("")),
    eri_onboard_country = function(...) stop("must not be called -- cancelled on blank name"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_surveillance())
})

test_that(".eri_flow_onboard_cmr dry-runs and writes for real with create_dirs = TRUE both times", {
  withr::local_options(rlang_interactive = TRUE)
  calls <- list()
  record <- function(name, ...) calls[[length(calls) + 1L]] <<- list(name = name, args = list(...))
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_line = scripted(list("Uganda")),
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_cmr = function(country_code, country_name, language = "en", create_dirs = FALSE, dry_run = FALSE) {
      record(if (dry_run) "dry_run" else "real", create_dirs = create_dirs, language = language)
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) TRUE,
    .package = "erifunctions"
  )

  expect_invisible(.eri_flow_onboard_cmr())

  names_called <- vapply(calls, function(c) c$name, character(1))
  expect_equal(names_called, c("dry_run", "real"))
  expect_true(calls[[1]]$args$create_dirs)
  expect_true(calls[[2]]$args$create_dirs)
})

test_that(".eri_flow_onboard_cmr does not write for real when the DA declines", {
  withr::local_options(rlang_interactive = TRUE)
  real_called <- FALSE
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_line = scripted(list("Uganda")),
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_cmr = function(..., dry_run = FALSE) {
      if (!dry_run) real_called <<- TRUE
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) FALSE,
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_cmr())
  expect_false(real_called)
})

test_that(".eri_flow_onboard_cmr cancels cleanly on a blank country name", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_line = scripted(list("")),
    eri_onboard_cmr = function(...) stop("must not be called -- cancelled on blank name"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_cmr())
})

test_that(".eri_flow_onboard_surveillance/_cmr cancel cleanly when the DA declines the language prompt", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_line = scripted(list("Uganda")),
    .eri_prompt_pick_or_type = function(...) "malaria",
    .eri_wizard_prompt_language = function(...) NA_character_,
    eri_onboard_country = function(...) stop("must not be called -- language prompt was cancelled"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_surveillance())

  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_line = scripted(list("Uganda")),
    .eri_wizard_prompt_language = function(...) NA_character_,
    eri_onboard_cmr = function(...) stop("must not be called -- language prompt was cancelled"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_cmr())
})

test_that(".eri_flow_onboard_disease maps the menu choice to the right data_types vector", {
  withr::local_options(rlang_interactive = TRUE)
  captured_types <- list()
  local_mocked_bindings(
    .eri_prompt_pick_or_type = function(...) "schisto",
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    eri_onboard_disease = function(disease, country, data_types, dry_run = FALSE) {
      if (!dry_run) captured_types[[length(captured_types) + 1L]] <<- data_types
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) TRUE,
    .package = "erifunctions"
  )

  local_mocked_bindings(.eri_prompt_menu = scripted(list(1L)), .package = "erifunctions")
  .eri_flow_onboard_disease()
  local_mocked_bindings(.eri_prompt_menu = scripted(list(2L)), .package = "erifunctions")
  .eri_flow_onboard_disease()
  local_mocked_bindings(.eri_prompt_menu = scripted(list(3L)), .package = "erifunctions")
  .eri_flow_onboard_disease()

  expect_equal(captured_types, list(c("mda", "prevalence"), "mda", "prevalence"))
})

test_that(".eri_flow_onboard_disease cancels cleanly when the DA declines the schema-type menu", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_prompt_pick_or_type = function(...) "schisto",
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_menu = scripted(list(0L)),
    eri_onboard_disease = function(...) stop("must not be called -- schema-type menu was cancelled"),
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_disease())
})

test_that("eri_do's top menu routes to the CMR flow and exits cleanly", {
  withr::local_options(rlang_interactive = TRUE)
  cmr_ran <- FALSE
  local_mocked_bindings(
    .eri_flow_cmr = function() { cmr_ran <<- TRUE; invisible(NULL) },
    .eri_prompt_menu = scripted(list(1L, 6L)),  # CMR flow, then Exit
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
    .eri_prompt_menu = scripted(list(2L, 6L)),  # ingest flow, then Exit
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
  expect_true(ingest_ran)
})

test_that("eri_do's top menu routes to the ODK flow and exits cleanly", {
  withr::local_options(rlang_interactive = TRUE)
  odk_ran <- FALSE
  local_mocked_bindings(
    .eri_flow_odk = function() { odk_ran <<- TRUE; invisible(NULL) },
    .eri_prompt_menu = scripted(list(3L, 6L)),  # ODK flow, then Exit
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
  expect_true(odk_ran)
})

test_that("eri_do's top menu routes to the onboarding flow and exits cleanly", {
  withr::local_options(rlang_interactive = TRUE)
  onboard_ran <- FALSE
  local_mocked_bindings(
    .eri_flow_onboard = function() { onboard_ran <<- TRUE; invisible(NULL) },
    .eri_prompt_menu = scripted(list(4L, 6L)),  # onboarding flow, then Exit
    .package = "erifunctions"
  )
  expect_invisible(eri_do())
  expect_true(onboard_ran)
})

test_that("eri_do's top menu routes to the DQ-review shortcut with a picked country/period", {
  withr::local_options(rlang_interactive = TRUE)
  reviewed <- NULL
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_wizard_pick_period  = function(...) "202406",
    eri_dq_review = function(country, period) { reviewed <<- c(country, period); invisible(NULL) },
    .eri_prompt_menu = scripted(list(5L, 6L)),  # DQ review shortcut, then Exit
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

#### Phase D: eri_do(flow=) deep links ####

test_that("eri_do(flow=) jumps straight into each named flow without showing the top menu", {
  withr::local_options(rlang_interactive = TRUE)
  ran <- character(0)
  local_mocked_bindings(
    .eri_flow_cmr     = function() { ran <<- c(ran, "cmr"); invisible(NULL) },
    .eri_flow_ingest  = function() { ran <<- c(ran, "ingest"); invisible(NULL) },
    .eri_flow_odk     = function() { ran <<- c(ran, "odk"); invisible(NULL) },
    .eri_flow_onboard = function() { ran <<- c(ran, "onboard"); invisible(NULL) },
    .eri_prompt_menu  = function(...) stop("must not show the top menu -- a flow was named directly"),
    .package = "erifunctions"
  )
  expect_invisible(eri_do("cmr"))
  expect_invisible(eri_do("ingest"))
  expect_invisible(eri_do("odk"))
  expect_invisible(eri_do("onboard"))
  expect_equal(ran, c("cmr", "ingest", "odk", "onboard"))
})

test_that("eri_do(flow='review') jumps straight into the DQ-review shortcut", {
  withr::local_options(rlang_interactive = TRUE)
  reviewed <- NULL
  local_mocked_bindings(
    .eri_prompt_pick_country = function(...) "uga",
    .eri_wizard_pick_period  = function(...) "202406",
    eri_dq_review = function(country, period) { reviewed <<- c(country, period); invisible(NULL) },
    .eri_prompt_menu = function(...) stop("must not show the top menu -- a flow was named directly"),
    .package = "erifunctions"
  )
  expect_invisible(eri_do("review"))
  expect_equal(reviewed, c("uga", "202406"))
})

test_that("eri_do(flow=) is case/whitespace-insensitive and does not loop back to the menu", {
  withr::local_options(rlang_interactive = TRUE)
  cmr_calls <- 0L
  local_mocked_bindings(
    .eri_flow_cmr = function() { cmr_calls <<- cmr_calls + 1L; invisible(NULL) },
    .eri_prompt_menu = function(...) stop("must not show the top menu after a deep-link flow finishes"),
    .package = "erifunctions"
  )
  expect_invisible(eri_do("  CMR  "))
  expect_equal(cmr_calls, 1L)
})

test_that("eri_do(flow=) errors clearly on an unrecognized flow name", {
  withr::local_options(rlang_interactive = TRUE)
  expect_error(eri_do("bogus"), "must be one of")
})

#### Phase D: onboarding overwrite protection ####

test_that(".eri_flow_onboard_surveillance writes normally when no local schema file exists yet", {
  withr::local_options(rlang_interactive = TRUE)
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  real_called <- FALSE
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_line = scripted(list("Atlantis")),
    .eri_prompt_pick_or_type = function(...) "malaria",
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_country = function(..., dry_run = FALSE) {
      if (!dry_run) real_called <<- TRUE
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) TRUE,
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_surveillance())
  expect_true(real_called)
})

test_that(".eri_flow_onboard_surveillance warns and re-confirms before overwriting an existing schema file", {
  withr::local_options(rlang_interactive = TRUE)
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  writeLines("# a DA's in-progress schema edits", "atlantis_malaria_surveillance_aggregate.yaml")

  confirm_prompts <- character(0)
  real_called <- FALSE
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_line = scripted(list("Atlantis")),
    .eri_prompt_pick_or_type = function(...) "malaria",
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_country = function(..., dry_run = FALSE) {
      if (!dry_run) real_called <<- TRUE
      invisible(NULL)
    },
    .eri_wizard_confirm = function(prompt) { confirm_prompts <<- c(confirm_prompts, prompt); TRUE },
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_surveillance())
  expect_true(real_called)
  expect_match(confirm_prompts[[1]], "Overwrite", fixed = TRUE)
})

test_that(".eri_flow_onboard_surveillance does not overwrite when the DA declines", {
  withr::local_options(rlang_interactive = TRUE)
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  writeLines("# a DA's in-progress schema edits", "atlantis_malaria_surveillance_aggregate.yaml")

  real_called <- FALSE
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_line = scripted(list("Atlantis")),
    .eri_prompt_pick_or_type = function(...) "malaria",
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_country = function(..., dry_run = FALSE) {
      if (!dry_run) real_called <<- TRUE
      invisible(NULL)
    },
    .eri_wizard_confirm = function(...) FALSE,
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_surveillance())
  expect_false(real_called)
})

test_that(".eri_flow_onboard_cmr warns before overwriting an existing CMR schema file", {
  withr::local_options(rlang_interactive = TRUE)
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  writeLines("# existing CMR schema", "uga_cmr_schema.yaml")

  confirm_prompts <- character(0)
  local_mocked_bindings(
    .eri_wizard_prompt_country_code = function(...) "uga",
    .eri_prompt_line = scripted(list("Uganda")),
    .eri_wizard_prompt_language = function(...) "en",
    eri_onboard_cmr = function(...) invisible(NULL),
    .eri_wizard_confirm = function(prompt) { confirm_prompts <<- c(confirm_prompts, prompt); TRUE },
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_cmr())
  expect_match(confirm_prompts[[1]], "Overwrite", fixed = TRUE)
})

test_that(".eri_flow_onboard_disease warns once for two existing schema files (both types)", {
  withr::local_options(rlang_interactive = TRUE)
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  writeLines("# existing", "atlantis_schisto_programmatic_treatment.yaml")
  writeLines("# existing", "atlantis_schisto_research_prevalence.yaml")

  confirm_prompts <- character(0)
  local_mocked_bindings(
    .eri_prompt_pick_or_type = function(...) "schisto",
    .eri_wizard_prompt_country_code = function(...) "atlantis",
    .eri_prompt_menu = scripted(list(1L)),  # "Both (MDA + prevalence)"
    eri_onboard_disease = function(...) invisible(NULL),
    .eri_wizard_confirm = function(prompt) { confirm_prompts <<- c(confirm_prompts, prompt); TRUE },
    .package = "erifunctions"
  )
  expect_invisible(.eri_flow_onboard_disease())
  expect_match(confirm_prompts[[1]], "Overwrite", fixed = TRUE)
})
