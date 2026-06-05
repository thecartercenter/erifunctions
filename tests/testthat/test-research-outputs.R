#### Tests for research output management ####

.base_manifest <- function(project_name = "test_proj") {
  list(
    project_name   = project_name,
    country        = "dr",
    disease        = "malaria",
    description    = "test",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = paste0("research/", project_name, "/"),
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list()
  )
}

.write_manifest <- function(tmp, project_name = "test_proj") {
  yaml::write_yaml(.base_manifest(project_name), file.path(tmp, "research.yaml"))
}

# --- eri_research_upload_figure -----------------------------------------------

test_that("eri_research_upload_figure errors when file not found", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  expect_error(
    eri_research_upload_figure("/nonexistent/fig.png", path = tmp),
    "not found"
  )
})

test_that("eri_research_upload_figure errors when research.yaml absent", {
  tmp <- withr::local_tempdir()
  fig <- tempfile(tmpdir = tmp, fileext = ".png")
  writeLines("x", fig)
  expect_error(
    eri_research_upload_figure(fig, path = tmp),
    "research.yaml"
  )
})

test_that("eri_research_upload_figure uploads file and records in research.yaml", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  fig <- file.path(tmp, "its_model.png")
  writeLines("png_data", fig)

  uploaded_to <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  result <- eri_research_upload_figure(fig, caption = "ITS model", path = tmp)

  expect_match(result, "outputs/figs/its_model.png")
  expect_true(any(grepl("its_model.png", uploaded_to)))

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$outputs), 1L)
  expect_equal(updated$outputs[[1L]]$type,     "figure")
  expect_equal(updated$outputs[[1L]]$filename,  "its_model.png")
  expect_equal(updated$outputs[[1L]]$caption,   "ITS model")
  expect_true(nchar(updated$outputs[[1L]]$uploaded_at) > 0L)
})

test_that("eri_research_upload_figure stores NA caption when none supplied", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  fig <- file.path(tmp, "fig.png")
  writeLines("x", fig)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_upload_figure(fig, path = tmp)
  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_true(is.na(updated$outputs[[1L]]$caption))
})

# --- eri_research_upload_output -----------------------------------------------

test_that("eri_research_upload_output errors when research.yaml absent", {
  tmp <- withr::local_tempdir()
  expect_error(
    eri_research_upload_output(list(a = 1), "model.qs2", path = tmp),
    "research.yaml"
  )
})

test_that("eri_research_upload_output serializes and uploads R object", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)

  uploaded_to <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  result <- eri_research_upload_output(list(coef = 1.5), "its_model.qs2", path = tmp)

  expect_match(result, "outputs/its_model.qs2")
  expect_true(any(grepl("its_model.qs2", uploaded_to)))

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$outputs), 1L)
  expect_equal(updated$outputs[[1L]]$type,    "object")
  expect_equal(updated$outputs[[1L]]$filename, "its_model.qs2")
})

test_that("eri_research_upload_output appends to existing outputs", {
  tmp <- withr::local_tempdir()
  manifest <- .base_manifest()
  manifest$outputs <- list(
    list(type = "figure", filename = "fig.png",
         azure_path = "research/test_proj/outputs/figs/fig.png",
         caption = NA, uploaded_at = "t", uploaded_by = "u")
  )
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_upload_output(list(x = 1), "model.qs2", path = tmp)

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$outputs), 2L)
})

# --- eri_research_snapshot ----------------------------------------------------

test_that("eri_research_snapshot errors when research.yaml absent", {
  tmp <- withr::local_tempdir()
  expect_error(eri_research_snapshot(path = tmp), "research.yaml")
})

test_that("eri_research_snapshot errors when data/ directory absent", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  expect_error(eri_research_snapshot(path = tmp), "data/")
})

test_that("eri_research_snapshot warns and returns NULL when data/ is empty", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  dir.create(file.path(tmp, "data"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  expect_warning(
    result <- eri_research_snapshot(path = tmp),
    "empty"
  )
  expect_null(result)
})

test_that("eri_research_snapshot uploads data/ contents and records in research.yaml", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  data_dir <- file.path(tmp, "data")
  dir.create(data_dir)
  writeLines("row1,row2", file.path(data_dir, "surveillance.parquet"))
  writeLines("row1,row2", file.path(data_dir, "cmr.parquet"))

  uploaded_to <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_upload = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  result <- eri_research_snapshot(label = "pre-ITS-run", path = tmp)

  expect_match(result, "research/test_proj/snapshots/")
  # data files + _manifest.yaml
  expect_true(any(grepl("surveillance.parquet", uploaded_to)))
  expect_true(any(grepl("cmr.parquet", uploaded_to)))
  expect_true(any(grepl("_manifest.yaml", uploaded_to)))

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$snapshots), 1L)
  expect_equal(updated$snapshots[[1L]]$label,      "pre-ITS-run")
  expect_equal(updated$snapshots[[1L]]$file_count,  2L)
  expect_true(nchar(updated$snapshots[[1L]]$azure_path) > 0L)
})

test_that("eri_research_snapshot stores NA label when none supplied", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  data_dir <- file.path(tmp, "data")
  dir.create(data_dir)
  writeLines("x", file.path(data_dir, "file.csv"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_upload = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_snapshot(path = tmp)
  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_true(is.na(updated$snapshots[[1L]]$label))
})
