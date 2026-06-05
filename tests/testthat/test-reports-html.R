#### eri_report_qmd_template ####

test_that("eri_report_qmd_template copies bundled qmd to destination", {
  path <- tempfile(fileext = ".qmd")
  withr::defer(unlink(path))
  result <- eri_report_qmd_template(path)
  expect_true(file.exists(path))
  expect_equal(result, path)
  content <- readLines(path, warn = FALSE)
  expect_true(any(grepl("self-contained", content)))
})

test_that("eri_report_qmd_template errors if file exists without overwrite", {
  path <- tempfile(fileext = ".qmd")
  file.create(path)
  withr::defer(unlink(path))
  expect_error(eri_report_qmd_template(path), "already exists")
})

test_that("eri_report_qmd_template overwrites when overwrite = TRUE", {
  path <- tempfile(fileext = ".qmd")
  writeLines("old content", path)
  withr::defer(unlink(path))
  eri_report_qmd_template(path, overwrite = TRUE)
  content <- readLines(path, warn = FALSE)
  expect_true(any(grepl("self-contained", content)))
})

#### eri_report_html input validation ####

test_that("eri_report_html errors when quarto not installed", {
  skip_if(requireNamespace("quarto", quietly = TRUE), "quarto is installed")
  expect_error(
    eri_report_html(list(), tempfile(fileext = ".html"), title = "T"),
    "quarto"
  )
})

test_that("eri_report_html errors on non-list sections", {
  skip_if_not_installed("quarto")
  expect_error(
    eri_report_html("not a list", tempfile(fileext = ".html")),
    "list"
  )
})

#### .eri_serialise_sections ####

test_that(".eri_serialise_sections preserves heading and text", {
  sections <- list(
    s1 = list(heading = "Overview", text = "Some text here.")
  )
  result <- erifunctions:::.eri_serialise_sections(sections)
  expect_equal(result$s1$heading, "Overview")
  expect_equal(result$s1$text, "Some text here.")
})

test_that(".eri_serialise_sections converts table to HTML", {
  skip_if_not_installed("flextable")
  skip_if_not(
    requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available(),
    "pandoc not available"
  )
  sections <- list(
    s1 = list(
      heading = "Table",
      table   = tibble::tibble(country = c("DR", "Haiti"), n = c(10L, 20L))
    )
  )
  result <- erifunctions:::.eri_serialise_sections(sections)
  expect_true(!is.null(result$s1$table_html))
  expect_true(nchar(result$s1$table_html) > 0L)
  expect_true(grepl("<table|<TABLE", result$s1$table_html))
})

test_that(".eri_serialise_sections converts ggplot to base64 PNG", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("base64enc")
  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3),
                       ggplot2::aes(x, y)) + ggplot2::geom_point()
  sections <- list(s1 = list(heading = "Fig", figure = p))
  result <- erifunctions:::.eri_serialise_sections(sections)
  expect_true(!is.null(result$s1$figure_b64))
  expect_true(grepl("^data:image/png;base64,", result$s1$figure_b64))
})

test_that(".eri_serialise_sections handles section with no table or figure", {
  sections <- list(s1 = list(heading = "H", text = "T"))
  result <- erifunctions:::.eri_serialise_sections(sections)
  expect_null(result$s1$table_html)
  expect_null(result$s1$figure_b64)
})
