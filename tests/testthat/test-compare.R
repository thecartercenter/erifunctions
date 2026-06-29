#### Tests for eri_compare() — dataset reconciliation ####

# Pure data-frame engine; no Azure, synthetic frames only.

test_that("eri_compare reports equivalence for identical data", {
  a <- data.frame(id = 1:3, n = c(10, 20, 30), site = c("x", "y", "z"))
  r <- eri_compare(a, a, by = "id")
  expect_s3_class(r, "eri_comparison")
  expect_true(r$equivalent)
  expect_equal(r$summary$n_matched, 3L)
  expect_equal(nrow(r$values), 0L)
})

test_that("eri_compare pinpoints per-cell value mismatches by key", {
  a <- data.frame(id = 1:3, n = c(10, 20, 30), site = c("x", "y", "z"))
  b <- data.frame(id = 1:3, n = c(10, 21, 30), site = c("x", "y", "Z"))
  r <- eri_compare(a, b, by = "id")

  expect_false(r$equivalent)
  expect_equal(r$summary$n_value_mismatches, 2L)
  expect_setequal(r$values$column, c("n", "site"))
  v <- r$values[r$values$id == 2 & r$values$column == "n", ]
  expect_equal(v$new, "20")
  expect_equal(v$old, "21")
})

test_that("eri_compare detects added and dropped rows (full rows returned)", {
  a <- data.frame(id = c(1, 2, 4), n = c(1, 2, 4))
  b <- data.frame(id = c(1, 2, 3), n = c(1, 2, 3))
  r <- eri_compare(a, b, by = "id")

  expect_equal(r$rows$added$id, 4)     # only in new
  expect_equal(r$rows$dropped$id, 3)   # only in old
  expect_true("n" %in% names(r$rows$added))  # full row, not just key
  expect_false(r$equivalent)
})

test_that("eri_compare honours numeric tolerance", {
  a <- data.frame(id = 1:2, x = c(1.00, 2.00))
  b <- data.frame(id = 1:2, x = c(1.005, 2.50))
  expect_equal(eri_compare(a, b, by = "id", tolerance = 0.01)$summary$n_value_mismatches, 1L)
  expect_equal(eri_compare(a, b, by = "id", tolerance = 0)$summary$n_value_mismatches, 2L)
})

test_that("eri_compare reports added/dropped columns and type mismatches", {
  a <- data.frame(id = 1:2, n = c(1L, 2L), extra = c("p", "q"))
  b <- data.frame(id = 1:2, n = c("1", "2"), gone = c("r", "s"))
  r <- eri_compare(a, b, by = "id")

  expect_equal(r$schema$added, "extra")
  expect_equal(r$schema$dropped, "gone")
  expect_equal(r$schema$type_mismatch$column, "n")
  expect_equal(r$summary$n_value_mismatches, 0L)  # 1L vs "1" is equal in content
  expect_false(r$equivalent)                      # but schema differs
})

test_that("eri_compare treats NA == NA as equal and NA vs value as a mismatch", {
  a <- data.frame(id = 1:2, x = c(NA_real_, 5))
  b <- data.frame(id = 1:2, x = c(NA_real_, NA_real_))
  r <- eri_compare(a, b, by = "id")
  expect_equal(r$summary$n_value_mismatches, 1L)  # id 1 NA==NA; id 2 5 vs NA
})

test_that("eri_compare without keys reports schema + row membership and informs", {
  a <- data.frame(id = 1:3, n = c(1, 2, 3))
  b <- data.frame(id = 1:3, n = c(1, 2, 9))
  expect_message(r <- eri_compare(a, b), "keys")

  expect_false(r$equivalent)
  expect_equal(r$summary$n_added, 1L)
  expect_equal(r$summary$n_dropped, 1L)
  expect_true(is.na(r$summary$n_value_mismatches))
})

test_that("eri_compare aborts when by is not a unique key", {
  a <- data.frame(id = c(1, 1, 2), n = 1:3)
  b <- data.frame(id = c(1, 2, 3), n = 1:3)
  expect_error(eri_compare(a, b, by = "id"), "uniquely identify")
})

test_that("eri_compare aborts when a key column is missing", {
  a <- data.frame(id = 1:2, n = 1:2)
  b <- data.frame(other = 1:2, n = 1:2)
  expect_error(eri_compare(a, b, by = "id"), "not found in both")
})

test_that("eri_compare ignores specified columns", {
  a <- data.frame(id = 1:2, n = c(1, 2), ts = c("t1", "t2"))
  b <- data.frame(id = 1:2, n = c(1, 2), ts = c("t9", "t8"))
  expect_true(eri_compare(a, b, by = "id", ignore = "ts")$equivalent)
})

test_that("print.eri_comparison summarises both outcomes without error", {
  a <- data.frame(id = 1:2, n = c(1, 2))
  b <- data.frame(id = 1:3, n = c(1, 9, 3))
  expect_match(cli::cli_fmt(print(eri_compare(a, b, by = "id"))), "Not equivalent", all = FALSE)
  expect_match(cli::cli_fmt(print(eri_compare(a, a, by = "id"))), "Equivalent", all = FALSE)
})
