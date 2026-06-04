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

test_that("eri_odk_sync warns and returns invisible NULL on zero submissions", {
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
    download_odk_form = function(...) tibble::tibble(),
    eri_write         = function(...) { eri_written <<- TRUE },
    .package = "erifunctions"
  )

  expect_warning(
    result <- eri_odk_sync(
      project_id = 7L, form_id = "RiverProspection",
      data_con = "mock"
    ),
    "No submissions"
  )
  expect_null(result)
  expect_false(eri_written)
})

# --- successful sync ----------------------------------------------------------

test_that("eri_odk_sync writes to correct blob path and updates last_synced", {
  entry      <- make_sync_entry()
  stored_reg <- make_sync_reg(entry)

  written_path <- NULL
  written_obj  <- NULL

  local_mocked_bindings(
    storage_file_exists = function(container, path, ...) {
      grepl("registry\\.yaml$", path) && length(stored_reg$forms) > 0
    },
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(stored_reg, dest)
    },
    storage_dir_exists = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      if (grepl("registry\\.yaml$", dest)) {
        stored_reg <<- yaml::read_yaml(src)
      }
    },
    .package = "AzureStor"
  )

  fake_data <- tibble::tibble(id = 1:3, value = letters[1:3])

  local_mocked_bindings(
    download_odk_form = function(...) fake_data,
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

  expect_equal(written_path, "uga/oncho/odk/raw/RiverProspection.parquet")
  expect_equal(written_obj, fake_data)
  expect_false(is.null(stored_reg$forms[[1]]$last_synced))
  expect_invisible(
    eri_odk_sync(
      project_id = 7L, form_id = "RiverProspection",
      data_con = "mock"
    )
  )
})

# --- blob path construction ---------------------------------------------------

test_that("eri_odk_sync uses correct blob path: {country}/{disease}/odk/raw/{form_id}.parquet", {
  entry      <- make_sync_entry(project_id = 3L, country = "nga", disease = "lf", form_id = "LFSurvey")
  stored_reg <- make_sync_reg(entry)

  written_path <- NULL

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(stored_reg, dest)
    },
    storage_dir_exists = function(...) TRUE,
    storage_upload     = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  local_mocked_bindings(
    download_odk_form = function(...) tibble::tibble(x = 1L),
    eri_write = function(obj, file_loc, ...) {
      written_path <<- file_loc
      invisible(NULL)
    },
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  eri_odk_sync(project_id = 3L, form_id = "LFSurvey", data_con = "mock")

  expect_equal(written_path, "nga/lf/odk/raw/LFSurvey.parquet")
})
