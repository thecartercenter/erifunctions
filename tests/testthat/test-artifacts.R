#### Tests for artifact registry ####

# Shared mock registry helpers
.mock_empty_registry    <- function(...) FALSE  # storage_file_exists → no registry yet
.mock_dir_exists_false  <- function(...) FALSE
.mock_create_dir        <- function(...) invisible(NULL)
.mock_upload            <- function(...) invisible(NULL)
.mock_download_noop     <- function(...) invisible(NULL)

.with_artifact_mocks <- function(
    file_exists_fn = .mock_empty_registry,
    dir_exists_fn  = .mock_dir_exists_false,
    code
) {
  local_mocked_bindings(
    storage_file_exists = file_exists_fn,
    storage_dir_exists  = dir_exists_fn,
    create_storage_dir  = .mock_create_dir,
    storage_upload      = .mock_upload,
    storage_download    = .mock_download_noop,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  force(code)
}

# --- eri_artifact_upload -------------------------------------------------------

test_that("eri_artifact_upload errors on missing local file", {
  expect_error(
    eri_artifact_upload("/nonexistent/file.xlsx", "x", "study_data", "test"),
    "not found"
  )
})

test_that("eri_artifact_upload errors on invalid type", {
  tmp <- tempfile(fileext = ".xlsx")
  writeLines("x", tmp)
  withr::defer(unlink(tmp))
  expect_error(
    eri_artifact_upload(tmp, "x", "bad_type", "test"),
    "should be one of"
  )
})

test_that("eri_artifact_upload registers entry in registry and uploads file", {
  tmp <- tempfile(fileext = ".xlsx")
  writeLines("data", tmp)
  withr::defer(unlink(tmp))

  uploaded <- character(0)
  registered <- NULL

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_dir_exists  = function(...) FALSE,
    create_storage_dir  = function(...) invisible(NULL),
    storage_upload      = function(con, src, dest, ...) {
      uploaded <<- c(uploaded, dest)
      invisible(NULL)
    },
    storage_download    = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list()),
    .eri_artifact_registry_write = function(registry, ...) {
      registered <<- registry$entries[[1L]]
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  result <- eri_artifact_upload(tmp, "dr_irs_2024", "study_data", "IRS data DR 2024")

  expect_equal(result$name,        "dr_irs_2024")
  expect_equal(result$type,        "study_data")
  expect_equal(result$description, "IRS data DR 2024")
  expect_false(result$archived)
  expect_match(result$azure_path, "artifacts/study_data/dr_irs_2024/")
  expect_false(is.null(registered))
})

test_that("eri_artifact_upload upserts an existing entry by name", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("a,b", tmp)
  withr::defer(unlink(tmp))

  existing_entry <- list(
    name = "my_artifact", type = "reference",
    description = "old desc", version = NA_character_,
    azure_path = "artifacts/reference/my_artifact/old.csv",
    filename = "old.csv", file_format = "csv",
    uploaded_at = "2026-01-01T00:00:00Z", uploaded_by = "user",
    archived = FALSE
  )

  final_registry <- NULL

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_dir_exists  = function(...) TRUE,
    create_storage_dir  = function(...) invisible(NULL),
    storage_upload      = function(...) invisible(NULL),
    storage_download    = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list(existing_entry)),
    .eri_artifact_registry_write = function(registry, ...) {
      final_registry <<- registry
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  eri_artifact_upload(tmp, "my_artifact", "reference", "new desc")
  expect_equal(length(final_registry$entries), 1L)
  expect_equal(final_registry$entries[[1L]]$description, "new desc")
})

# --- eri_artifact_list --------------------------------------------------------

test_that("eri_artifact_list returns typed empty tibble when registry is empty", {
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  result <- eri_artifact_list()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true(all(c("name", "type", "description", "azure_path", "archived") %in% names(result)))
})

test_that("eri_artifact_list filters by type", {
  entries <- list(
    list(name = "a", type = "study_data",  description = "d1", version = NA_character_,
         azure_path = "p1", filename = "f1", file_format = "xlsx",
         uploaded_at = "t", uploaded_by = "u", archived = FALSE),
    list(name = "b", type = "spatial",     description = "d2", version = NA_character_,
         azure_path = "p2", filename = "f2", file_format = "shp",
         uploaded_at = "t", uploaded_by = "u", archived = FALSE)
  )

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = entries),
    .package = "erifunctions"
  )

  result <- eri_artifact_list(type = "study_data")
  expect_equal(nrow(result), 1L)
  expect_equal(result$name, "a")
})

test_that("eri_artifact_list excludes archived by default", {
  entries <- list(
    list(name = "active",   type = "reference", description = "d", version = NA_character_,
         azure_path = "p1", filename = "f1", file_format = "csv",
         uploaded_at = "t", uploaded_by = "u", archived = FALSE),
    list(name = "archived", type = "reference", description = "d", version = NA_character_,
         azure_path = "p2", filename = "f2", file_format = "csv",
         uploaded_at = "t", uploaded_by = "u", archived = TRUE)
  )

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = entries),
    .package = "erifunctions"
  )

  result <- eri_artifact_list()
  expect_equal(nrow(result), 1L)
  expect_equal(result$name, "active")

  result_all <- eri_artifact_list(include_archived = TRUE)
  expect_equal(nrow(result_all), 2L)
})

# --- eri_artifact_pull --------------------------------------------------------

test_that("eri_artifact_pull errors when artifact not found", {
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list()),
    .package = "erifunctions"
  )

  expect_error(eri_artifact_pull("nonexistent"), "not found")
})

test_that("eri_artifact_pull errors on archived artifact", {
  archived_entry <- list(
    name = "old", type = "reference", description = "d", version = NA_character_,
    azure_path = "p", filename = "f.csv", file_format = "csv",
    uploaded_at = "t", uploaded_by = "u", archived = TRUE
  )

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list(archived_entry)),
    .package = "erifunctions"
  )

  expect_error(eri_artifact_pull("old"), "archived")
})

test_that("eri_artifact_pull downloads file to dest", {
  entry <- list(
    name = "dr_irs_2024", type = "study_data", description = "d", version = NA_character_,
    azure_path = "artifacts/study_data/dr_irs_2024/dr_irs.xlsx",
    filename = "dr_irs.xlsx", file_format = "xlsx",
    uploaded_at = "t", uploaded_by = "u", archived = FALSE
  )

  tmp_dest   <- tempdir()
  downloaded <- character(0)

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_download = function(con, src, dest, ...) {
      downloaded <<- c(downloaded, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list(entry)),
    .package = "erifunctions"
  )

  result <- eri_artifact_pull("dr_irs_2024", dest = tmp_dest)
  expect_equal(result, file.path(tmp_dest, "dr_irs.xlsx"))
  expect_true(any(grepl("dr_irs.xlsx", downloaded)))
})

test_that("eri_artifact_pull records usage in research.yaml when present", {
  entry <- list(
    name = "dr_irs_2024", type = "study_data", description = "d", version = NA_character_,
    azure_path = "artifacts/study_data/dr_irs_2024/dr_irs.xlsx",
    filename = "dr_irs.xlsx", file_format = "xlsx",
    uploaded_at = "t", uploaded_by = "u", archived = FALSE
  )

  tmp_dir <- withr::local_tempdir()
  yaml_path <- file.path(tmp_dir, "research.yaml")
  yaml::write_yaml(list(project_name = "test_project", artifacts_used = list()), yaml_path)

  withr::with_dir(tmp_dir, {
    local_mocked_bindings(
      storage_file_exists = function(...) FALSE,
      storage_download    = function(...) invisible(NULL),
      .package = "AzureStor"
    )
    local_mocked_bindings(
      get_azure_storage_connection = function(...) "mock_con",
      .eri_artifact_registry_read  = function(...) list(entries = list(entry)),
      .package = "erifunctions"
    )

    eri_artifact_pull("dr_irs_2024", dest = tmp_dir)
  })

  updated <- yaml::read_yaml(yaml_path)
  expect_equal(length(updated$artifacts_used), 1L)
  expect_equal(updated$artifacts_used[[1L]]$name, "dr_irs_2024")
})

# --- eri_artifact_archive -----------------------------------------------------

test_that("eri_artifact_archive errors when artifact not found", {
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list()),
    .package = "erifunctions"
  )

  expect_error(eri_artifact_archive("nonexistent"), "not found")
})

test_that("eri_artifact_archive sets archived flag without deleting file", {
  entry <- list(
    name = "dr_irs_2024", type = "study_data", description = "d", version = NA_character_,
    azure_path = "p", filename = "f.xlsx", file_format = "xlsx",
    uploaded_at = "t", uploaded_by = "u", archived = FALSE
  )

  final_registry <- NULL

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_dir_exists  = function(...) TRUE,
    storage_upload      = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list(entry)),
    .eri_artifact_registry_write = function(registry, ...) {
      final_registry <<- registry
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  result <- eri_artifact_archive("dr_irs_2024")
  expect_null(result)
  expect_true(final_registry$entries[[1L]]$archived)
})

test_that("eri_artifact_archive is idempotent when already archived", {
  entry <- list(
    name = "old", type = "reference", description = "d", version = NA_character_,
    azure_path = "p", filename = "f.csv", file_format = "csv",
    uploaded_at = "t", uploaded_by = "u", archived = TRUE
  )

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_artifact_registry_read  = function(...) list(entries = list(entry)),
    .package = "erifunctions"
  )

  expect_no_error(eri_artifact_archive("old"))
})
