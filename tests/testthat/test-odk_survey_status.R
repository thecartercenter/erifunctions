#### Tests for eri_survey_status() ####

# ---------------------------------------------------------------------------
# Shared mock helpers
# ---------------------------------------------------------------------------

fake_resp <- function(url = "") {
  structure(list(status_code = 200L, url = url), class = "response")
}

# ---------------------------------------------------------------------------
# Test 1: single-form scope returns 1-row survey_status tibble with correct columns
# ---------------------------------------------------------------------------

test_that("single-form scope returns 1-row survey_status with correct columns", {
  proj_meta_content <- list(name = "My Project")

  form_meta_content <- list(
    name           = "Registration Form",
    xmlFormId      = "reg_form",
    state          = "open",
    submissions    = 42L,
    lastSubmission = "2026-05-01T10:00:00Z"
  )

  subs_content <- list(
    list(createdAt = "2026-06-01T08:00:00Z"),
    list(createdAt = "2026-05-30T09:00:00Z"),
    list(createdAt = "2026-01-15T12:00:00Z")
  )

  call_n <- 0L

  testthat::local_mocked_bindings(
    GET = function(url, ...) {
      call_n <<- call_n + 1L
      fake_resp(url)
    },
    http_error  = function(resp, ...) FALSE,
    status_code = function(resp, ...) 200L,
    content = function(resp, ...) {
      switch(call_n,
        `1` = proj_meta_content,
        `2` = form_meta_content,
        `3` = subs_content,
        list()
      )
    },
    .package = "httr"
  )

  withr::with_envvar(
    list(ODK_URL = "https://odk.example.org/", ODK_TOKEN = "fake_token"),
    {
      result <- eri_survey_status(project_id = 1L, form_id = "reg_form")
    }
  )

  expect_s3_class(result, "survey_status")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)

  expected_cols <- c("project_id", "project_name", "form_id", "form_name",
                     "server_url", "status", "total_submissions",
                     "last_submission_at", "submissions_7d", "submissions_30d")
  expect_true(all(expected_cols %in% names(result)))
  # total / last come from the (extended) form metadata
  expect_equal(result$total_submissions, 42L)
  expect_equal(result$last_submission_at, "2026-05-01T10:00:00Z")
})

# ---------------------------------------------------------------------------
# Test 1b: the form-metadata request asks for extended metadata, so ODK Central
# includes the submissions count / lastSubmission (otherwise total is always 0).
# ---------------------------------------------------------------------------

test_that("form metadata request sends the X-Extended-Metadata header", {
  headers_by_call <- list()
  call_n <- 0L

  testthat::local_mocked_bindings(
    GET = function(url, ...) {
      call_n <<- call_n + 1L
      cfg <- list(...)$config
      headers_by_call[[call_n]] <<- if (!is.null(cfg)) cfg$headers else character(0)
      fake_resp(url)
    },
    http_error  = function(resp, ...) FALSE,
    status_code = function(resp, ...) 200L,
    content = function(resp, ...) {
      switch(call_n,
        `1` = list(name = "P"),
        `2` = list(name = "F", xmlFormId = "f", state = "open",
                   submissions = 5L, lastSubmission = "2026-06-01T00:00:00Z"),
        `3` = list(),
        list()
      )
    },
    .package = "httr"
  )

  withr::with_envvar(
    list(ODK_URL = "https://odk.example.org/", ODK_TOKEN = "tok"),
    eri_survey_status(project_id = 1L, form_id = "f")
  )

  # Call 2 is the form-metadata GET (call 1 = project meta, call 3 = submissions).
  expect_true("X-Extended-Metadata" %in% names(headers_by_call[[2]]))
  expect_equal(unname(headers_by_call[[2]][["X-Extended-Metadata"]]), "true")
})

# ---------------------------------------------------------------------------
# Test 2: project scope calls list_odk_forms and returns multi-row result
# ---------------------------------------------------------------------------

test_that("project scope returns multi-row result using list_odk_forms", {
  proj_meta_content <- list(name = "Health Project")

  form_meta_content <- list(
    name           = "Form A",
    xmlFormId      = "form_a",
    state          = "open",
    submissions    = 10L,
    lastSubmission = NA_character_
  )

  call_n <- 0L

  testthat::local_mocked_bindings(
    GET = function(url, ...) {
      call_n <<- call_n + 1L
      fake_resp(url)
    },
    http_error  = function(resp, ...) FALSE,
    status_code = function(resp, ...) 200L,
    content = function(resp, ...) {
      if (call_n == 1L) return(proj_meta_content)
      if (grepl("/submissions$", if (is.null(resp$url)) "" else resp$url)) return(list())
      return(form_meta_content)
    },
    .package = "httr"
  )

  testthat::local_mocked_bindings(
    list_odk_forms = function(...) {
      tibble::tibble(xmlFormId = c("form_a", "form_b"), name = c("Form A", "Form B"))
    },
    .package = "erifunctions"
  )

  withr::with_envvar(
    list(ODK_URL = "https://odk.example.org/", ODK_TOKEN = "fake_token"),
    {
      result <- eri_survey_status(project_id = 5L, form_id = NULL)
    }
  )

  expect_s3_class(result, "survey_status")
  expect_equal(nrow(result), 2L)
})

# ---------------------------------------------------------------------------
# Test 3: all-forms scope calls list_odk_projects then list_odk_forms per project
# ---------------------------------------------------------------------------

test_that("all-forms scope iterates over projects and forms", {
  form_meta_content <- list(
    name           = "Form X",
    xmlFormId      = "form_x",
    state          = "open",
    submissions    = 5L,
    lastSubmission = NA_character_
  )

  testthat::local_mocked_bindings(
    GET = function(url, ...) fake_resp(url),
    http_error  = function(resp, ...) FALSE,
    status_code = function(resp, ...) 200L,
    content = function(resp, ...) {
      url <- if (is.null(resp$url)) "" else resp$url
      if (grepl("/submissions$", url)) list() else form_meta_content
    },
    .package = "httr"
  )

  testthat::local_mocked_bindings(
    list_odk_projects = function(...) {
      tibble::tibble(
        project_id  = c(1L, 2L),
        project     = c("Proj A", "Proj B"),
        description = c(NA_character_, NA_character_)
      )
    },
    list_odk_forms = function(...) {
      tibble::tibble(xmlFormId = "form_x", name = "Form X")
    },
    .package = "erifunctions"
  )

  withr::with_envvar(
    list(ODK_URL = "https://odk.example.org/", ODK_TOKEN = "fake_token"),
    {
      result <- eri_survey_status(project_id = NULL, form_id = NULL)
    }
  )

  expect_s3_class(result, "survey_status")
  expect_equal(nrow(result), 2L)
})

# ---------------------------------------------------------------------------
# Test 4: print.survey_status returns invisibly
# ---------------------------------------------------------------------------

test_that("print.survey_status returns x invisibly", {
  stub <- structure(
    tibble::tibble(
      project_id         = 1L,
      project_name       = "Proj",
      form_id            = "f1",
      form_name          = "Form 1",
      server_url         = "https://odk.example.org/",
      status             = "open",
      total_submissions  = 10L,
      last_submission_at = "2026-05-01T10:00:00Z",
      submissions_7d     = 2L,
      submissions_30d    = 5L
    ),
    class = c("survey_status", "tbl_df", "tbl", "data.frame")
  )

  ret <- withVisible(print(stub))
  expect_false(ret$visible)
  expect_identical(ret$value, stub)
})

# ---------------------------------------------------------------------------
# Test 5: correct column types
# ---------------------------------------------------------------------------

test_that("project_id and total_submissions are integer", {
  proj_meta_content <- list(name = "Typed Project")

  form_meta_content <- list(
    name           = "Typed Form",
    xmlFormId      = "typed_form",
    state          = "open",
    submissions    = 7L,
    lastSubmission = "2026-05-20T00:00:00Z"
  )

  call_n <- 0L

  testthat::local_mocked_bindings(
    GET = function(url, ...) {
      call_n <<- call_n + 1L
      fake_resp(url)
    },
    http_error  = function(resp, ...) FALSE,
    status_code = function(resp, ...) 200L,
    content = function(resp, ...) {
      switch(call_n,
        `1` = proj_meta_content,
        `2` = form_meta_content,
        `3` = list(),
        list()
      )
    },
    .package = "httr"
  )

  withr::with_envvar(
    list(ODK_URL = "https://odk.example.org/", ODK_TOKEN = "fake_token"),
    {
      result <- eri_survey_status(project_id = 3L, form_id = "typed_form")
    }
  )

  expect_type(result$project_id,        "integer")
  expect_type(result$total_submissions, "integer")
  expect_type(result$submissions_7d,    "integer")
  expect_type(result$submissions_30d,   "integer")
  expect_type(result$form_id,           "character")
  expect_type(result$status,            "character")
})
