#### SharePoint integration tests ####
# All tests skip when Microsoft365R is not installed.

#### eri_sharepoint_connect ####

test_that("eri_sharepoint_connect errors clearly when Microsoft365R is absent", {
  skip_if(requireNamespace("Microsoft365R", quietly = TRUE), "Microsoft365R is installed")
  expect_error(
    eri_sharepoint_connect("https://example.sharepoint.com/sites/ERI"),
    "Microsoft365R"
  )
})

test_that("eri_sharepoint_connect errors on connection failure", {
  skip_if_not_installed("Microsoft365R")
  local_mocked_bindings(
    get_sharepoint_site = function(...) stop("auth failed"),
    .package = "Microsoft365R"
  )
  expect_error(
    eri_sharepoint_connect("https://example.sharepoint.com/sites/ERI"),
    "auth failed"
  )
})

#### eri_sharepoint_list ####

test_that("eri_sharepoint_list errors clearly when Microsoft365R is absent", {
  skip_if(requireNamespace("Microsoft365R", quietly = TRUE), "Microsoft365R is installed")
  expect_error(eri_sharepoint_list(NULL), "Microsoft365R")
})

test_that("eri_sharepoint_list returns an empty tibble when folder is empty", {
  skip_if_not_installed("Microsoft365R")

  mock_folder <- list(
    list_items = function() list()
  )
  mock_drive <- list(
    get_root = function() mock_folder
  )
  mock_site <- list(
    get_drive = function() mock_drive
  )

  result <- eri_sharepoint_list(mock_site)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true(all(c("name", "size", "modified", "is_folder", "path") %in% names(result)))
})

test_that("eri_sharepoint_list returns correct tibble structure for items", {
  skip_if_not_installed("Microsoft365R")

  make_item <- function(name, size, is_folder = FALSE) {
    props <- list(
      name                  = name,
      size                  = size,
      lastModifiedDateTime  = "2024-06-01T12:00:00Z",
      folder                = if (is_folder) list() else NULL
    )
    list(properties = props)
  }

  mock_folder <- list(
    list_items = function() list(
      make_item("report.xlsx", 1024L, FALSE),
      make_item("archive",     0L,    TRUE)
    )
  )
  mock_drive <- list(
    get_item = function(...) mock_folder
  )
  mock_site <- list(
    get_drive = function() mock_drive
  )

  result <- eri_sharepoint_list(mock_site, "Shared Documents/Reports")
  expect_equal(nrow(result), 2L)
  expect_equal(result$name, c("report.xlsx", "archive"))
  expect_equal(result$is_folder, c(FALSE, TRUE))
})

#### eri_sharepoint_read ####

test_that("eri_sharepoint_read errors clearly when Microsoft365R is absent", {
  skip_if(requireNamespace("Microsoft365R", quietly = TRUE), "Microsoft365R is installed")
  expect_error(eri_sharepoint_read(NULL, "file.csv"), "Microsoft365R")
})

test_that("eri_sharepoint_read reads a CSV from a mocked SharePoint item", {
  skip_if_not_installed("Microsoft365R")

  tmp_csv <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,x\n2,y", tmp_csv)
  withr::defer(unlink(tmp_csv))

  mock_item <- list(
    download = function(dest, overwrite = TRUE) file.copy(tmp_csv, dest, overwrite = TRUE)
  )
  mock_drive <- list(
    get_item = function(...) mock_item
  )
  mock_site <- list(
    get_drive = function() mock_drive
  )

  result <- eri_sharepoint_read(mock_site, "Shared Documents/data.csv")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2L)
  expect_true("a" %in% names(result))
})

test_that("eri_sharepoint_read returns temp path for unknown extension", {
  skip_if_not_installed("Microsoft365R")

  tmp_bin <- tempfile(fileext = ".bin")
  writeBin(as.raw(1:10), tmp_bin)
  withr::defer(unlink(tmp_bin))

  mock_item <- list(
    download = function(dest, overwrite = TRUE) file.copy(tmp_bin, dest, overwrite = TRUE)
  )
  mock_drive <- list(
    get_item = function(...) mock_item
  )
  mock_site <- list(
    get_drive = function() mock_drive
  )

  result <- suppressMessages(eri_sharepoint_read(mock_site, "Shared Documents/data.bin"))
  expect_type(result, "character")
  expect_true(grepl("\\.bin$", result))
})

#### eri_sharepoint_upload ####

test_that("eri_sharepoint_upload errors clearly when Microsoft365R is absent", {
  skip_if(requireNamespace("Microsoft365R", quietly = TRUE), "Microsoft365R is installed")
  expect_error(eri_sharepoint_upload("file.csv", NULL, "Shared Documents"), "Microsoft365R")
})

test_that("eri_sharepoint_upload errors when local file does not exist", {
  skip_if_not_installed("Microsoft365R")
  expect_error(
    eri_sharepoint_upload("/nonexistent/path/file.xlsx", list(), "Shared Documents"),
    "not found"
  )
})

test_that("eri_sharepoint_upload calls folder$upload with the local path", {
  skip_if_not_installed("Microsoft365R")

  tmp_file <- tempfile(fileext = ".csv")
  writeLines("x,y\n1,2", tmp_file)
  withr::defer(unlink(tmp_file))

  uploaded <- NULL
  mock_folder <- list(
    upload    = function(path) { uploaded <<- path; list(properties = list(webUrl = "https://sp/file.csv")) },
    get_item  = function(...) stop("not found")
  )
  mock_drive <- list(
    get_item = function(...) mock_folder
  )
  mock_site <- list(
    get_drive = function() mock_drive
  )

  result <- suppressMessages(eri_sharepoint_upload(tmp_file, mock_site, "Shared Documents"))
  expect_equal(uploaded, tmp_file)
  expect_equal(result, "https://sp/file.csv")
})

test_that("eri_sharepoint_upload errors when overwrite = FALSE and file exists", {
  skip_if_not_installed("Microsoft365R")

  tmp_file <- tempfile(fileext = ".csv")
  writeLines("x,y\n1,2", tmp_file)
  withr::defer(unlink(tmp_file))

  mock_folder <- list(
    get_item = function(...) list(properties = list(name = basename(tmp_file))),
    upload   = function(path) list(properties = list(webUrl = "https://sp/file.csv"))
  )
  mock_drive <- list(
    get_item = function(...) mock_folder
  )
  mock_site <- list(
    get_drive = function() mock_drive
  )

  expect_error(
    eri_sharepoint_upload(tmp_file, mock_site, "Shared Documents", overwrite = FALSE),
    "already exists"
  )
})
