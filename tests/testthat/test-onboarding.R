#### Tests for onboarding helpers ####

# --- eri_onboard_country ------------------------------------------------------

test_that("eri_onboard_country dry_run returns invisible NULL without writing files", {
  tmp <- tempdir()
  result <- eri_onboard_country("uga", "Uganda", "oncho",
                                 path = tmp, dry_run = TRUE)
  expect_null(result)
  expect_false(file.exists(file.path(tmp, "uga_oncho_schema.yaml")))
})

test_that("eri_onboard_country writes a YAML file to path", {
  tmp <- tempdir()

  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    create_storage_dir  = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out_path <- eri_onboard_country("uga", "Uganda", "oncho", path = tmp)
  expect_equal(out_path, file.path(tmp, "uga_oncho_schema.yaml"))
  expect_true(file.exists(out_path))

  content <- paste(readLines(out_path, warn = FALSE), collapse = "\n")
  expect_match(content, "country: Uganda")
  expect_match(content, "disease: oncho")
  expect_match(content, "year_col")
  unlink(out_path)
})

test_that("eri_onboard_country errors on invalid language", {
  expect_error(
    eri_onboard_country("uga", "Uganda", "oncho", language = "de", dry_run = TRUE),
    "language"
  )
})

test_that("eri_onboard_country creates Azure directories", {
  tmp <- tempdir()
  created <- character(0)

  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    create_storage_dir = function(container, path, ...) {
      created <<- c(created, path)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  eri_onboard_country("uga", "Uganda", "oncho", path = tmp)
  expect_length(created, 3L)
  expect_true(any(grepl("raw", created)))
  expect_true(any(grepl("staged", created)))
  expect_true(any(grepl("processed", created)))
  unlink(file.path(tmp, "uga_oncho_schema.yaml"))
})

# --- eri_onboard_cmr ----------------------------------------------------------

test_that("eri_onboard_cmr dry_run returns invisible NULL without writing files", {
  tmp <- tempdir()
  result <- eri_onboard_cmr("uga", "Uganda", path = tmp, dry_run = TRUE)
  expect_null(result)
  expect_false(file.exists(file.path(tmp, "uga_cmr_schema.yaml")))
})

test_that("eri_onboard_cmr writes a YAML file with correct structure", {
  tmp <- tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out_path <- eri_onboard_cmr("uga", "Uganda", path = tmp)
  expect_true(file.exists(out_path))

  content <- paste(readLines(out_path, warn = FALSE), collapse = "\n")
  expect_match(content, "country: Uganda")
  expect_match(content, "country_code: uga")
  expect_match(content, "template: english_cmr")
  unlink(out_path)
})

test_that("eri_onboard_cmr uses french_cmr template for language fr", {
  tmp <- tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out_path <- eri_onboard_cmr("tcd", "Chad", language = "fr", path = tmp)
  content  <- paste(readLines(out_path, warn = FALSE), collapse = "\n")
  expect_match(content, "template: french_cmr")
  unlink(out_path)
})

# --- eri_schema_validate ------------------------------------------------------

test_that("eri_schema_validate errors on missing file", {
  expect_error(
    eri_schema_validate("/nonexistent/schema.yaml"),
    "not found"
  )
})

test_that("eri_schema_validate returns empty tibble for valid schema", {
  path <- system.file("schemas/dominican_republic_malaria.yaml", package = "erifunctions")
  skip_if(nchar(path) == 0, "bundled schema not found")
  result <- eri_schema_validate(path)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("eri_schema_validate flags missing required top-level keys", {
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(list(country = "Uganda", disease = "oncho"), tmp)
  result <- suppressWarnings(eri_schema_validate(tmp))
  expect_gt(nrow(result), 0L)
  expect_true(any(result$field == "columns"))
  expect_true(any(result$field == "temporal"))
  unlink(tmp)
})

test_that("eri_schema_validate flags columns with missing required/type", {
  schema <- list(
    country  = "Uganda",
    disease  = "oncho",
    temporal = list(year_col = "Year", period_col = "EpiWeek"),
    columns  = list(
      Year    = list(required = TRUE, type = "numeric"),
      EpiWeek = list(required = TRUE)   # missing type
    )
  )
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(schema, tmp)
  result <- suppressWarnings(eri_schema_validate(tmp))
  expect_true(any(grepl("EpiWeek", result$field) & result$issue_type == "missing_field"))
  unlink(tmp)
})

test_that("eri_schema_validate flags consistency rules referencing unknown columns", {
  schema <- list(
    country  = "Uganda",
    disease  = "oncho",
    temporal = list(year_col = "Year", period_col = "EpiWeek"),
    columns  = list(
      Year    = list(required = TRUE, type = "numeric"),
      EpiWeek = list(required = TRUE, type = "numeric")
    ),
    consistency = list(
      bad_rule = list(lhs = "NoSuchCol", op = "<=", rhs_value = 0,
                      message = "test")
    )
  )
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(schema, tmp)
  result <- suppressWarnings(eri_schema_validate(tmp))
  expect_true(any(result$issue_type == "unknown_column_reference"))
  unlink(tmp)
})

test_that("eri_schema_validate flags invalid column type", {
  schema <- list(
    country  = "Uganda",
    disease  = "oncho",
    temporal = list(year_col = "Year", period_col = "EpiWeek"),
    columns  = list(
      Year    = list(required = TRUE, type = "integer"),  # invalid
      EpiWeek = list(required = TRUE, type = "numeric")
    )
  )
  tmp <- tempfile(fileext = ".yaml")
  yaml::write_yaml(schema, tmp)
  result <- suppressWarnings(eri_schema_validate(tmp))
  expect_true(any(result$issue_type == "invalid_value" & grepl("Year", result$field)))
  unlink(tmp)
})
