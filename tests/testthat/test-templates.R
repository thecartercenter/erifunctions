#### Tests for inst/templates ####

test_that("eri_daily_workflow.qmd template is installed and non-empty", {
  path <- system.file("templates/eri_daily_workflow.qmd", package = "erifunctions")
  expect_gt(nchar(path), 0L)
  expect_true(file.exists(path), label = "template file exists on disk")
  lines <- readLines(path, warn = FALSE)
  expect_gt(length(lines), 10L)
})

test_that("eri_daily_workflow.qmd template contains required sections", {
  path <- system.file("templates/eri_daily_workflow.qmd", package = "erifunctions")
  skip_if(nchar(path) == 0, "template not installed")
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(content, "eri_survey_status")
  expect_match(content, "eri_odk_sync")
  expect_match(content, "eri_approve")
  expect_match(content, "get_azure_storage_connection")
  expect_match(content, "init_odk_connection")
})

#### eri_template_list / pull / upload ########################################

# --- eri_template_list --------------------------------------------------------

test_that("eri_template_list returns bundled templates when data_con = NA", {
  result <- eri_template_list(data_con = NA)
  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) >= 1L)
  expect_true(all(c("name", "description", "source", "filename") %in% names(result)))
  expect_true(all(result$source == "bundled"))
  expect_true("eri_daily_workflow" %in% result$name)
})

test_that("eri_template_list combines bundled and Azure templates", {
  azure_entry <- list(
    name        = "eri_research_workflow",
    description = "Research workflow",
    source      = "azure",
    filename    = "eri_research_workflow.qmd",
    uploaded_at = "2026-06-04T00:00:00Z",
    uploaded_by = "test.user"
  )

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download    = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_template_registry_read = function(...) list(entries = list(azure_entry)),
    .package = "erifunctions"
  )

  result <- eri_template_list()
  expect_true("eri_daily_workflow" %in% result$name)
  expect_true("eri_research_workflow" %in% result$name)
  expect_true(any(result$source == "azure"))
  expect_true(any(result$source == "bundled"))
})

test_that("eri_template_list falls back to bundled on Azure error", {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) stop("no connection"),
    .package = "erifunctions"
  )

  expect_warning(result <- eri_template_list(), "bundled")
  expect_true(nrow(result) >= 1L)
  expect_true(all(result$source == "bundled"))
})

test_that("eri_template_list returns typed empty tibble when no templates found", {
  local_mocked_bindings(
    .eri_template_bundled        = function() list(),
    .eri_template_registry_read  = function(...) list(entries = list()),
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )

  result <- eri_template_list()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

# --- eri_template_pull --------------------------------------------------------

test_that("eri_template_pull copies bundled template to dest", {
  tmp    <- withr::local_tempdir()
  result <- eri_template_pull("eri_daily_workflow", dest = tmp)
  expect_true(file.exists(result))
  expect_equal(basename(result), "eri_daily_workflow.qmd")
  expect_true(file.exists(file.path(tmp, "eri_daily_workflow.qmd")))
})

test_that("eri_template_pull errors with informative message on unknown name", {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )

  expect_error(eri_template_pull("nonexistent_template"), "not found")
})

test_that("eri_template_pull downloads Azure template to dest", {
  tmp <- withr::local_tempdir()

  azure_entry <- list(
    name = "custom_workflow", description = "Custom", source = "azure",
    filename = "custom_workflow.qmd", uploaded_at = "t", uploaded_by = "u"
  )
  downloaded_from <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(con, src, dest, ...) {
      downloaded_from <<- c(downloaded_from, src)
      writeLines("template content", dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_template_registry_read = function(...) list(entries = list(azure_entry)),
    .package = "erifunctions"
  )

  result <- eri_template_pull("custom_workflow", dest = tmp)
  expect_true(any(grepl("custom_workflow.qmd", downloaded_from)))
  expect_true(file.exists(result))
})

# --- eri_template_upload ------------------------------------------------------

test_that("eri_template_upload errors when file not found", {
  expect_error(
    eri_template_upload("/nonexistent/tmpl.qmd", "x", "desc"),
    "not found"
  )
})

test_that("eri_template_upload errors on unsupported file extension", {
  tmp <- tempfile(fileext = ".txt")
  writeLines("x", tmp)
  withr::defer(unlink(tmp))
  expect_error(eri_template_upload(tmp, "x", "desc"), "supported")
})

test_that("eri_template_upload errors on name collision with bundled template", {
  tmp <- tempfile(fileext = ".qmd")
  writeLines("x", tmp)
  withr::defer(unlink(tmp))
  expect_error(
    eri_template_upload(tmp, "eri_daily_workflow", "desc"),
    "conflicts with a bundled"
  )
})

test_that("eri_template_upload uploads file and registers in Azure", {
  tmp <- tempfile(fileext = ".qmd")
  writeLines("---\ntitle: test\n---", tmp)
  withr::defer(unlink(tmp))

  uploaded_to    <- character(0)
  final_registry <- NULL

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_dir_exists  = function(...) TRUE,
    create_storage_dir  = function(...) invisible(NULL),
    storage_upload      = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    storage_download    = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_template_registry_read  = function(...) list(entries = list()),
    .eri_template_registry_write = function(registry, ...) {
      final_registry <<- registry
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  result <- eri_template_upload(tmp, "my_custom_workflow", "My workflow")

  expect_match(result, "templates/")
  expect_true(any(grepl(basename(tmp), uploaded_to)))
  expect_false(is.null(final_registry))
  expect_equal(final_registry$entries[[1L]]$name,   "my_custom_workflow")
  expect_equal(final_registry$entries[[1L]]$source, "azure")
})

test_that("eri_template_upload upserts existing entry by name", {
  tmp <- tempfile(fileext = ".qmd")
  writeLines("x", tmp)
  withr::defer(unlink(tmp))

  existing <- list(
    name = "my_workflow", description = "old", source = "azure",
    filename = "my_workflow.qmd", uploaded_at = "t", uploaded_by = "u"
  )
  final_registry <- NULL

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_dir_exists  = function(...) TRUE,
    create_storage_dir  = function(...) invisible(NULL),
    storage_upload      = function(...) invisible(NULL),
    storage_download    = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_template_registry_read  = function(...) list(entries = list(existing)),
    .eri_template_registry_write = function(registry, ...) {
      final_registry <<- registry
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  eri_template_upload(tmp, "my_workflow", "updated desc")
  expect_equal(length(final_registry$entries), 1L)
  expect_equal(final_registry$entries[[1L]]$description, "updated desc")
})
