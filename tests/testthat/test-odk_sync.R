#### Tests for eri_odk_sync ####

# --- helpers ------------------------------------------------------------------

make_sync_entry <- function(
    project_id = 7L,
    form_id    = "RiverProspection",
    country    = "uga",
    disease    = "oncho",
    server_url = "https://odk.example.org",
    active     = TRUE
) {
  list(
    server_url        = server_url,
    project_id        = project_id,
    form_id           = form_id,
    form_display_name = form_id,
    country           = country,
    disease           = disease,
    active            = active,
    added_by          = "test.user",
    added_at          = "2026-06-04",
    last_synced       = NULL,
    last_cursor       = NULL
  )
}

make_sync_reg <- function(...) list(forms = list(...))

# --- form not in registry -----------------------------------------------------

test_that("eri_odk_sync errors when form is not in the registry", {
  reg <- list(forms = list())

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )

  expect_error(
    eri_odk_sync(project_id = 99L, form_id = "NoSuchForm", data_con = "mock"),
    "not in the ODK registry"
  )
})

test_that("eri_odk_sync errors when matching entry is inactive", {
  entry <- make_sync_entry(active = FALSE)
  reg   <- make_sync_reg(entry)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(reg, dest)
    },
    .package = "AzureStor"
  )

  expect_error(
    eri_odk_sync(
      project_id = 7L, form_id = "RiverProspection",
      data_con = "mock"
    ),
    "not in the ODK registry"
  )
})

# --- zero submissions ---------------------------------------------------------

test_that("eri_odk_sync overwrites raw with the empty result on zero submissions (default)", {
  entry <- make_sync_entry()
  store <- new_yaml_store(make_sync_reg(entry))
  local_yaml_store(store)

  written_path  <- NULL
  written_obj   <- NULL
  deleted_paths <- character(0)

  local_mocked_bindings(
    .eri_log_session   = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) store$data,
    download_odk_form  = function(...) list(RiverProspection = tibble::tibble()),
    eri_write = function(obj, file_loc, ...) {
      written_obj  <<- obj
      written_path <<- file_loc
      invisible(NULL)
    },
    eri_list = function(...) tibble::tibble(name = "uga/oncho/research/raw/RiverProspection.parquet"),
    eri_delete = function(file_loc, ...) { deleted_paths <<- c(deleted_paths, file_loc) },
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  result <- eri_odk_sync(
    project_id = 7L, form_id = "RiverProspection",
    data_con = "mock"
  )

  expect_equal(written_path, "uga/oncho/research/raw/RiverProspection.parquet")
  expect_equal(nrow(written_obj), 0L)
  expect_false(is.null(store$data$forms[[1]]$last_synced))
  expect_equal(nrow(result), 0L)
  # the only existing raw file is the one this pull just re-wrote -- nothing orphaned
  expect_length(deleted_paths, 0L)
})

test_that("eri_odk_sync deletes an orphaned repeat table when the parent goes to zero rows", {
  entry <- make_sync_entry(form_id = "RiverRepeat")
  store <- new_yaml_store(make_sync_reg(entry))
  local_yaml_store(store)

  written_paths <- character(0)
  deleted_paths <- character(0)

  local_mocked_bindings(
    .eri_log_session   = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) store$data,
    # simulate ODK Central omitting the repeat group's CSV once the parent is empty
    download_odk_form  = function(...) list(RiverRepeat = tibble::tibble()),
    eri_write = function(obj, file_loc, ...) { written_paths <<- c(written_paths, file_loc) },
    # the repeat table from the last non-empty sync is still sitting in raw/
    eri_list = function(...) tibble::tibble(name = c(
      "uga/oncho/research/raw/RiverRepeat.parquet",
      "uga/oncho/research/raw/RiverRepeat-larva_sample.parquet"
    )),
    eri_delete = function(file_loc, ...) { deleted_paths <<- c(deleted_paths, file_loc) },
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  eri_odk_sync(project_id = 7L, form_id = "RiverRepeat", data_con = "mock")

  expect_equal(written_paths, "uga/oncho/research/raw/RiverRepeat.parquet")
  expect_equal(deleted_paths, "uga/oncho/research/raw/RiverRepeat-larva_sample.parquet")
})

test_that("eri_odk_sync(overwrite = FALSE) warns and leaves Azure untouched on zero submissions", {
  entry       <- make_sync_entry()
  reg         <- make_sync_reg(entry)
  eri_written <- FALSE

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(reg, dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    download_odk_form = function(...) list(RiverProspection = tibble::tibble()),
    eri_write         = function(...) { eri_written <<- TRUE },
    .package = "erifunctions"
  )

  expect_warning(
    result <- eri_odk_sync(
      project_id = 7L, form_id = "RiverProspection",
      data_con = "mock", overwrite = FALSE
    ),
    "No submissions"
  )
  expect_null(result)
  expect_false(eri_written)
})

# --- successful sync ----------------------------------------------------------

test_that("eri_odk_sync writes to correct blob path and updates last_synced", {
  entry <- make_sync_entry()
  store <- new_yaml_store(make_sync_reg(entry))
  local_yaml_store(store)

  written_path <- NULL
  written_obj  <- NULL

  fake_data <- tibble::tibble(id = 1:3, value = letters[1:3])

  local_mocked_bindings(
    .eri_log_session   = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) store$data,
    download_odk_form  = function(...) list(RiverProspection = fake_data),
    eri_write = function(obj, file_loc, ...) {
      written_obj  <<- obj
      written_path <<- file_loc
      invisible(NULL)
    },
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  result <- eri_odk_sync(
    project_id = 7L, form_id = "RiverProspection",
    data_con = "mock"
  )

  expect_equal(written_path, "uga/oncho/research/raw/RiverProspection.parquet")
  expect_equal(written_obj, fake_data)
  expect_false(is.null(store$data$forms[[1]]$last_synced))
  expect_invisible(
    eri_odk_sync(
      project_id = 7L, form_id = "RiverProspection",
      data_con = "mock"
    )
  )
})

# --- blob path construction ---------------------------------------------------

test_that("eri_odk_sync uses correct blob path: {country}/{disease}/research/raw/{form_id}.parquet", {
  entry <- make_sync_entry(project_id = 3L, country = "nga", disease = "lf", form_id = "LFSurvey")
  store <- new_yaml_store(make_sync_reg(entry))
  local_yaml_store(store)

  written_path <- NULL

  local_mocked_bindings(
    .eri_log_session   = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) store$data,
    download_odk_form  = function(...) list(LFSurvey = tibble::tibble(x = 1L)),
    eri_write = function(obj, file_loc, ...) {
      written_path <<- file_loc
      invisible(NULL)
    },
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  eri_odk_sync(project_id = 3L, form_id = "LFSurvey", data_con = "mock")

  expect_equal(written_path, "nga/lf/research/raw/LFSurvey.parquet")
})

# --- repeat groups: multiple tables -> multiple Parquets ----------------------

test_that("eri_odk_sync writes one Parquet per table for a repeat-group form", {
  entry <- make_sync_entry(form_id = "RiverRepeat")
  store <- new_yaml_store(make_sync_reg(entry))
  local_yaml_store(store)

  written_paths <- character(0)

  local_mocked_bindings(
    .eri_log_session   = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) store$data,
    download_odk_form = function(...) list(
      RiverRepeat               = tibble::tibble(KEY = c("a", "b")),               # main: 2 submissions
      `RiverRepeat-larva_sample` = tibble::tibble(PARENT_KEY = c("a", "a", "b"))   # repeat: 3 rows
    ),
    eri_write = function(obj, file_loc, ...) {
      written_paths <<- c(written_paths, file_loc)
      invisible(NULL)
    },
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  res <- eri_odk_sync(project_id = 7L, form_id = "RiverRepeat", data_con = "mock")

  expect_equal(written_paths, c(
    "uga/oncho/research/raw/RiverRepeat.parquet",
    "uga/oncho/research/raw/RiverRepeat-larva_sample.parquet"
  ))
  # multi-table sync returns the named list of tables
  expect_named(res, c("RiverRepeat", "RiverRepeat-larva_sample"))
})

# --- download_odk_form table extraction ---------------------------------------

# Mock the download (GET) + unzip so the function reads real fixture CSVs offline.
mock_export <- function(env) {
  parent <- tibble::tibble(KEY = c("a", "b"),        site = c("S1", "S2"))
  child  <- tibble::tibble(PARENT_KEY = c("a", "a", "b"), species = c("x", "y", "z"))
  testthat::local_mocked_bindings(
    GET = function(url, ...) structure(list(status_code = 200L), class = "response"),
    .package = "httr", .env = env
  )
  testthat::local_mocked_bindings(
    .odk_check_response = function(...) invisible(NULL),
    unzip = function(zipfile, exdir, ...) {
      readr::write_csv(parent, file.path(exdir, "myform.csv"))
      readr::write_csv(child,  file.path(exdir, "myform-larva_sample.csv"))
      invisible(character(0))
    },
    .package = "erifunctions", .env = env
  )
}

test_that("download_odk_form(tables = TRUE) returns a named list of all export tables", {
  mock_export(environment())
  out <- download_odk_form(url = "https://x/", auth = "tok",
                           project_id = 1L, form_id = "myform", tables = TRUE)
  expect_type(out, "list")
  expect_named(out, c("myform", "myform-larva_sample"))   # main table first
  expect_equal(nrow(out[["myform"]]), 2L)
  expect_equal(nrow(out[["myform-larva_sample"]]), 3L)
})

test_that("download_odk_form(tables = FALSE) returns only the main table tibble", {
  mock_export(environment())
  out <- download_odk_form(url = "https://x/", auth = "tok",
                           project_id = 1L, form_id = "myform")   # tables = FALSE
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 2L)   # the repeat table is not returned
})
