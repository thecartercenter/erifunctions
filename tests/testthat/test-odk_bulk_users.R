#### Tests for eri_odk_bulk_users ####

# --- helpers ------------------------------------------------------------------

write_csv_tmp <- function(df) {
  path <- tempfile(fileext = ".csv")
  readr::write_csv(df, path)
  path
}

good_csv <- function() {
  tibble::tibble(
    project_id = c(7L, 7L),
    form_id    = c("RiverProspection", "RiverProspection"),
    action     = c("assign", "create"),
    actor_name = c("Jane Fieldworker", "John Fieldworker")
  )
}

mock_forms <- tibble::tibble(
  xmlFormId = c("RiverProspection", "FlyCollection"),
  name      = c("River Prospection", "Fly Collection")
)

mock_users <- tibble::tibble(
  id          = c(101L, 102L),
  displayName = c("Jane Fieldworker", "Existing User"),
  type        = c("field_key", "field_key")
)

# --- pre-flight errors --------------------------------------------------------

test_that("errors on missing CSV file", {
  expect_error(
    eri_odk_bulk_users("/nonexistent/path.csv"),
    "not found"
  )
})

test_that("errors on missing required columns", {
  path <- write_csv_tmp(tibble::tibble(project_id = 1L, form_id = "F"))
  expect_error(
    eri_odk_bulk_users(path),
    "Missing"
  )
  unlink(path)
})

test_that("pre-flight aborts on invalid action value", {
  df <- good_csv()
  df$action[1] <- "fly"
  path <- write_csv_tmp(df)

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms         = function(...) mock_forms,
    list_all_odk_app_users = function(...) mock_users,
    .package = "erifunctions"
  )

  expect_error(
    eri_odk_bulk_users(path),
    "invalid action"
  )
  unlink(path)
})

test_that("pre-flight aborts on unknown form_id", {
  df <- tibble::tibble(
    project_id = 7L,
    form_id    = "NoSuchForm",
    action     = "assign",
    actor_name = "Jane Fieldworker"
  )
  path <- write_csv_tmp(df)

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms         = function(...) mock_forms,
    list_all_odk_app_users = function(...) mock_users,
    .package = "erifunctions"
  )

  expect_error(
    eri_odk_bulk_users(path),
    "not found in project"
  )
  unlink(path)
})

test_that("pre-flight aborts on conflicting actions for same user/form", {
  df <- tibble::tibble(
    project_id = c(7L, 7L),
    form_id    = c("RiverProspection", "RiverProspection"),
    action     = c("assign", "remove"),
    actor_name = c("Jane Fieldworker", "Jane Fieldworker")
  )
  path <- write_csv_tmp(df)

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms         = function(...) mock_forms,
    list_all_odk_app_users = function(...) mock_users,
    .package = "erifunctions"
  )

  expect_error(
    eri_odk_bulk_users(path),
    "conflicting actions"
  )
  unlink(path)
})

test_that("pre-flight collects multiple errors before aborting", {
  df <- tibble::tibble(
    project_id = c(7L, 7L),
    form_id    = c("NoSuchForm", "RiverProspection"),
    action     = c("fly", "assign"),
    actor_name = c("A", "B")
  )
  path <- write_csv_tmp(df)

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms         = function(...) mock_forms,
    list_all_odk_app_users = function(...) mock_users,
    .package = "erifunctions"
  )

  err <- tryCatch(eri_odk_bulk_users(path), error = function(e) e)
  msg <- conditionMessage(err)
  # Both the invalid-action and the unknown-form errors should appear
  expect_match(msg, "invalid action")
  expect_match(msg, "not found in project")
  unlink(path)
})

# --- dry_run ------------------------------------------------------------------

test_that("dry_run returns invisible NULL without mutating", {
  path <- write_csv_tmp(good_csv())
  called <- FALSE

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms         = function(...) mock_forms,
    list_all_odk_app_users = function(...) mock_users,
    update_odk_app_user_role = function(...) { called <<- TRUE; TRUE },
    .package = "erifunctions"
  )

  result <- eri_odk_bulk_users(path, dry_run = TRUE)
  expect_null(result)
  expect_false(called)
  unlink(path)
})

# --- auto-create on assign ----------------------------------------------------

test_that("assign auto-creates actor when not found, then assigns", {
  df <- tibble::tibble(
    project_id = 7L,
    form_id    = "RiverProspection",
    action     = "assign",
    actor_name = "Brand New User"
  )
  path <- write_csv_tmp(df)

  create_called <- FALSE
  assign_called <- FALSE
  # First call returns empty (user absent); second returns with the new user
  list_users_calls <- 0L

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms = function(...) mock_forms,
    list_all_odk_app_users = function(...) {
      list_users_calls <<- list_users_calls + 1L
      if (list_users_calls == 1L) {
        # pre-flight fetch — user absent
        tibble::tibble(id = integer(), displayName = character(), type = character())
      } else {
        # post-create refresh — user present
        tibble::tibble(id = 200L, displayName = "Brand New User", type = "field_key")
      }
    },
    update_odk_app_user_role = function(action, ...) {
      if (action == "create") create_called <<- TRUE
      if (action == "assign") assign_called <<- TRUE
      list(actor_name = "Brand New User", actor_id = 200L, project_id = 7L)
    },
    .package = "erifunctions"
  )

  out <- eri_odk_bulk_users(path)
  expect_true(create_called)
  expect_true(assign_called)
  expect_equal(out$result, "assign")
  unlink(path)
})

# --- result tibble ------------------------------------------------------------

test_that("returns invisible tibble with result column on success", {
  df <- tibble::tibble(
    project_id = 7L,
    form_id    = "RiverProspection",
    action     = "create",
    actor_name = "New User"
  )
  path <- write_csv_tmp(df)

  local_mocked_bindings(
    .odk_creds = function(...) list(url = "https://x.org/", auth = "tok"),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_odk_forms         = function(...) mock_forms,
    list_all_odk_app_users = function(...) tibble::tibble(
      id = integer(), displayName = character(), type = character()
    ),
    update_odk_app_user_role = function(...) list(actor_name = "New User", actor_id = 99L),
    .package = "erifunctions"
  )

  out <- withVisible(eri_odk_bulk_users(path))
  expect_false(out$visible)
  expect_s3_class(out$value, "tbl_df")
  expect_true("result" %in% names(out$value))
  expect_equal(out$value$result, "created")
  unlink(path)
})
