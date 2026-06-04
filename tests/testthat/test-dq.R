#### Shared helpers ####

make_surveillance <- function() {
  tibble::tibble(
    Year     = c(rep(2024L, 6), rep(2025L, 4)),
    EpiWeek  = c(1L, 2L, 3L, 4L, 5L, 6L, 1L, 2L, 3L, 4L),
    Province = c(rep("North", 5), rep("South", 5)),
    n_cases  = c(10L, 11L, 12L, 50L, 13L,
                 5L,  6L,  5L,  6L,  5L)
  )
}

make_gapped <- function() {
  # Week 3 missing for North; complete for South
  tibble::tibble(
    Year     = rep(2024L, 9),
    EpiWeek  = c(1L, 2L, 4L, 5L,   # North: week 3 missing
                 1L, 2L, 3L, 4L, 5L),
    Province = c(rep("North", 4), rep("South", 5)),
    n_cases  = c(10L, 11L, 13L, 14L, 5L, 6L, 5L, 6L, 5L)
  )
}

test_that("add_anomaly_gaps detects missing week", {
  df   <- make_gapped()
  gaps <- add_anomaly_gaps(df, "EpiWeek", "week",
                            group_cols = "Province", year_col = "Year")
  expect_equal(nrow(gaps), 1L)
  expect_equal(gaps$Province, "North")
  expect_equal(gaps$EpiWeek, 3L)
  expect_equal(gaps$issue, "structural_gap")
})

test_that("add_anomaly_gaps returns empty tibble when no gaps", {
  df   <- make_surveillance()
  gaps <- add_anomaly_gaps(df, "EpiWeek", "week",
                            group_cols = "Province", year_col = "Year")
  expect_equal(nrow(gaps), 0L)
})

test_that("add_anomaly_gaps errors on missing period_col", {
  df <- tibble::tibble(week = 1:3, n = 1:3)
  expect_error(add_anomaly_gaps(df, "EpiWeek", "week"), "period_col")
})

test_that("add_anomaly_gaps works on dq_result and appends flags", {
  df  <- make_gapped()
  dqr <- structure(
    list(
      data  = df,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
  out <- add_anomaly_gaps(dqr, "EpiWeek", "week",
                           group_cols = "Province", year_col = "Year")
  expect_s3_class(out, "dq_result")
  expect_gt(nrow(out$flags), 0L)
  expect_true(all(grepl("structural_gap", out$flags$issue)))
  expect_true(all(is.na(out$flags$row)))
})

#### Tests for add_anomaly_pct_change ####

test_that("add_anomaly_pct_change flags known spike", {
  df  <- make_surveillance()
  out <- add_anomaly_pct_change(df, "n_cases", "EpiWeek",
                                 threshold  = 0.5,
                                 group_cols = "Province",
                                 year_col   = "Year")

  flag_col <- "anomaly_pct_change_n_cases"
  pct_col  <- "pct_change_n_cases"

  expect_true(flag_col %in% names(out))
  expect_true(pct_col  %in% names(out))

  # Row where North jumps from 12 to 50 should be flagged
  north_spike <- out[out$Province == "North" & out$EpiWeek == 4 & out$Year == 2024, ]
  expect_true(north_spike[[flag_col]])
  expect_gt(north_spike[[pct_col]], 2)  # >200% change
})

test_that("add_anomaly_pct_change does not flag stable series", {
  df  <- make_surveillance()
  out <- add_anomaly_pct_change(df, "n_cases", "EpiWeek",
                                 threshold  = 0.5,
                                 group_cols = "Province",
                                 year_col   = "Year")

  south_rows <- out[out$Province == "South", ]
  expect_false(any(south_rows[["anomaly_pct_change_n_cases"]], na.rm = TRUE))
})

test_that("add_anomaly_pct_change produces NA pct_change for first row per group", {
  df  <- make_surveillance()
  out <- add_anomaly_pct_change(df, "n_cases", "EpiWeek",
                                 group_cols = "Province",
                                 year_col   = "Year")

  first_per_group <- out |>
    dplyr::group_by(Province) |>
    dplyr::slice_min(order_by = Year * 1000 + EpiWeek, n = 1) |>
    dplyr::ungroup()

  expect_true(all(is.na(first_per_group[["pct_change_n_cases"]])))
})

test_that("add_anomaly_pct_change works without group_cols", {
  df  <- tibble::tibble(period = 1:5, n = c(10, 11, 12, 50, 13))
  out <- add_anomaly_pct_change(df, "n", "period", threshold = 0.5)
  expect_true("anomaly_pct_change_n" %in% names(out))
  expect_true(out$anomaly_pct_change_n[4])  # 50/12 - 1 > 0.5
})

test_that("add_anomaly_pct_change errors on missing value_col", {
  df <- tibble::tibble(period = 1:3, n = 1:3)
  expect_error(add_anomaly_pct_change(df, "missing", "period"), "value_col")
})

test_that("add_anomaly_pct_change works on dq_result and appends flags", {
  df  <- make_surveillance()
  # Build a minimal dq_result by hand
  dqr <- structure(
    list(
      data  = df,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
  out <- add_anomaly_pct_change(dqr, "n_cases", "EpiWeek",
                                 threshold  = 0.5,
                                 group_cols = "Province",
                                 year_col   = "Year")

  expect_s3_class(out, "dq_result")
  expect_true("anomaly_pct_change_n_cases" %in% names(out$data))
  expect_gt(nrow(out$flags), 0)
  expect_true(all(out$flags$column == "n_cases"))
  expect_true(all(grepl("% change anomaly", out$flags$issue)))
})
