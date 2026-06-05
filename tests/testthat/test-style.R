#### Tests for style.R ####

#### eri_color_scheme ####

test_that("eri_color_scheme returns named character vector for each type", {
  types <- c("malaria.incidence", "lf.status", "oncho.status", "activities", "dq.flag")
  for (type in types) {
    result <- eri_color_scheme(type)
    expect_type(result, "character")
    expect_true(!is.null(names(result)))
    expect_true(length(result) >= 2L)
  }
})

test_that("eri_color_scheme malaria.incidence has 4 levels", {
  result <- eri_color_scheme("malaria.incidence")
  expect_equal(length(result), 4L)
  expect_true(all(c("0", "<1", "1-10", ">=10") %in% names(result)))
})

test_that("eri_color_scheme lf.status has 5 levels", {
  result <- eri_color_scheme("lf.status")
  expect_equal(length(result), 5L)
  expect_true("Non-endemic" %in% names(result))
  expect_true("PTS (Passed TAS-3)" %in% names(result))
})

test_that("eri_color_scheme oncho.status has 5 levels", {
  result <- eri_color_scheme("oncho.status")
  expect_equal(length(result), 5L)
  expect_true("Verified free of transmission" %in% names(result))
})

test_that("eri_color_scheme activities has Completed and Not completed", {
  result <- eri_color_scheme("activities")
  expect_setequal(names(result), c("Completed", "Not completed"))
})

test_that("eri_color_scheme dq.flag has 3 levels", {
  result <- eri_color_scheme("dq.flag")
  expect_equal(length(result), 3L)
  expect_setequal(names(result), c("pass", "warning", "fail"))
})

test_that("eri_color_scheme errors with informative message for unknown type", {
  expect_error(eri_color_scheme("unknown.type"), "Unknown colour scheme")
  expect_error(eri_color_scheme("unknown.type"), "malaria.incidence")
})

#### eri_plot_theme ####

test_that("eri_plot_theme returns a theme object for each type", {
  for (type in c("map", "epicurve", "map.inset")) {
    result <- eri_plot_theme(type)
    expect_s3_class(result, "theme")
  }
})

test_that("eri_plot_theme errors on unknown type", {
  expect_error(eri_plot_theme("unknown"), "Unknown theme type")
  expect_error(eri_plot_theme("unknown"), "map")
})

test_that("eri_plot_theme can be added to a ggplot", {
  p <- ggplot2::ggplot() + eri_plot_theme("map")
  expect_s3_class(p, "gg")
  p2 <- ggplot2::ggplot() + eri_plot_theme("epicurve")
  expect_s3_class(p2, "gg")
})
