#### Tests for console verbosity + transfer helpers ####

test_that("verbosity defaults to full and reads the option", {
  withr::local_options(erifunctions.verbosity = NULL)
  withr::local_envvar(ERIFUNCTIONS_VERBOSITY = "")
  expect_equal(eri_verbosity(), "full")
  expect_true(.eri_chatty())

  withr::local_options(erifunctions.verbosity = "quiet")
  expect_equal(eri_verbosity(), "quiet")
  expect_false(.eri_chatty())
})

test_that("eri_verbosity() sets and validates the level", {
  withr::local_options(erifunctions.verbosity = NULL)
  expect_message(eri_verbosity("quiet"), "quiet")
  expect_equal(getOption("erifunctions.verbosity"), "quiet")
  expect_error(eri_verbosity("loud"))          # match.arg rejects unknown levels
})

test_that("ERIFUNCTIONS_VERBOSITY env var is honoured when the option is unset", {
  withr::local_options(erifunctions.verbosity = NULL)
  withr::local_envvar(ERIFUNCTIONS_VERBOSITY = "quiet")
  expect_equal(eri_verbosity(), "quiet")
  expect_false(.eri_chatty())
})

test_that(".eri_say_* are gated by verbosity; interpolate in the caller frame", {
  withr::local_options(erifunctions.verbosity = "full")
  expect_message(.eri_say_done("done {1L + 1L}"), "done 2")
  expect_message(.eri_say_info("info {2L + 2L}"), "info 4")

  withr::local_options(erifunctions.verbosity = "quiet")
  expect_no_message(.eri_say_done("hidden"))
  expect_no_message(.eri_say_info("hidden"))
})

test_that(".eri_summary always renders, at both verbosity levels", {
  withr::local_options(erifunctions.verbosity = "quiet")
  expect_message(.eri_summary("Tagged {.val v1}", c(A = "1", B = "2")), "Tagged")
})

#### transfer helpers ####

test_that(".eri_blob_transfer_many transfers each file once and returns dests", {
  n_up <- 0L
  local_mocked_bindings(
    storage_upload = function(...) n_up <<- n_up + 1L,
    .package = "AzureStor"
  )
  out <- .eri_blob_transfer_many("con", c("a", "b", "c"),
                                 c("x/a", "x/b", "x/c"), direction = "upload")
  expect_equal(n_up, 3L)
  expect_equal(out, c("x/a", "x/b", "x/c"))
})

test_that(".eri_blob_transfer_many is a no-op on zero files", {
  expect_equal(
    .eri_blob_transfer_many("con", character(), character(), "upload"),
    character()
  )
})

test_that(".eri_blob_write/read suppress the AzureStor progress bar by default", {
  seen <- NA
  local_mocked_bindings(
    storage_upload = function(...) seen <<- getOption("azure_storage_progress_bar"),
    .package = "AzureStor"
  )
  .eri_blob_write("con", "src", "dest")
  expect_false(seen)

  .eri_blob_write("con", "src", "dest", progress = TRUE)
  expect_true(seen)
})
