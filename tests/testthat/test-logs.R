#### Tests for the log triage backlog (eri_logs / eri_dq_log / eri_logs_resolve) ####

make_op_log <- function(operation = "eri_approve", status = "error",
                        analyst = "test.user", country = "uga", disease = "oncho",
                        data_type = "surveillance", period = "2024-01",
                        error = "No staged files found matching '2024-01'.",
                        timestamp = "2026-06-04T12:00:00Z", triage = NULL) {
  e <- list(
    operation    = operation,
    analyst      = analyst,
    started_at   = timestamp,
    completed_at = timestamp,
    parameters   = list(country = country, disease = disease,
                        data_type = data_type, period = period),
    status       = status
  )
  if (!is.null(error))  e$error  <- error
  if (!is.null(triage)) e$triage <- triage
  e
}

make_dq_log <- function(n_flags = 2L, status = "needs_review",
                        country = "uga", disease = "oncho",
                        data_type = "surveillance", period = "2024-01",
                        timestamp = "2026-06-05T09:00:00Z") {
  list(
    operation     = "dq_flags",
    analyst       = "test.user",
    timestamp     = timestamp,
    parameters    = list(country = country, disease = disease,
                         data_type = data_type, period = period),
    status        = status,
    n_flags       = n_flags,
    n_corrections = 3L,
    flags = lapply(seq_len(n_flags), function(i)
      list(row = i, column = "Age", value = "250", issue = "out of range"))
  )
}

scoped_dir <- "uga/oncho/surveillance/logs"

# --- eri_logs: read + flatten ----------------------------------------------

test_that("eri_logs reads op-log + dq-flag YAMLs into a backlog tibble", {
  store <- list()
  store[[paste0(scoped_dir, "/20260604_120000_eri_approve_2024-01.yaml")]] <- make_op_log()
  store[[paste0(scoped_dir, "/20260605_090000_dq_flags_2024-01.yaml")]]    <- make_dq_log()
  files <- tibble::tibble(name = names(store), size = 100L, isdir = FALSE,
                          lastModified = Sys.time())

  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    list_storage_files = function(container, path, ...)
      files[startsWith(files$name, path), , drop = FALSE],
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(store[[src]], dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_logs("uga", "oncho", "surveillance")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 2L)
  expect_setequal(out$operation, c("eri_approve", "dq_flags"))
  expect_true(all(c("error", "needs_review") %in% out$status))
  # newest first (2026-06-05 before 2026-06-04)
  expect_equal(out$operation[1], "dq_flags")
  expect_equal(out$summary[out$operation == "dq_flags"], "2 flags")
  expect_equal(out$n_issues[out$operation == "dq_flags"], 2L)
  # error op-log surfaces its message as the summary
  expect_match(out$summary[out$operation == "eri_approve"], "No staged files")
})

test_that("eri_logs filters by status", {
  store <- list()
  store[[paste0(scoped_dir, "/a_eri_approve.yaml")]] <- make_op_log()
  store[[paste0(scoped_dir, "/b_dq_flags.yaml")]]    <- make_dq_log()
  files <- tibble::tibble(name = names(store), size = 100L, isdir = FALSE,
                          lastModified = Sys.time())

  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    list_storage_files = function(container, path, ...)
      files[startsWith(files$name, path), , drop = FALSE],
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(store[[src]], dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_logs("uga", "oncho", "surveillance", status = "error")
  expect_equal(nrow(out), 1L)
  expect_equal(out$operation, "eri_approve")
})

test_that("eri_logs hides handled items unless include_handled = TRUE", {
  handled <- make_op_log(
    triage = list(handled = TRUE, handled_by = "someone",
                  handled_at = "2026-06-06T08:00:00Z", note = "done")
  )
  store <- list()
  store[[paste0(scoped_dir, "/handled_eri_approve.yaml")]] <- handled
  files <- tibble::tibble(name = names(store), size = 100L, isdir = FALSE,
                          lastModified = Sys.time())

  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    list_storage_files = function(container, path, ...)
      files[startsWith(files$name, path), , drop = FALSE],
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(store[[src]], dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  expect_equal(nrow(eri_logs("uga", "oncho", "surveillance")), 0L)
  out <- eri_logs("uga", "oncho", "surveillance", include_handled = TRUE)
  expect_equal(nrow(out), 1L)
  expect_true(out$handled)
  expect_equal(out$handled_by, "someone")
})

test_that("eri_logs enumerates the tree when unscoped", {
  logfile <- paste0(scoped_dir, "/20260604_120000_eri_approve.yaml")
  store <- list(); store[[logfile]] <- make_op_log(period = NULL)

  local_mocked_bindings(
    storage_dir_exists = function(container, path, ...) identical(path, scoped_dir),
    list_storage_files = function(container, path, ...) {
      if (identical(path, ""))    return(tibble::tibble(name = "uga", size = NA, isdir = TRUE, lastModified = Sys.time()))
      if (identical(path, "uga")) return(tibble::tibble(name = "uga/oncho", size = NA, isdir = TRUE, lastModified = Sys.time()))
      if (identical(path, scoped_dir)) return(tibble::tibble(name = names(store), size = 100L, isdir = FALSE, lastModified = Sys.time()))
      tibble::tibble(name = character(), size = numeric(), isdir = logical(), lastModified = Sys.time()[0])
    },
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(store[[src]], dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_logs()
  expect_equal(nrow(out), 1L)
  expect_equal(out$country, "uga")
  expect_equal(out$operation, "eri_approve")
})

test_that("eri_logs fills scoping columns from the path for thin envelopes", {
  # eri_odk_sync-style log whose parameters omit data_type/period.
  dir  <- "uga/oncho/odk/logs"
  thin <- list(
    operation  = "eri_odk_sync", analyst = "test.user",
    timestamp  = "2026-06-07T08:00:00Z",
    parameters = list(country = "uga", disease = "oncho"),
    status     = "success"
  )
  store <- list(); store[[paste0(dir, "/x_eri_odk_sync.yaml")]] <- thin
  files <- tibble::tibble(name = names(store), size = 100L, isdir = FALSE,
                          lastModified = Sys.time())

  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    list_storage_files = function(container, path, ...)
      files[startsWith(files$name, path), , drop = FALSE],
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(store[[src]], dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_logs("uga", "oncho", "odk")
  expect_equal(nrow(out), 1L)
  expect_equal(out$data_type, "odk")   # recovered from the blob path
  expect_equal(out$country, "uga")
  expect_equal(out$disease, "oncho")
})

# --- eri_dq_log ------------------------------------------------------------

test_that("eri_dq_log writes a dq_flags envelope with the flags", {
  captured <- NULL
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      captured <<- yaml::read_yaml(src); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  flags <- tibble::tibble(row = c(1L, 2L), column = c("Age", "Sex"),
                          value = c("250", "x"),
                          issue = c("out of range", "not allowed"))
  res <- structure(
    list(data = tibble::tibble(a = 1),
         log  = tibble::tibble(row = integer()),
         flags = flags),
    class = "dq_result"
  )

  n <- eri_dq_log(res, "uga", "oncho", "surveillance", period = "2024-01")
  expect_equal(n, 2L)
  expect_equal(captured$operation, "dq_flags")
  expect_equal(captured$status, "needs_review")
  expect_equal(captured$n_flags, 2L)
  expect_length(captured$flags, 2L)
  expect_equal(captured$parameters$country, "uga")
  expect_equal(captured$flags[[1]]$column, "Age")
})

test_that("eri_dq_log records a clean status when there are no flags", {
  captured <- NULL
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      captured <<- yaml::read_yaml(src); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  res <- structure(
    list(data = tibble::tibble(a = 1),
         log  = tibble::tibble(row = integer()),
         flags = tibble::tibble(row = integer(), column = character(),
                                value = character(), issue = character())),
    class = "dq_result"
  )

  n <- eri_dq_log(res, "uga", "oncho", "surveillance")
  expect_equal(n, 0L)
  expect_equal(captured$status, "clean")
})

test_that("eri_dq_log rejects non-dq_result input", {
  expect_error(
    eri_dq_log(list(flags = 1), "uga", "oncho", "surveillance"),
    "dq_result"
  )
})

# --- eri_logs_resolve ------------------------------------------------------

test_that("eri_logs_resolve adds a triage block and preserves the record", {
  path  <- paste0(scoped_dir, "/20260604_120000_eri_approve_2024-01.yaml")
  entry <- make_op_log()
  captured <- NULL

  local_mocked_bindings(
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(entry, dest); invisible(dest)
    },
    storage_upload = function(container, src, dest, ...) {
      captured <<- yaml::read_yaml(src); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  res <- eri_logs_resolve(path, note = "Re-ran after the source fixed the file.")
  expect_true(res)
  expect_true(captured$triage$handled)
  expect_equal(captured$triage$note, "Re-ran after the source fixed the file.")
  expect_equal(captured$operation, "eri_approve")   # original record preserved
  expect_equal(captured$status, "error")
})
