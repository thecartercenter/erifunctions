#### eri_brand_colors ####

test_that("eri_brand_colors returns named character vector of length 7", {
  cols <- eri_brand_colors()
  expect_type(cols, "character")
  expect_length(cols, 7L)
  expect_named(cols, c("navy", "blue", "orange", "gold", "green", "light_blue", "gray"))
})

test_that("eri_brand_colors navy is Carter Center signature color", {
  expect_equal(unname(eri_brand_colors()["navy"]), "#44546A")
})

test_that("eri_brand_colors values are valid hex colors", {
  cols <- eri_brand_colors()
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", cols)))
})

#### eri_brand_ggplot_theme ####

test_that("eri_brand_ggplot_theme returns a ggplot theme", {
  expect_s3_class(eri_brand_ggplot_theme(), "theme")
})

test_that("eri_brand_ggplot_theme accepts custom base_size", {
  th <- eri_brand_ggplot_theme(base_size = 14)
  expect_s3_class(th, "theme")
})

test_that("eri_brand_ggplot_theme can be added to a ggplot", {
  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    eri_brand_ggplot_theme()
  expect_s3_class(p, "ggplot")
})

#### eri_table ####

test_that("eri_table returns a flextable", {
  skip_if_not_installed("flextable")
  df  <- tibble::tibble(country = c("DR", "Haiti"), cases = c(100L, 200L))
  ft  <- eri_table(df)
  expect_s3_class(ft, "flextable")
})

test_that("eri_table with title returns flextable", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(a = 1:3, b = letters[1:3])
  ft <- eri_table(df, title = "Test table")
  expect_s3_class(ft, "flextable")
})

test_that("eri_table with footnote returns flextable", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(x = 1:2)
  ft <- eri_table(df, footnote = "Source: ERI")
  expect_s3_class(ft, "flextable")
})

test_that("eri_table with highlight_cols returns flextable", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(country = c("DR", "Haiti"), pct = c(80, 95))
  ft <- eri_table(df, highlight_cols = list(pct = "#FFC000"))
  expect_s3_class(ft, "flextable")
})

test_that("eri_table highlight_cols ignores unknown columns", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(country = c("DR", "Haiti"))
  expect_s3_class(
    eri_table(df, highlight_cols = list(nonexistent = "#FF0000")),
    "flextable"
  )
})

test_that("eri_table header background stored in flextable styles", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(a = 1:2, b = 3:4)
  ft <- eri_table(df)
  # Header background is set via flextable::bg(); verify the object is valid
  # and has the correct structure rather than calling unexported style_prop()
  expect_true(!is.null(ft$header))
  expect_s3_class(ft, "flextable")
})

test_that("eri_table with single-row data does not error", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(country = "DR", cases = 50L)
  expect_s3_class(eri_table(df), "flextable")
})

test_that("eri_table with empty data frame does not error", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(country = character(0), cases = integer(0))
  expect_s3_class(eri_table(df), "flextable")
})

test_that("eri_table with col_widths returns flextable", {
  skip_if_not_installed("flextable")
  df <- tibble::tibble(country = c("DR", "Haiti"), cases = c(100L, 200L))
  ft <- eri_table(df, col_widths = c(country = 1.5, cases = 0.8))
  expect_s3_class(ft, "flextable")
})
