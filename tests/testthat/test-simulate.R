#### Tests for eri_inject_anomalies() ####

clean_df <- function() {
  data.frame(
    id    = 1:10,
    cases = as.numeric(c(5, 8, 3, 6, 9, 4, 7, 2, 5, 8)),
    site  = letters[1:10],
    stringsAsFactors = FALSE
  )
}

test_that("eri_inject_anomalies is reproducible with a seed and attaches a log", {
  a <- suppressMessages(eri_inject_anomalies(clean_df(), seed = 42))
  b <- suppressMessages(eri_inject_anomalies(clean_df(), seed = 42))
  expect_identical(a, b)
  expect_s3_class(attr(a, "eri_anomalies"), "tbl_df")
  expect_named(attr(a, "eri_anomalies"), c("type", "row", "column", "original", "new"))
})

test_that("missing injects NA into the logged cells", {
  d   <- suppressMessages(eri_inject_anomalies(clean_df(), types = "missing", n = 3, seed = 1))
  log <- attr(d, "eri_anomalies")
  expect_equal(nrow(log), 3L)
  expect_true(all(log$type == "missing"))
  for (i in seq_len(nrow(log))) {
    expect_true(is.na(d[[log$column[i]]][[log$row[i]]]))
  }
})

test_that("outlier and negative produce extreme / negative numeric cells", {
  d1 <- suppressMessages(eri_inject_anomalies(clean_df(), types = "outlier",
                                              n = 1, cols = "cases", seed = 1))
  expect_gte(d1$cases[[attr(d1, "eri_anomalies")$row]], 1000)

  d2 <- suppressMessages(eri_inject_anomalies(clean_df(), types = "negative",
                                              n = 1, cols = "cases", seed = 1))
  expect_lt(d2$cases[[attr(d2, "eri_anomalies")$row]], 0)
})

test_that("typo perturbs a character cell", {
  d  <- suppressMessages(eri_inject_anomalies(clean_df(), types = "typo",
                                              n = 1, cols = "site", seed = 1))
  rw <- attr(d, "eri_anomalies")$row
  expect_false(identical(d$site[[rw]], clean_df()$site[[rw]]))
})

test_that("duplicate adds rows and drop removes them, both logged", {
  dup <- suppressMessages(eri_inject_anomalies(clean_df(), types = "duplicate", n = 2, seed = 1))
  expect_equal(nrow(dup), 12L)
  expect_equal(sum(attr(dup, "eri_anomalies")$type == "duplicate"), 2L)

  drp <- suppressMessages(eri_inject_anomalies(clean_df(), types = "drop", n = 3, seed = 1))
  expect_equal(nrow(drp), 7L)
  expect_equal(sum(attr(drp, "eri_anomalies")$type == "drop"), 3L)
})

test_that("cell-level sampling is distinct and capped at the eligible-cell count", {
  df <- data.frame(id = 1:4, a = as.numeric(1:4))  # 4 eligible cells in col 'a'
  d  <- suppressMessages(eri_inject_anomalies(df, types = "missing", n = 99, cols = "a", seed = 5))
  log <- attr(d, "eri_anomalies")
  expect_equal(nrow(log), 4L)                       # capped at 4 cells, not 99
  expect_equal(nrow(unique(log[, c("row", "column")])), 4L)  # all distinct
})

test_that("numeric injection preserves an integer column's type", {
  df <- data.frame(id = 1:10, cases = 1:10)  # integer
  d  <- suppressMessages(eri_inject_anomalies(df, types = "outlier", n = 1, cols = "cases", seed = 1))
  expect_type(d$cases, "integer")             # not promoted to double
})

test_that("combined duplicate + drop keeps logged indices valid", {
  d <- suppressMessages(eri_inject_anomalies(clean_df(), types = c("duplicate", "drop"),
                                             n = 2, seed = 3))
  log <- attr(d, "eri_anomalies")
  expect_equal(nrow(d), 10L)                   # +2 duplicated, -2 dropped
  expect_equal(sum(log$type == "duplicate"), 2L)
  expect_equal(sum(log$type == "drop"), 2L)
})

test_that("cols restricts cell-level injection", {
  df <- data.frame(id = 1:10, a = as.numeric(1:10), b = as.numeric(1:10))
  d  <- suppressMessages(eri_inject_anomalies(df, types = "missing", n = 5, cols = "a", seed = 1))
  expect_true(all(attr(d, "eri_anomalies")$column == "a"))
})

test_that("eri_inject_anomalies validates its inputs", {
  cl <- clean_df()
  expect_error(eri_inject_anomalies(cl, types = "explode"), "Unknown anomaly type")
  expect_error(eri_inject_anomalies(cl, n = 0), "positive integer")
  expect_error(eri_inject_anomalies(cl[0, ]), "no rows")
  expect_error(eri_inject_anomalies(cl, cols = "nope"), "not in")
})

test_that("a type with no eligible columns is skipped with a warning", {
  numeric_only <- data.frame(id = 1:5, cases = as.numeric(1:5))
  d <- suppressWarnings(eri_inject_anomalies(numeric_only, types = "typo", n = 1, seed = 1))
  expect_equal(nrow(attr(d, "eri_anomalies")), 0L)
  # two warnings: the per-type skip, then the "nothing injected" summary
  expect_warning(
    expect_warning(eri_inject_anomalies(numeric_only, types = "typo", n = 1, seed = 1), "no eligible"),
    "No anomalies"
  )
})
