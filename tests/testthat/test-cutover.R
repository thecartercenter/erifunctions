#### Tests for the cutover ledger (ADR-0015) ####

# eri_cutover_check runs eri_compare on data frames and records via the
# in-memory optimistic-concurrency store (helper-metadata.R).

# --- eri_cutover_check --------------------------------------------------------

test_that("eri_cutover_check records an equivalent period with the verified actor", {
  a <- data.frame(id = 1:3, n = c(1, 2, 3))
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "tester", .package = "erifunctions")

  cmp <- suppressMessages(eri_cutover_check(
    a, a, country = "uga", disease = "oncho", data_source = "programmatic",
    period = "2024_06", by = "id", data_con = "mock"
  ))

  expect_s3_class(cmp, "eri_comparison")
  expect_length(store$data$entries, 1L)
  e <- store$data$entries[[1]]
  expect_true(e$equivalent)
  expect_equal(e$country, "uga")
  expect_equal(e$period, "2024_06")
  expect_equal(e$recorded_by, "tester")
  expect_equal(unlist(e$by), "id")
})

test_that("eri_cutover_check records a non-equivalent period with delta counts", {
  a <- data.frame(id = 1:3, n = c(1, 2, 3))
  b <- data.frame(id = 1:3, n = c(1, 9, 3))
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "t", .package = "erifunctions")

  suppressMessages(eri_cutover_check(
    a, b, country = "uga", disease = "oncho", data_source = "programmatic",
    period = "2024_06", by = "id", data_con = "mock"
  ))
  e <- store$data$entries[[1]]
  expect_false(e$equivalent)
  expect_equal(e$n_value_mismatches, 1L)
})

test_that("eri_cutover_check with record = FALSE does not write", {
  a <- data.frame(id = 1:2, n = c(1, 2))
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)

  cmp <- suppressMessages(eri_cutover_check(
    a, a, country = "uga", disease = "oncho", data_source = "programmatic",
    period = "2024_06", by = "id", record = FALSE, data_con = "mock"
  ))
  expect_length(store$data$entries, 0L)
  expect_s3_class(cmp, "eri_comparison")
})

test_that("eri_cutover_check validates required args", {
  a <- data.frame(id = 1:2, n = c(1, 2))
  expect_error(eri_cutover_check(a, a, country = "", disease = "o", data_source = "p",
                                 period = "x", by = "id", data_con = "mock"), "non-empty")
  expect_error(eri_cutover_check(a, a, country = "u", disease = "o", data_source = "p",
                                 period = "x", by = NULL, data_con = "mock"), "by")
})

# --- eri_cutover_status -------------------------------------------------------

mk_entry <- function(period, equivalent, at, data_type = NA_character_) {
  list(country = "uga", disease = "oncho", data_source = "programmatic",
       data_type = data_type, period = period, equivalent = equivalent,
       n_added = 0L, n_dropped = 0L,
       n_value_mismatches = if (equivalent) 0L else 1L, recorded_at = at)
}

test_that("eri_cutover_status reports the streak and eligibility", {
  store <- new_yaml_store(list(entries = list(
    mk_entry("2024_04", TRUE, "2026-06-29T01:00:00Z"),
    mk_entry("2024_05", TRUE, "2026-06-29T02:00:00Z"),
    mk_entry("2024_06", TRUE, "2026-06-29T03:00:00Z")
  )))
  local_yaml_store(store)

  st <- suppressMessages(eri_cutover_status("uga", "oncho", "programmatic", n = 3, data_con = "mock"))
  expect_equal(st$streak, 3L)
  expect_true(st$eligible)
  expect_equal(nrow(st$periods), 3L)
})

test_that("a non-equivalent period resets the streak to the trailing run", {
  store <- new_yaml_store(list(entries = list(
    mk_entry("2024_04", TRUE,  "2026-06-29T01:00:00Z"),
    mk_entry("2024_05", FALSE, "2026-06-29T02:00:00Z"),
    mk_entry("2024_06", TRUE,  "2026-06-29T03:00:00Z")
  )))
  local_yaml_store(store)

  st <- suppressMessages(eri_cutover_status("uga", "oncho", "programmatic", n = 3, data_con = "mock"))
  expect_equal(st$streak, 1L)
  expect_false(st$eligible)
})

test_that("the streak orders by data period, not check time (backfill-safe)", {
  # 2024_06 checked first (equivalent); 2024_05 backfilled later (not equivalent).
  store <- new_yaml_store(list(entries = list(
    mk_entry("2024_06", TRUE,  "2026-06-29T01:00:00Z"),
    mk_entry("2024_05", FALSE, "2026-06-29T02:00:00Z")
  )))
  local_yaml_store(store)

  st <- suppressMessages(eri_cutover_status("uga", "oncho", "programmatic", n = 3, data_con = "mock"))
  # period order is 2024_05 (F) -> 2024_06 (T); trailing run is just 2024_06 -> streak 1.
  # (recorded_at order would have put 2024_05 last and given streak 0.)
  expect_equal(st$streak, 1L)
  expect_equal(st$periods$period, c("2024_05", "2024_06"))
})

test_that("the most recent entry per period wins", {
  store <- new_yaml_store(list(entries = list(
    mk_entry("2024_06", FALSE, "2026-06-29T01:00:00Z"),   # first check failed
    mk_entry("2024_06", TRUE,  "2026-06-29T02:00:00Z")    # re-checked, now equivalent
  )))
  local_yaml_store(store)

  st <- suppressMessages(eri_cutover_status("uga", "oncho", "programmatic", n = 3, data_con = "mock"))
  expect_equal(nrow(st$periods), 1L)
  expect_true(st$periods$equivalent)
  expect_equal(st$streak, 1L)
})

test_that("eri_cutover_status with no entries for the stream is not eligible", {
  store <- new_yaml_store(list(entries = list(
    mk_entry("2024_06", TRUE, "2026-06-29T01:00:00Z", data_type = "treatment")
  )))
  local_yaml_store(store)

  # different data_type -> no match
  st <- suppressMessages(eri_cutover_status("uga", "oncho", "programmatic", data_con = "mock"))
  expect_false(st$eligible)
  expect_equal(st$streak, 0L)
  expect_equal(nrow(st$periods), 0L)
})
