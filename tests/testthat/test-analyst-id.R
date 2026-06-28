#### Tests for .eri_analyst_id() identity resolution ####

test_that(".eri_analyst_id returns ERI_ANALYST_ID when set, with no warning", {
  withr::local_envvar(ERI_ANALYST_ID = "jane.doe")
  expect_silent(id <- .eri_analyst_id())
  expect_equal(id, "jane.doe")
})

test_that(".eri_analyst_id falls back to a MARKED OS user and warns once when unset", {
  withr::local_envvar(ERI_ANALYST_ID = "", ERI_REQUIRE_ANALYST_ID = "")
  withr::local_options(erifunctions.warned_analyst_id = FALSE)

  expect_warning(id1 <- .eri_analyst_id(), "is not set")
  # The recorded value is marked unverified so the audit trail is honest.
  expect_equal(id1, paste0(Sys.info()[["user"]], " (unverified)"))
  expect_match(id1, "\\(unverified\\)$")

  # second resolution in the same session: same value, no repeat warning
  expect_silent(id2 <- .eri_analyst_id())
  expect_equal(id2, paste0(Sys.info()[["user"]], " (unverified)"))
})

test_that(".eri_analyst_id refuses when ERI_REQUIRE_ANALYST_ID is on and the id is unset", {
  withr::local_envvar(ERI_ANALYST_ID = "", ERI_REQUIRE_ANALYST_ID = "true")
  expect_error(.eri_analyst_id(), "ERI_REQUIRE_ANALYST_ID")
})

test_that(".eri_analyst_id strict mode still returns a configured id without error", {
  withr::local_envvar(ERI_ANALYST_ID = "jane.doe", ERI_REQUIRE_ANALYST_ID = "true")
  expect_silent(id <- .eri_analyst_id())
  expect_equal(id, "jane.doe")
})
