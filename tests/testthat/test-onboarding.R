#### Tests for onboarding helpers ####

# --- eri_onboard_country ------------------------------------------------------

test_that("eri_onboard_country dry_run returns invisible NULL without writing files", {
  tmp <- tempdir()
  result <- eri_onboard_country("uga", "Uganda", "oncho",
                                 path = tmp, dry_run = TRUE)
  expect_null(result)
  expect_false(file.exists(file.path(tmp, "uga_oncho_surveillance_aggregate.yaml")))
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
  expect_equal(out_path, file.path(tmp, "uga_oncho_surveillance_aggregate.yaml"))
  expect_true(file.exists(out_path))

  content <- paste(readLines(out_path, warn = FALSE), collapse = "\n")
  expect_match(content, "country: uga")
  expect_match(content, "disease: oncho")
  expect_match(content, "data_source: surveillance")
  expect_match(content, "data_type: aggregate")
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
  # ADLS-safe creation makes each missing parent level, so the three layer leaves plus their
  # shared parents (uga, uga/oncho, uga/oncho/surveillance) are all created.
  expect_true("uga/oncho/surveillance/raw"       %in% created)
  expect_true("uga/oncho/surveillance/staged"    %in% created)
  expect_true("uga/oncho/surveillance/processed" %in% created)
  unlink(file.path(tmp, "uga_oncho_surveillance_aggregate.yaml"))
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

test_that("eri_onboard_cmr create_dirs makes the canonical rblf/cmr directories", {
  tmp <- tempdir()
  captured <- NULL

  local_mocked_bindings(
    .onboarding_resolve_con = function(...) "mock_con",
    .onboarding_create_azure_dirs = function(country_code, disease, data_con,
                                             data_types = "surveillance") {
      captured <<- list(disease = disease, data_types = data_types)
      paste(country_code, disease, data_types, c("raw", "staged", "processed"), sep = "/")
    },
    .package = "erifunctions"
  )

  out <- eri_onboard_cmr("uga", "Uganda", create_dirs = TRUE, path = tmp)
  # CMR is filed under the combined rblf code, matching eri_stage_cmr / eri_approve.
  expect_equal(captured$disease, "rblf")
  expect_equal(captured$data_types, "cmr")
  unlink(out)
})

test_that("eri_onboard_cmr does not touch Azure when create_dirs is FALSE (default)", {
  tmp    <- tempdir()
  called <- FALSE

  local_mocked_bindings(
    get_azure_storage_connection  = function(...) "mock_con",
    .onboarding_create_azure_dirs = function(...) { called <<- TRUE; character(0) },
    .package = "erifunctions"
  )

  out <- eri_onboard_cmr("uga", "Uganda", path = tmp)   # create_dirs defaults to FALSE
  expect_false(called)
  unlink(out)
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
  path <- system.file("schemas/dr_malaria_surveillance_aggregate.yaml", package = "erifunctions")
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

# --- eri_onboard_disease -------------------------------------------------------

test_that("eri_onboard_disease dry_run returns NULL without writing files", {
  tmp <- tempdir()
  result <- eri_onboard_disease("schisto", "ug", output_dir = tmp, dry_run = TRUE)
  expect_null(result)
  expect_false(file.exists(file.path(tmp, "ug_schisto_programmatic_treatment.yaml")))
  expect_false(file.exists(file.path(tmp, "ug_schisto_research_prevalence.yaml")))
})

test_that("eri_onboard_disease generates one file per data_type", {
  tmp <- tempdir()
  paths <- eri_onboard_disease("schisto", "ug", output_dir = tmp)
  expect_length(paths, 2L)
  expect_true(all(file.exists(paths)))
  expect_true(any(grepl("programmatic_treatment", paths)))
  expect_true(any(grepl("research_prevalence", paths)))
  unlink(paths)
})

test_that("eri_onboard_disease mda skeleton contains required columns", {
  tmp  <- tempdir()
  paths <- eri_onboard_disease("rb", "ug", data_types = "mda", output_dir = tmp)
  content <- paste(readLines(paths[[1L]], warn = FALSE), collapse = "\n")
  expect_match(content, "target_pop")
  expect_match(content, "treated")
  expect_match(content, "coverage_pct")
  unlink(paths)
})

test_that("eri_onboard_disease prevalence skeleton contains result and survey_type", {
  tmp   <- tempdir()
  paths <- eri_onboard_disease("sth", "global", data_types = "prevalence", output_dir = tmp)
  content <- paste(readLines(paths[[1L]], warn = FALSE), collapse = "\n")
  expect_match(content, "result")
  expect_match(content, "survey_type")
  expect_match(content, "lat")
  unlink(paths)
})

test_that("eri_onboard_disease errors on unsupported data_type", {
  expect_error(
    eri_onboard_disease("rb", "ug", data_types = "cas_count"),
    class = "error"
  )
})

# --- bundled schemas for new programs -----------------------------------------

# ADR-0012 identity: (country, disease, data_source, data_type)
new_schemas <- list(
  c("uga",    "oncho",   "programmatic", "treatment"),
  c("uga",    "oncho",   "research",     "prevalence"),
  c("global", "schisto", "programmatic", "treatment"),
  c("global", "schisto", "research",     "prevalence"),
  c("global", "sth",     "programmatic", "treatment"),
  c("global", "sth",     "research",     "prevalence")
)

for (s in new_schemas) {
  local({
    co <- s[[1L]]; di <- s[[2L]]; ds <- s[[3L]]; dt <- s[[4L]]
    stem <- paste(co, di, ds, dt, sep = "_")
    test_that(paste0("load_dq_schema loads ", stem), {
      result <- load_dq_schema(co, di, ds, dt, azcontainer = NULL)
      expect_type(result, "list")
      expect_true(!is.null(result$disease))
    })
    test_that(paste0("eri_schema_validate passes for ", stem), {
      path <- system.file(paste0("schemas/", stem, ".yaml"), package = "erifunctions")
      skip_if(nchar(path) == 0L, paste("schema file not found:", stem))
      result <- suppressWarnings(eri_schema_validate(path))
      expect_s3_class(result, "tbl_df")
      expect_equal(nrow(result), 0L)
    })
  })
}
