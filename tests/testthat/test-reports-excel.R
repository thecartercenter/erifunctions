#### eri_wb_create ####

test_that("eri_wb_create returns an openxlsx2 workbook", {
  skip_if_not_installed("openxlsx2")
  wb <- eri_wb_create("Test Report")
  expect_s3_class(wb, "wbWorkbook")
})

test_that("eri_wb_create works with no title", {
  skip_if_not_installed("openxlsx2")
  expect_s3_class(eri_wb_create(), "wbWorkbook")
})

#### eri_wb_add_sheet ####

test_that("eri_wb_add_sheet adds a worksheet", {
  skip_if_not_installed("openxlsx2")
  wb <- eri_wb_create()
  df <- tibble::tibble(country = c("DR", "Haiti"), n = c(10L, 20L))
  wb <- eri_wb_add_sheet(wb, "Cases", df)
  expect_true("Cases" %in% wb$get_sheet_names())
})

test_that("eri_wb_add_sheet with title adds worksheet", {
  skip_if_not_installed("openxlsx2")
  wb <- eri_wb_create()
  df <- tibble::tibble(x = 1:3)
  wb <- eri_wb_add_sheet(wb, "Data", df, title = "Annual data")
  expect_true("Data" %in% wb$get_sheet_names())
})

test_that("eri_wb_add_sheet handles single-row data", {
  skip_if_not_installed("openxlsx2")
  wb <- eri_wb_create()
  df <- tibble::tibble(country = "DR", n = 5L)
  expect_s3_class(eri_wb_add_sheet(wb, "Single", df), "wbWorkbook")
})

test_that("eri_wb_add_sheet handles empty data frame", {
  skip_if_not_installed("openxlsx2")
  wb <- eri_wb_create()
  df <- tibble::tibble(country = character(0), n = integer(0))
  expect_s3_class(eri_wb_add_sheet(wb, "Empty", df), "wbWorkbook")
})

#### eri_wb_save ####

test_that("eri_wb_save writes a file to disk", {
  skip_if_not_installed("openxlsx2")
  wb   <- eri_wb_create("Test")
  df   <- tibble::tibble(x = 1:3)
  wb   <- eri_wb_add_sheet(wb, "Data", df)
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  eri_wb_save(wb, path)
  expect_true(file.exists(path))
  expect_gt(file.size(path), 0L)
})

test_that("eri_wb_save creates parent directory if missing", {
  skip_if_not_installed("openxlsx2")
  wb  <- eri_wb_create()
  df  <- tibble::tibble(x = 1L)
  wb  <- eri_wb_add_sheet(wb, "S", df)
  dir <- file.path(tempdir(), paste0("eri_test_", sample.int(1e6, 1)))
  path <- file.path(dir, "out.xlsx")
  withr::defer(unlink(dir, recursive = TRUE))
  eri_wb_save(wb, path)
  expect_true(file.exists(path))
})

#### eri_report_excel ####

test_that("eri_report_excel writes a multi-sheet xlsx", {
  skip_if_not_installed("openxlsx2")
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  eri_report_excel(
    sheets = list(
      "Summary" = tibble::tibble(country = c("DR", "Haiti"), n = c(10L, 20L)),
      "Detail"  = tibble::tibble(province = "Santo Domingo", n = 5L)
    ),
    path  = path,
    title = "Test Report"
  )
  expect_true(file.exists(path))
  wb2 <- openxlsx2::wb_load(path)
  expect_true("Summary" %in% wb2$get_sheet_names())
  expect_true("Detail"  %in% wb2$get_sheet_names())
})

test_that("eri_report_excel errors on unnamed sheets", {
  skip_if_not_installed("openxlsx2")
  expect_error(
    eri_report_excel(list(tibble::tibble(x = 1)), tempfile(fileext = ".xlsx")),
    "named list"
  )
})

test_that("eri_report_excel errors on empty sheets list", {
  skip_if_not_installed("openxlsx2")
  expect_error(eri_report_excel(list(), tempfile(fileext = ".xlsx")), "at least one")
})

test_that("eri_report_excel errors when a sheet element is not a data frame", {
  skip_if_not_installed("openxlsx2")
  expect_error(
    eri_report_excel(list(A = "not a df"), tempfile(fileext = ".xlsx")),
    "data frame"
  )
})
