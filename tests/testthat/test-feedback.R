#### Tests for the feedback / ticket log ####

# These reuse the in-memory optimistic-concurrency store from helper-metadata.R
# (new_yaml_store / local_yaml_store), which mocks .eri_yaml_read_versioned /
# .eri_yaml_write_conditional — so eri_feedback()'s .eri_yaml_update() append runs
# against a plain list, no Azure.

# --- eri_feedback (capture) ---------------------------------------------------

test_that("eri_feedback files a ticket into an empty log", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "test.user", .package = "erifunctions")

  out <- suppressMessages(eri_feedback("Onboarding week 1 felt too fast", data_con = "mock"))

  expect_equal(out$id, 1L)
  expect_equal(out$submitted_by, "test.user")
  expect_equal(out$area, "general")
  expect_equal(out$status, "submitted")
  expect_match(out$message, "too fast")
  expect_false(is.null(out$submitted_at))
  expect_length(store$data$entries, 1L)
})

test_that("eri_feedback auto-increments the ticket id and records the area (lower-cased)", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  a <- suppressMessages(eri_feedback("first", data_con = "mock"))
  b <- suppressMessages(eri_feedback("second", area = "ODK", data_con = "mock"))

  expect_equal(a$id, 1L)
  expect_equal(b$id, 2L)
  expect_equal(b$area, "odk")
  expect_length(store$data$entries, 2L)
})

test_that("eri_feedback nudges toward known areas for an unfamiliar area but still files it", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  expect_message(
    out <- eri_feedback("x", area = "odk-sync", data_con = "mock"),
    "new area"
  )
  expect_equal(out$area, "odk-sync")
  expect_length(store$data$entries, 1L)
})

test_that("eri_feedback rejects an empty message or area before touching Azure", {
  expect_error(eri_feedback("   "), "non-empty")
  expect_error(eri_feedback("ok", area = ""), "non-empty")
})

test_that("eri_feedback gives a distinct id even when a concurrent ticket lands first", {
  store <- new_yaml_store(list(entries = list()))
  # On our first write a concurrent writer commits ticket #1; ours 412s and retries
  # against the fresh log, so the auto-increment must skip to #2.
  local_yaml_store(store, concurrent = function(d) {
    if (is.null(d$entries)) d$entries <- list()
    d$entries <- c(d$entries, list(list(
      id = 1L, area = "general", status = "submitted", message = "other"
    )))
    d
  })
  store$conflict_once <- TRUE
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  out <- suppressMessages(eri_feedback("mine", data_con = "mock"))

  expect_equal(out$id, 2L)
  ids <- vapply(store$data$entries, function(e) as.integer(e$id), integer(1L))
  expect_setequal(ids, c(1L, 2L))
})

# --- eri_feedback_list (read) -------------------------------------------------

test_that("eri_feedback_list returns the backlog and filters by area / status", {
  e1 <- list(id = 1L, submitted_at = "t1", submitted_by = "u", area = "general",
             status = "submitted", message = "a")
  e2 <- list(id = 2L, submitted_at = "t2", submitted_by = "u", area = "odk",
             status = "planned", message = "b")
  store <- new_yaml_store(list(entries = list(e1, e2)))
  local_yaml_store(store)

  all <- eri_feedback_list(data_con = "mock")
  expect_s3_class(all, "tbl_df")
  expect_equal(nrow(all), 2L)
  expect_named(all, c("id", "submitted_at", "submitted_by", "area", "status", "message"))

  expect_equal(eri_feedback_list(area = "odk", data_con = "mock")$id, 2L)
  expect_equal(eri_feedback_list(status = "submitted", data_con = "mock")$id, 1L)
})

test_that("eri_feedback_list returns a typed empty tibble when nothing is logged", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)

  out <- suppressMessages(eri_feedback_list(data_con = "mock"))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("id", "submitted_at", "submitted_by", "area", "status", "message"))
})

# --- eri_feedback_status (triage) ---------------------------------------------

mk_ticket <- function(id, status = "submitted", area = "general") {
  list(id = id, submitted_at = "t", submitted_by = "u", area = area,
       status = status, message = paste("msg", id))
}

test_that("eri_feedback_status moves a ticket and records the transition history", {
  store <- new_yaml_store(list(entries = list(mk_ticket(1L), mk_ticket(2L))))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "triager", .package = "erifunctions")

  out <- suppressMessages(eri_feedback_status(2L, "planned", note = "queued for v0.x", data_con = "mock"))

  expect_equal(out$status, "planned")
  expect_equal(out$updated_by, "triager")
  expect_length(out$history, 1L)
  expect_equal(out$history[[1]]$from, "submitted")
  expect_equal(out$history[[1]]$to, "planned")
  expect_equal(out$history[[1]]$note, "queued for v0.x")
  # ticket #1 untouched
  ticket1 <- Filter(function(e) e$id == 1L, store$data$entries)[[1]]
  expect_equal(ticket1$status, "submitted")
})

test_that("eri_feedback_status appends successive transitions to the history", {
  store <- new_yaml_store(list(entries = list(mk_ticket(1L))))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  suppressMessages(eri_feedback_status(1L, "planned", data_con = "mock"))
  out <- suppressMessages(eri_feedback_status(1L, "fixed", note = "#251", data_con = "mock"))

  expect_equal(out$status, "fixed")
  expect_length(out$history, 2L)
  expect_equal(out$history[[2]]$from, "planned")
  expect_equal(out$history[[2]]$to, "fixed")
})

test_that("eri_feedback_status rejects an unknown status and an unknown id", {
  store <- new_yaml_store(list(entries = list(mk_ticket(1L))))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  expect_error(eri_feedback_status(1L, "donezo", data_con = "mock"), "not a valid status")
  expect_error(eri_feedback_status(999L, "fixed", data_con = "mock"), "No feedback ticket")
})

# --- eri_feedback_board -------------------------------------------------------

test_that("eri_feedback_board counts tickets by status and returns the backlog", {
  store <- new_yaml_store(list(entries = list(
    mk_ticket(1L, "submitted"), mk_ticket(2L, "planned"),
    mk_ticket(3L, "fixed"),     mk_ticket(4L, "fixed")
  )))
  local_yaml_store(store)

  out <- eri_feedback_board(data_con = "mock")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 4L)
  expect_equal(sum(out$status == "fixed"), 2L)
})

test_that("eri_feedback_board is a clean no-op on an empty backlog", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)

  out <- suppressMessages(eri_feedback_board(data_con = "mock"))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})
