#### Tests for epi.R ####

#### eri_incidence_rate ####

test_that("eri_incidence_rate computes rate correctly", {
  result <- eri_incidence_rate(5, 1000)
  expect_equal(result, 5)  # 5/1000 * 1000 = 5

  result2 <- eri_incidence_rate(1, 1000, multiplier = 100000)
  expect_equal(result2, 100)  # 1/1000 * 100000 = 100
})

test_that("eri_incidence_rate returns NA when pop is 0", {
  result <- eri_incidence_rate(5, 0)
  expect_true(is.na(result))
})

test_that("eri_incidence_rate returns NA when pop is negative", {
  result <- eri_incidence_rate(5, -100)
  expect_true(is.na(result))
})

test_that("eri_incidence_rate returns NA when pop is NA", {
  result <- eri_incidence_rate(5, NA_real_)
  expect_true(is.na(result))
})

test_that("eri_incidence_rate is vectorized", {
  cases <- c(10, 5, 0)
  pop   <- c(1000, 500, 1000)
  result <- eri_incidence_rate(cases, pop)
  expect_equal(result, c(10, 10, 0))
})

test_that("eri_incidence_rate errors on mismatched lengths", {
  expect_error(eri_incidence_rate(c(1, 2, 3), c(1000, 2000)), "same length")
})

#### eri_epiweek_date ####

test_that("eri_epiweek_date week 1 of 2024 is correct (CDC Sunday)", {
  result <- eri_epiweek_date(2024, 1, "Sunday")
  expect_s3_class(result, "Date")
  # CDC epiweek 1 2024 starts on Dec 31, 2023
  expect_equal(as.character(result), "2023-12-31")
})

test_that("eri_epiweek_date week 1 of 2023 is correct (CDC Sunday)", {
  result <- eri_epiweek_date(2023, 1, "Sunday")
  expect_equal(as.character(result), "2023-01-01")
})

test_that("eri_epiweek_date is vectorized", {
  result <- eri_epiweek_date(c(2023, 2024), c(1, 1), "Sunday")
  expect_equal(length(result), 2L)
  expect_s3_class(result, "Date")
})

test_that("eri_epiweek_date warns on out-of-range week", {
  expect_warning(eri_epiweek_date(2024, 54), "outside")
})

#### eri_study_week ####

test_that("eri_study_week returns 0 for the index week", {
  index <- as.Date("2024-01-07")  # a Sunday
  result <- eri_study_week(2024, 2, index, "Sunday")
  expect_equal(result, 0L)
})

test_that("eri_study_week is positive after index_date", {
  index  <- as.Date("2024-01-07")
  result <- eri_study_week(2024, 10, index, "Sunday")
  expect_true(result > 0L)
})

test_that("eri_study_week is negative before index_date", {
  index  <- as.Date("2024-06-01")
  result <- eri_study_week(2024, 1, index, "Sunday")
  expect_true(result < 0L)
})

test_that("eri_study_week errors when index_date is not a Date", {
  expect_error(eri_study_week(2024, 5, "2024-01-07"), "Date")
})

#### eri_epidemic_curve ####

test_that("eri_epidemic_curve returns a ggplot", {
  df <- tibble::tibble(
    date = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 12),
    n    = sample(1:20, 12, replace = TRUE)
  )
  p <- eri_epidemic_curve(df, "date", count_col = "n")
  expect_s3_class(p, "gg")
})

test_that("eri_epidemic_curve works with case-level data (count_col = NULL)", {
  df <- tibble::tibble(
    date = rep(seq.Date(as.Date("2024-01-01"), by = "week", length.out = 4), each = 5)
  )
  p <- eri_epidemic_curve(df, "date")
  expect_s3_class(p, "gg")
})

test_that("eri_epidemic_curve with group_col returns ggplot", {
  df <- tibble::tibble(
    date    = rep(seq.Date(as.Date("2024-01-01"), by = "week", length.out = 6), 2),
    country = rep(c("DR", "Haiti"), each = 6),
    n       = sample(1:30, 12, replace = TRUE)
  )
  p <- eri_epidemic_curve(df, "date", count_col = "n", group_col = "country")
  expect_s3_class(p, "gg")
})

test_that("eri_epidemic_curve period = 'month' groups correctly", {
  df <- tibble::tibble(
    date = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 20),
    n    = rep(1L, 20)
  )
  p <- eri_epidemic_curve(df, "date", count_col = "n", period = "month")
  expect_s3_class(p, "gg")
  built <- ggplot2::ggplot_build(p)
  # 20 weekly obs should collapse to <= 5 months
  expect_lte(nrow(built$data[[1]]), 5L)
})

test_that("eri_epidemic_curve errors on missing date column", {
  df <- tibble::tibble(x = 1:5, n = 1:5)
  expect_error(eri_epidemic_curve(df, "date", "n"), "date_col")
})

#### eri_case_summary ####

test_that("eri_case_summary counts rows by group when count_col is NULL", {
  df <- tibble::tibble(
    country = c("DR", "DR", "Haiti", "Haiti", "Haiti"),
    year    = c(2023, 2024, 2023, 2024, 2024)
  )
  result <- eri_case_summary(df, group_cols = c("country", "year"))
  expect_equal(nrow(result), 4L)
  haiti_2024 <- result[result$country == "Haiti" & result$year == 2024, ]
  expect_equal(haiti_2024$n_cases, 2L)
})

test_that("eri_case_summary sums count_col when supplied", {
  df <- tibble::tibble(
    country = c("DR", "DR", "Haiti"),
    n       = c(10L, 15L, 20L)
  )
  result <- eri_case_summary(df, "country", count_col = "n")
  dr_row <- result[result$country == "DR", ]
  expect_equal(dr_row$n_cases, 25L)
})

test_that("eri_case_summary date filter works", {
  df <- tibble::tibble(
    country = c("DR", "DR", "DR"),
    date    = as.Date(c("2024-01-01", "2024-06-01", "2024-12-01")),
    n       = c(10L, 20L, 30L)
  )
  result <- eri_case_summary(
    df, "country",
    start    = as.Date("2024-03-01"),
    end      = as.Date("2024-09-01"),
    date_col = "date",
    count_col = "n"
  )
  expect_equal(result$n_cases, 20L)
})

test_that("eri_case_summary errors on missing group column", {
  df <- tibble::tibble(x = 1:3)
  expect_error(eri_case_summary(df, c("country", "year")), "country")
})

test_that("eri_case_summary errors when start is given without date_col", {
  df <- tibble::tibble(country = "DR", n = 5L)
  expect_error(
    eri_case_summary(df, "country", start = as.Date("2024-01-01")),
    "date_col"
  )
})
