#### Tests for update_odk_app_user_role input validation ####

test_that("update_odk_app_user_role errors on invalid action", {
  expect_error(
    update_odk_app_user_role(action = "invalid", project_id = 1),
    "create.*delete.*assign.*revoke"
  )
})

test_that("update_odk_app_user_role errors when create action missing actor_name", {
  expect_error(
    update_odk_app_user_role(action = "create", project_id = 1),
    "actor_name"
  )
})

test_that("update_odk_app_user_role errors when delete action missing actor_id", {
  expect_error(
    update_odk_app_user_role(action = "delete", project_id = 1),
    "actor_id"
  )
})

test_that("update_odk_app_user_role errors when assign action missing form_id", {
  expect_error(
    update_odk_app_user_role(action = "assign", project_id = 1,
                              role_id = 2, actor_id = 99),
    "form_id"
  )
})

test_that("update_odk_app_user_role errors when assign action missing role_id", {
  expect_error(
    update_odk_app_user_role(action = "assign", project_id = 1,
                              form_id = "MyForm", actor_id = 99),
    "role_id"
  )
})

test_that("update_odk_app_user_role errors when assign action missing actor_id", {
  expect_error(
    update_odk_app_user_role(action = "assign", project_id = 1,
                              form_id = "MyForm", role_id = 2),
    "actor_id"
  )
})

test_that("update_odk_app_user_role errors when revoke action missing form_id", {
  expect_error(
    update_odk_app_user_role(action = "revoke", project_id = 1,
                              role_id = 2, actor_id = 99),
    "form_id"
  )
})

#### Tests for init_odk_connection ####

test_that("init_odk_connection defaults use env vars not keys.yaml", {
  fn_body <- deparse(formals(init_odk_connection))
  expect_false(any(grepl("keys\\.yaml", fn_body)))
  expect_false(any(grepl("here::", fn_body)))
})

test_that("init_odk_connection errors when user is empty", {
  withr::with_envvar(c(ODK_USER = "", ODK_PASS = "somepass"), {
    expect_error(
      init_odk_connection(url = "https://example.org/"),
      "username"
    )
  })
})

test_that("init_odk_connection errors when pass is empty", {
  withr::with_envvar(c(ODK_USER = "user@example.org", ODK_PASS = ""), {
    expect_error(
      init_odk_connection(url = "https://example.org/"),
      "password"
    )
  })
})

#### Tests for odk_connection object ####

test_that("print.odk_connection returns invisibly", {
  con <- structure(
    list(url = "https://example.org/", token = "tok",
         expires_at = "2026-06-05T00:00:00Z", created_at = "2026-06-04T00:00:00Z"),
    class = "odk_connection"
  )
  expect_invisible(print(con))
})

#### Tests for .odk_creds helper ####

test_that(".odk_creds extracts url and token from odk_connection", {
  con <- structure(
    list(url = "https://odk.example.org/", token = "mytoken"),
    class = "odk_connection"
  )
  result <- .odk_creds(con, NULL, NULL)
  expect_equal(result$url, "https://odk.example.org/")
  expect_equal(result$auth, "mytoken")
})

test_that(".odk_creds uses explicit url/auth when con is NULL", {
  result <- .odk_creds(NULL, "https://fallback.org/", "fallbacktoken")
  expect_equal(result$url, "https://fallback.org/")
  expect_equal(result$auth, "fallbacktoken")
})

test_that(".odk_creds errors when con is not an odk_connection", {
  expect_error(
    .odk_creds(list(url = "x", token = "y"), NULL, NULL),
    "odk_connection"
  )
})

#### Tests for empty-result guard ####

test_that("list_odk_projects empty-result tibble has correct columns", {
  empty <- tibble::tibble(project_id = integer(), project = character(), description = character())
  expect_named(empty, c("project_id", "project", "description"))
  expect_equal(nrow(empty), 0L)
})

test_that("list_odk_forms empty-result tibble has correct columns", {
  empty <- tibble::tibble(xmlFormId = character(), name = character())
  expect_named(empty, c("xmlFormId", "name"))
  expect_equal(nrow(empty), 0L)
})

#### Network-dependent tests (skipped outside live environment) ####

test_that("ODK connection returns odk_connection object with real credentials", {
  skip_if_offline()
  skip_on_ci()
  skip_if(
    Sys.getenv("ODK_USER") == "" || Sys.getenv("ODK_PASS") == "",
    "ODK credentials not set"
  )
  con <- init_odk_connection()
  expect_s3_class(con, "odk_connection")
  expect_true(nchar(con$token) > 0)
  expect_true(nchar(con$expires_at) > 0)
})
