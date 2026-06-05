#### Tests for eri_research_pull ####

.base_manifest <- function(tmp) {
  list(
    project_name   = "test_proj",
    country        = "dr",
    disease        = "malaria",
    description    = "test",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = "research/test_proj/",
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list()
  )
}

.write_manifest <- function(tmp, manifest = NULL) {
  if (is.null(manifest)) manifest <- .base_manifest(tmp)
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))
}

# --- argument validation ------------------------------------------------------

test_that("eri_research_pull errors when no canonical args or path supplied", {
  expect_error(eri_research_pull(), "Supply either")
})

test_that("eri_research_pull errors when both canonical args and path supplied", {
  expect_error(
    eri_research_pull(country = "dr", disease = "malaria", data_type = "surveillance",
                      path = "spatial/foo"),
    "not both"
  )
})

test_that("eri_research_pull errors when only some canonical args supplied", {
  expect_error(eri_research_pull(country = "dr", disease = "malaria"), "Supply either")
})

# --- canonical pull -----------------------------------------------------------

test_that("eri_research_pull by canonical args resolves processed path and downloads files", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "data"))
  .write_manifest(tmp)

  downloaded <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(con, path, ...) {
      c("dr/malaria/surveillance/processed/2024_W01.parquet",
        "dr/malaria/surveillance/processed/2024_W02.parquet")
    },
    storage_download = function(con, src, dest, ...) {
      downloaded <<- c(downloaded, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    result <- eri_research_pull(
      country   = "dr",
      disease   = "malaria",
      data_type = "surveillance",
      dest      = file.path(tmp, "data")
    )
  })

  expect_equal(length(result), 2L)
  expect_true(any(grepl("2024_W01.parquet", downloaded)))
  expect_true(any(grepl("2024_W02.parquet", downloaded)))
})

test_that("eri_research_pull records pull in research.yaml", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "data"))
  .write_manifest(tmp)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) {
      c("dr/malaria/surveillance/processed/2024_W01.parquet")
    },
    storage_download = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    eri_research_pull(
      country   = "dr",
      disease   = "malaria",
      data_type = "surveillance",
      dest      = file.path(tmp, "data")
    )
  })

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$pulled_data), 1L)
  expect_equal(updated$pulled_data[[1L]]$azure_path, "dr/malaria/surveillance/processed")
  expect_true(nchar(updated$pulled_data[[1L]]$pulled_at) > 0L)
})

# --- path-based pull ----------------------------------------------------------

test_that("eri_research_pull by path downloads from explicit Azure path", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "data"))
  .write_manifest(tmp)

  pulled_from <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(con, path, ...) {
      pulled_from <<- path
      c("spatial/dom_admin_boundaries/adm0.shp",
        "spatial/dom_admin_boundaries/adm1.shp")
    },
    storage_download = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    result <- eri_research_pull(
      path = "spatial/dom_admin_boundaries",
      dest = file.path(tmp, "data")
    )
  })

  expect_equal(pulled_from, "spatial/dom_admin_boundaries")
  expect_equal(length(result), 2L)
})

test_that("eri_research_pull records path-based pull in research.yaml", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "data"))
  .write_manifest(tmp)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) c("spatial/dom_admin_boundaries/adm0.shp"),
    storage_download   = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    eri_research_pull(path = "spatial/dom_admin_boundaries", dest = file.path(tmp, "data"))
  })

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(updated$pulled_data[[1L]]$azure_path, "spatial/dom_admin_boundaries")
})

# --- appending to existing pulled_data ----------------------------------------

test_that("eri_research_pull appends when research.yaml has existing pulled_data", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "data"))

  existing_pull <- list(
    azure_path = "dr/malaria/surveillance/processed",
    files      = list("2024_W01.parquet"),
    local_dest = file.path(tmp, "data"),
    pulled_at  = "2026-06-01T00:00:00Z"
  )
  manifest <- .base_manifest(tmp)
  manifest$pulled_data <- list(existing_pull)
  .write_manifest(tmp, manifest)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) c("dr/malaria/cmr/processed/2024_05.parquet"),
    storage_download   = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    eri_research_pull(country = "dr", disease = "malaria", data_type = "cmr",
                      dest = file.path(tmp, "data"))
  })

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$pulled_data), 2L)
})

# --- no files at path ---------------------------------------------------------

test_that("eri_research_pull warns and returns empty when no files found", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) character(0L),
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    expect_warning(
      result <- eri_research_pull(path = "spatial/nonexistent"),
      "No files found"
    )
    expect_equal(length(result), 0L)
  })
})

# --- no research.yaml present -------------------------------------------------

test_that("eri_research_pull succeeds without research.yaml (no provenance written)", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) c("spatial/foo/bar.shp"),
    storage_download   = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  withr::with_dir(tmp, {
    expect_no_error(
      eri_research_pull(path = "spatial/foo", dest = file.path(tmp, "data"))
    )
  })

  expect_false(file.exists(file.path(tmp, "research.yaml")))
})
