#### eri_pptx_create ####

test_that("eri_pptx_create returns an rpptx object using bundled template", {
  skip_if_not_installed("officer")
  pptx <- eri_pptx_create()
  expect_s3_class(pptx, "rpptx")
})

test_that("eri_pptx_create errors on missing custom template", {
  skip_if_not_installed("officer")
  expect_error(eri_pptx_create("/nonexistent/template.pptx"), "not found")
})

#### eri_pptx_add_title ####

test_that("eri_pptx_add_title returns rpptx with one more slide", {
  skip_if_not_installed("officer")
  pptx <- eri_pptx_create()
  n0   <- length(pptx)
  pptx <- eri_pptx_add_title(pptx, "Test Title", subtitle = "Test Subtitle")
  expect_equal(length(pptx), n0 + 1L)
})

test_that("eri_pptx_add_title works without subtitle", {
  skip_if_not_installed("officer")
  pptx <- eri_pptx_create()
  expect_s3_class(eri_pptx_add_title(pptx, "Title Only"), "rpptx")
})

#### eri_pptx_add_section ####

test_that("eri_pptx_add_section adds a slide", {
  skip_if_not_installed("officer")
  pptx <- eri_pptx_create()
  n0   <- length(pptx)
  pptx <- eri_pptx_add_section(pptx, "Section 1")
  expect_equal(length(pptx), n0 + 1L)
})

#### eri_pptx_add_table ####

test_that("eri_pptx_add_table adds a slide", {
  skip_if_not_installed("officer")
  skip_if_not_installed("flextable")
  pptx <- eri_pptx_create()
  n0   <- length(pptx)
  df   <- tibble::tibble(country = c("DR", "Haiti"), n = c(10L, 20L))
  pptx <- eri_pptx_add_table(pptx, df, title = "Case counts")
  expect_equal(length(pptx), n0 + 1L)
})

test_that("eri_pptx_add_table works without title", {
  skip_if_not_installed("officer")
  skip_if_not_installed("flextable")
  pptx <- eri_pptx_create()
  df   <- tibble::tibble(x = 1:3)
  expect_s3_class(eri_pptx_add_table(pptx, df), "rpptx")
})

#### eri_pptx_add_plot ####

test_that("eri_pptx_add_plot adds a slide", {
  skip_if_not_installed("officer")
  skip_if_not_installed("ggplot2")
  pptx <- eri_pptx_create()
  n0   <- length(pptx)
  p    <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  pptx <- eri_pptx_add_plot(pptx, p, title = "Figure 1")
  expect_equal(length(pptx), n0 + 1L)
})

#### eri_pptx_save ####

test_that("eri_pptx_save writes a pptx file to disk", {
  skip_if_not_installed("officer")
  skip_if_not_installed("flextable")
  path <- tempfile(fileext = ".pptx")
  withr::defer(unlink(path))
  pptx <- eri_pptx_create() |>
    eri_pptx_add_title("Test Report", subtitle = "2024") |>
    eri_pptx_add_table(tibble::tibble(a = 1:2, b = 3:4))
  eri_pptx_save(pptx, path)
  expect_true(file.exists(path))
  expect_gt(file.size(path), 0L)
})

test_that("eri_pptx_save creates parent directory if needed", {
  skip_if_not_installed("officer")
  dir  <- file.path(tempdir(), paste0("eri_pptx_", sample.int(1e6, 1)))
  path <- file.path(dir, "report.pptx")
  withr::defer(unlink(dir, recursive = TRUE))
  pptx <- eri_pptx_create()
  eri_pptx_save(pptx, path)
  expect_true(file.exists(path))
})

#### Full pipeline ####

test_that("full PPTX pipeline: create -> title -> section -> table -> plot -> save", {
  skip_if_not_installed("officer")
  skip_if_not_installed("flextable")
  skip_if_not_installed("ggplot2")
  path <- tempfile(fileext = ".pptx")
  withr::defer(unlink(path))
  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) +
    ggplot2::geom_line()
  pptx <- eri_pptx_create() |>
    eri_pptx_add_title("Hispaniola Malaria 2024") |>
    eri_pptx_add_section("Results") |>
    eri_pptx_add_table(tibble::tibble(country = c("DR", "HT"), n = c(100L, 200L))) |>
    eri_pptx_add_plot(p, title = "Epidemic Curve")
  eri_pptx_save(pptx, path)
  expect_true(file.exists(path))
  pptx2 <- officer::read_pptx(path)
  expect_gte(length(pptx2), 4L)
})
