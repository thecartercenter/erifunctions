#### Tests for .eri_analyst_id() identity resolution ####

test_that(".eri_analyst_id returns ERI_ANALYST_ID when set, with no warning", {
  withr::local_envvar(ERI_ANALYST_ID = "jane.doe")
  expect_silent(id <- .eri_analyst_id())
  expect_equal(id, "jane.doe")
})

test_that(".eri_analyst_id falls back to the OS user and warns once when unset", {
  withr::local_envvar(ERI_ANALYST_ID = "")
  withr::local_options(erifunctions.warned_analyst_id = FALSE)

  expect_warning(id1 <- .eri_analyst_id(), "is not set")
  expect_equal(id1, Sys.info()[["user"]])

  # second resolution in the same session: same value, no repeat warning
  expect_silent(id2 <- .eri_analyst_id())
  expect_equal(id2, Sys.info()[["user"]])
})
