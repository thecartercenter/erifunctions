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
