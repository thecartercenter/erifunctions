#### Tests for update_odk_app_user_role input validation ####

test_that("update_odk_app_user_role errors on invalid action", {
  expect_error(
    update_odk_app_user_role(action = "invalid"),
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

#### Tests for init_odk_connection defaults ####

test_that("init_odk_connection defaults use env vars not keys.yaml", {
  # Verify the function signature does not reference here::here or keys.yaml
  fn_body <- deparse(formals(init_odk_connection))
  expect_false(any(grepl("keys\\.yaml", fn_body)))
  expect_false(any(grepl("here::", fn_body)))
})

#### Network-dependent tests (skipped outside live environment) ####

test_that("ODK connection can be initialised in testing mode", {
  skip_if_offline()
  skip_on_ci()
  expect_true(init_odk_connection(testing = TRUE, verbose = FALSE))
})

test_that("ODK API returns expected response in testing mode", {
  skip_if_offline()
  skip_on_ci()
  expect_equal(list_odk_projects(url = "https://rblf.tccodk.org/", testing = TRUE), 404.1)
  expect_equal(list_odk_forms(url = "https://rblf.tccodk.org/", testing = TRUE), 404.1)
  expect_equal(download_odk_form(url = "https://rblf.tccodk.org/", testing = TRUE), 404.1)
  expect_equal(list_all_odk_app_users(url = "https://rblf.tccodk.org/", testing = TRUE), 404.1)
})
