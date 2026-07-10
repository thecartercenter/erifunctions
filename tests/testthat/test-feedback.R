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
  expect_named(all, c("id", "submitted_at", "submitted_by", "area", "status", "message",
                      "context", "attachment"))

  expect_equal(eri_feedback_list(area = "odk", data_con = "mock")$id, 2L)
  expect_equal(eri_feedback_list(status = "submitted", data_con = "mock")$id, 1L)
})

test_that("eri_feedback_list returns a typed empty tibble when nothing is logged", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)

  out <- suppressMessages(eri_feedback_list(data_con = "mock"))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("id", "submitted_at", "submitted_by", "area", "status", "message",
                      "context", "attachment"))
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
  expect_error(eri_feedback_status(2.7, "fixed", data_con = "mock"), "positive integer")
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

# --- eri_feedback_report (weekly digest) --------------------------------------

iso_ago <- function(days) format(Sys.time() - days * 86400, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

report_store <- function() {
  new_yaml_store(list(entries = list(
    list(id = 1L, submitted_at = iso_ago(1),  submitted_by = "dana", area = "odk",
         status = "submitted", message = "sync slow on big forms"),
    list(id = 2L, submitted_at = iso_ago(30), submitted_by = "eli",  area = "spatial",
         status = "planned",   message = "reconcile wishlist"),
    list(id = 3L, submitted_at = iso_ago(40), submitted_by = "dana", area = "catalog",
         status = "fixed", updated_at = iso_ago(2), updated_by = "me",
         history = list(list(from = "planned", to = "fixed", by = "me",
                             at = iso_ago(2), note = "shipped in #251"))),
    list(id = 4L, submitted_at = iso_ago(40), submitted_by = "eli",  area = "docs",
         status = "fixed", updated_at = iso_ago(30), updated_by = "me",
         history = list(list(from = "planned", to = "fixed", by = "me",
                             at = iso_ago(30), note = "old fix")))
  )))
}

test_that("eri_feedback_report writes an HTML digest bucketed by the weekly window", {
  store <- report_store()
  local_yaml_store(store)
  f <- withr::local_tempfile(fileext = ".html")

  out <- suppressMessages(eri_feedback_report(file = f, format = "html", data_con = "mock"))
  expect_equal(out, f)

  html <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_match(html, "ERI feedback backlog")
  expect_match(html, "New this week \\(1\\)")      # only the 1-day-old ticket
  expect_match(html, "Closed this week \\(1\\)")   # only the one fixed 2 days ago
  expect_match(html, "Open backlog \\(2\\)")       # submitted + planned
  expect_match(html, "shipped in #251")            # closing note surfaced
  expect_no_match(html, "old fix")                 # fixed 30 days ago is not "this week"
})

test_that("eri_feedback_report writes a markdown digest", {
  store <- report_store()
  local_yaml_store(store)
  f <- withr::local_tempfile(fileext = ".md")

  suppressMessages(eri_feedback_report(file = f, format = "md", data_con = "mock"))
  md <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_match(md, "# ERI feedback backlog")
  expect_match(md, "## New this week \\(1\\)")
  expect_match(md, "## Open backlog \\(2\\)")
  expect_match(md, "\\| #1 \\|")                   # table row for ticket #1
})

test_that("eri_feedback_report handles an empty backlog", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  f <- withr::local_tempfile(fileext = ".md")

  suppressMessages(eri_feedback_report(file = f, format = "md", data_con = "mock"))
  expect_match(paste(readLines(f, warn = FALSE), collapse = "\n"), "No feedback logged yet")
})

test_that("eri_feedback_report treats a missing/NA status as submitted without crashing", {
  store <- new_yaml_store(list(entries = list(
    list(id = 1L, submitted_at = iso_ago(1), submitted_by = "u", area = "general",
         status = NA_character_, message = "status went missing")
  )))
  local_yaml_store(store)
  f <- withr::local_tempfile(fileext = ".md")

  expect_no_error(suppressMessages(eri_feedback_report(file = f, format = "md", data_con = "mock")))
  expect_match(paste(readLines(f, warn = FALSE), collapse = "\n"), "Open backlog \\(1\\)")
})

# --- eri_feedback context/attachment -----------------------------------------

test_that("eri_feedback stores context only when supplied, byte-for-byte legacy shape otherwise", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  plain <- suppressMessages(eri_feedback("no context here", data_con = "mock"))
  expect_false("context" %in% names(plain))

  scoped <- suppressMessages(eri_feedback(
    "scoped ticket", area = "dq",
    context = list(country = "sdn", disease = "oncho"),
    data_con = "mock"
  ))
  expect_equal(scoped$context, list(country = "sdn", disease = "oncho"))
})

test_that("eri_feedback rejects a non-list context", {
  expect_error(eri_feedback("x", context = "not a list"), "named list")
})

test_that("eri_feedback uploads an attachment before logging the ticket, keyed by a token not the ticket id", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(.eri_analyst_id = function(...) "u", .package = "erifunctions")

  uploaded <- NULL
  local_mocked_bindings(
    .eri_blob_write = function(con, src, dest, ...) { uploaded <<- list(src = src, dest = dest); invisible(dest) },
    .package = "erifunctions"
  )

  tmp <- withr::local_tempfile(fileext = ".yaml")
  writeLines("a: 1", tmp)

  out <- suppressMessages(eri_feedback("with an attachment", area = "dq",
                                        attachment = tmp, data_con = "mock"))

  expect_false(is.null(uploaded))
  expect_equal(uploaded$src, tmp)
  expect_match(uploaded$dest, "^_feedback/attachments/.+/", perl = TRUE)
  expect_match(uploaded$dest, basename(tmp), fixed = TRUE)
  expect_equal(out$attachment, uploaded$dest)
  # the token in the path is NOT the ticket's own id -- it's generated before
  # the id is known (the id is only assigned inside the racing log mutate)
  expect_false(grepl(paste0("/", out$id, "/"), uploaded$dest, fixed = TRUE))
})

test_that("eri_feedback errors on a missing attachment path before touching Azure", {
  expect_error(eri_feedback("x", attachment = "definitely/not/a/real/file.yaml"), "not found")
})

test_that("eri_feedback_list surfaces context as a list-column and attachment as a character column", {
  store <- new_yaml_store(list(entries = list(
    list(id = 1L, submitted_at = iso_ago(1), submitted_by = "u", area = "dq",
         status = "submitted", message = "scoped",
         context = list(country = "sdn", disease = "oncho"),
         attachment = "_feedback/attachments/tok/sdn_oncho.yaml"),
    list(id = 2L, submitted_at = iso_ago(1), submitted_by = "u", area = "general",
         status = "submitted", message = "plain, no context/attachment")
  )))
  local_yaml_store(store)

  tbl <- eri_feedback_list(data_con = "mock")
  expect_equal(tbl$attachment, c("_feedback/attachments/tok/sdn_oncho.yaml", NA_character_))
  expect_true(is.list(tbl$context))
  expect_equal(tbl$context[[1]], list(country = "sdn", disease = "oncho"))
  expect_null(tbl$context[[2]])
})

test_that("eri_feedback_list on an empty backlog still has context/attachment columns", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  tbl <- suppressMessages(eri_feedback_list(data_con = "mock"))
  expect_equal(nrow(tbl), 0L)
  expect_true(all(c("context", "attachment") %in% names(tbl)))
})
