#### Tests for ODK form registry ####

# --- helpers ------------------------------------------------------------------

make_reg <- function(...) {
  entries <- list(...)
  list(forms = entries)
}

make_entry <- function(
    server_url = "https://odk.example.org",
    project_id = 7L,
    form_id    = "RiverProspection",
    country    = "uga",
    disease    = "oncho",
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

# Minimal mock data_con that records uploads and serves staged registry content
mock_data_con <- function(initial_reg = list(forms = list())) {
  env <- new.env(parent = emptyenv())
  env$registry <- initial_reg
  env$log_written <- FALSE

  # Return list mimicking the AzureStor container interface via mock functions
  # (tests use local_mocked_bindings to intercept AzureStor calls)
  env
}

# --- input validation ---------------------------------------------------------

test_that("eri_odk_register errors on unknown country", {
  expect_error(
    eri_odk_register(
      project_id = 1, form_id = "F", country = "xyz",
      disease = "oncho", server_url = "https://x.org",
      data_con = mock_data_con()
    ),
    "not a known ERI country"
  )
})

test_that("eri_odk_register errors on duplicate active entry", {
  entry   <- make_entry()
  reg     <- make_reg(entry)
  written <- NULL

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(reg, dest)
    },
    storage_dir_exists = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      written <<- yaml::read_yaml(src)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  expect_error(
    eri_odk_register(
      project_id = 7L, form_id = "RiverProspection",
      country = "uga", disease = "oncho",
      server_url = "https://odk.example.org",
      data_con = "mock"
    ),
    "already registered"
  )
})

test_that("eri_odk_deregister errors when entry not found", {
  reg <- list(forms = list())

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(reg, dest)
    },
    .package = "AzureStor"
  )

  expect_error(
    eri_odk_deregister(
      project_id = 99L, form_id = "NoSuchForm",
      data_con = "mock"
    ),
    "No active registered form"
  )
})

test_that("eri_odk_deregister errors when multiple entries match without server_url", {
  e1 <- make_entry(server_url = "https://server1.org")
  e2 <- make_entry(server_url = "https://server2.org")
  reg <- make_reg(e1, e2)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(reg, dest)
    },
    .package = "AzureStor"
  )

  expect_error(
    eri_odk_deregister(
      project_id = 7L, form_id = "RiverProspection",
      data_con = "mock"
    ),
    "disambiguate"
  )
})

# --- purge (hard delete) ------------------------------------------------------

test_that("eri_odk_purge removes both active and inactive matching entries", {
  active   <- make_entry(form_id = "SandboxForm", active = TRUE)
  inactive <- make_entry(form_id = "SandboxForm", active = FALSE)   # already soft-deleted
  other    <- make_entry(form_id = "RealForm", project_id = 7L, active = TRUE)
  store    <- new_yaml_store(make_reg(active, inactive, other))
  local_yaml_store(store)

  local_mocked_bindings(
    .eri_write_log     = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) store$data,
    .package = "erifunctions"
  )

  n <- eri_odk_purge(project_id = 7L, form_id = "SandboxForm", data_con = "mock")
  expect_equal(n, 2L)
  # The real form survives; both SandboxForm rows are gone.
  expect_length(store$data$forms, 1L)
  expect_equal(store$data$forms[[1]]$form_id, "RealForm")
})

test_that("eri_odk_purge errors when no entry (active or inactive) matches", {
  reg <- make_reg(make_entry(form_id = "RealForm"))

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) yaml::write_yaml(reg, dest),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_write_log = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  expect_error(
    eri_odk_purge(project_id = 7L, form_id = "NoSuchForm", data_con = "mock"),
    "No registered form"
  )
})

# --- round-trip ---------------------------------------------------------------

test_that("register / deregister / list round-trip works", {
  store <- new_yaml_store(list(forms = list()))
  local_yaml_store(store)

  local_mocked_bindings(
    .eri_write_log     = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) {
      if (is.null(store$data) || length(store$data$forms) == 0L) list(forms = list())
      else store$data
    },
    .package = "erifunctions"
  )

  # Register
  e <- eri_odk_register(
    project_id = 7L, form_id = "RiverProspection",
    country = "uga", disease = "oncho",
    server_url = "https://odk.example.org",
    data_con = "mock"
  )
  expect_equal(e$form_id, "RiverProspection")
  expect_true(e$active)

  # List — should have 1 entry
  lst <- eri_odk_list_registered(data_con = "mock")
  expect_equal(nrow(lst), 1L)
  expect_equal(lst$form_id, "RiverProspection")
  expect_equal(lst$country, "uga")

  # Deregister
  eri_odk_deregister(
    project_id = 7L, form_id = "RiverProspection",
    server_url = "https://odk.example.org",
    data_con = "mock"
  )

  # List — should now be empty
  lst2 <- eri_odk_list_registered(data_con = "mock")
  expect_equal(nrow(lst2), 0L)
})

test_that("eri_odk_list_registered returns typed empty tibble when no forms", {
  reg <- list(forms = list())

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )

  out <- eri_odk_list_registered(data_con = "mock")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c(
    "server_url", "project_id", "form_id", "form_display_name",
    "country", "disease", "added_by", "added_at", "last_synced"
  ))
})

test_that("form_display_name defaults to form_id when not supplied", {
  store <- new_yaml_store(list(forms = list()))
  local_yaml_store(store)

  local_mocked_bindings(
    .eri_write_log     = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) {
      if (is.null(store$data) || length(store$data$forms) == 0L) list(forms = list())
      else store$data
    },
    .package = "erifunctions"
  )

  eri_odk_register(
    project_id = 3L, form_id = "MyForm",
    country = "nga", disease = "lf",
    server_url = "https://odk2.example.org",
    data_con = "mock"
  )

  expect_equal(store$data$forms[[1]]$form_display_name, "MyForm")
})

# --- ADR-0020: country/disease normalization -----------------------------------

test_that("eri_odk_register normalizes country/disease casing before storing", {
  store <- new_yaml_store(list(forms = list()))
  local_yaml_store(store)

  local_mocked_bindings(
    .eri_write_log     = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) {
      if (is.null(store$data) || length(store$data$forms) == 0L) list(forms = list())
      else store$data
    },
    .package = "erifunctions"
  )

  eri_odk_register(
    project_id = 5L, form_id = "TAS3",
    country = "UGA", disease = " LF ",
    server_url = "https://odk3.example.org",
    data_con = "mock"
  )

  expect_equal(store$data$forms[[1]]$country, "uga")
  expect_equal(store$data$forms[[1]]$disease, "lf")
})

test_that("eri_odk_register warns (does not error) on an unregistered disease", {
  store <- new_yaml_store(list(forms = list()))
  local_yaml_store(store)

  local_mocked_bindings(
    .eri_write_log     = function(...) invisible(NULL),
    .odk_registry_read = function(data_con) {
      if (is.null(store$data) || length(store$data$forms) == 0L) list(forms = list())
      else store$data
    },
    .package = "erifunctions"
  )

  expect_warning(
    eri_odk_register(
      project_id = 6L, form_id = "NewDiseaseForm",
      country = "uga", disease = "newdisease",
      server_url = "https://odk4.example.org",
      data_con = "mock"
    ),
    "disease"
  )
  expect_equal(store$data$forms[[1]]$disease, "newdisease")
})

test_that("eri_odk_register still hard-errors on an unknown country regardless of case", {
  expect_error(
    eri_odk_register(
      project_id = 1, form_id = "F", country = "XYZ",
      disease = "oncho", server_url = "https://x.org",
      data_con = mock_data_con()
    ),
    "not a known ERI country"
  )
})

# --- .odk_data_con auto-connect ------------------------------------------------

test_that(".odk_data_con delegates auto-connect to get_azure_storage_connection", {
  # A passed connection short-circuits (no auth).
  expect_equal(erifunctions:::.odk_data_con("passed"), "passed")

  # Auto-connect (NULL) routes through the shared connector — which carries the
  # zero-config auth defaults — targeting the data container. Reimplementing the
  # token from bare Sys.getenv() (as this once did) sent an empty client_id.
  seen <- NULL
  local_mocked_bindings(
    get_azure_storage_connection = function(storage_name, ...) {
      seen <<- storage_name
      "auto_con"
    },
    .package = "erifunctions"
  )
  # NA unsets the var on every platform; "" would stay an empty string on Linux
  # but unset the var on Windows, so `unset=` diverges across OSes.
  withr::local_envvar(ERIFUNCTIONS_DATA_STORAGE_NAME = NA)
  expect_equal(erifunctions:::.odk_data_con(NULL), "auto_con")
  expect_equal(seen, "data")   # default when the env var is unset
})
