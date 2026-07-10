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

  empty_tbl <- tibble::tibble(name = character(), size = numeric(),
                              isdir = logical(), lastModified = Sys.time()[0])

  local_mocked_bindings(
    storage_dir_exists = function(container, path, ...) identical(path, scoped_dir),
    list_storage_files = function(container, path, ...) {
      # Walk country -> disease -> data_source; no measure level (four-axis).
      if (identical(path, ""))               return(tibble::tibble(name = "uga", size = NA, isdir = TRUE, lastModified = Sys.time()))
      if (identical(path, "uga"))            return(tibble::tibble(name = "uga/oncho", size = NA, isdir = TRUE, lastModified = Sys.time()))
      if (identical(path, "uga/oncho"))      return(tibble::tibble(name = "uga/oncho/surveillance", size = NA, isdir = TRUE, lastModified = Sys.time()))
      if (identical(path, "uga/oncho/surveillance")) return(empty_tbl)  # no measures
      if (identical(path, scoped_dir))       return(tibble::tibble(name = names(store), size = 100L, isdir = FALSE, lastModified = Sys.time()))
      empty_tbl
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
  expect_equal(out$data_source, "surveillance")
  expect_equal(out$operation, "eri_approve")
})

# `odk` and `research` are both top-level infra dir names, but below the country
# level they are valid data_sources: an unscoped scan must still surface them.
for (channel in c("odk", "research")) {
  local({
    ch <- channel
    test_that(paste0("unscoped eri_logs enumerates a ", ch, "-channel log"), {
      empty <- tibble::tibble(name = character(), size = numeric(),
                              isdir = logical(), lastModified = Sys.time()[0])
      dir <- paste0("uga/oncho/", ch, "/logs")
      log <- list(
        operation  = "eri_odk_sync", analyst = "test.user",
        timestamp  = "2026-06-09T08:00:00Z",
        parameters = list(country = "uga", disease = "oncho"),
        status     = "success"
      )
      store <- list(); store[[paste0(dir, "/x.yaml")]] <- log

      local_mocked_bindings(
        storage_dir_exists = function(container, path, ...) identical(path, dir),
        list_storage_files = function(container, path, ...) {
          mk <- function(name) tibble::tibble(name = name, size = NA, isdir = TRUE,
                                              lastModified = Sys.time())
          if (identical(path, ""))                       return(mk("uga"))
          if (identical(path, "uga"))                    return(mk("uga/oncho"))
          if (identical(path, "uga/oncho"))              return(mk(paste0("uga/oncho/", ch)))
          if (identical(path, paste0("uga/oncho/", ch))) return(empty)  # no measures
          if (identical(path, dir)) return(tibble::tibble(name = names(store), size = 100L,
                                                          isdir = FALSE, lastModified = Sys.time()))
          empty
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
      expect_equal(out$data_source, ch)
    })
  })
}

test_that("eri_logs discovers five-axis (measure-level) logs and fills data_type", {
  # An approval log under the full {country}/{disease}/{data_source}/{measure}/logs path.
  dir <- "uga/oncho/programmatic/treatment/logs"
  log <- list(
    operation    = "eri_approve", analyst = "test.user",
    started_at   = "2026-06-08T08:00:00Z", completed_at = "2026-06-08T08:00:00Z",
    parameters   = list(country = "uga", disease = "oncho",
                        data_source = "programmatic", data_type = "treatment",
                        period = "2024-06"),
    status       = "success"
  )
  store <- list(); store[[paste0(dir, "/x_eri_approve.yaml")]] <- log
  files <- tibble::tibble(name = names(store), size = 100L, isdir = FALSE,
                          lastModified = Sys.time())

  local_mocked_bindings(
    storage_dir_exists = function(container, path, ...) identical(path, dir),
    list_storage_files = function(container, path, ...) {
      # The source has one measure subdir; its logs/ holds the file.
      if (identical(path, "uga/oncho/programmatic"))
        return(tibble::tibble(name = "uga/oncho/programmatic/treatment", size = NA,
                              isdir = TRUE, lastModified = Sys.time()))
      files[startsWith(files$name, path), , drop = FALSE]
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

  out <- eri_logs("uga", "oncho", "programmatic")
  expect_equal(nrow(out), 1L)
  expect_equal(out$data_source, "programmatic")
  expect_equal(out$data_type, "treatment")
  expect_equal(out$period, "2024-06")
})

test_that("eri_logs fills scoping columns from the path for thin envelopes", {
  # eri_odk_sync-style log whose parameters omit the channel/measure/period.
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
  expect_equal(out$data_source, "odk")  # the channel, recovered from the blob path
  expect_true(is.na(out$data_type))     # four-axis log: no measure level
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
  expect_equal(captured$parameters$data_source, "surveillance")
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

test_that("eri_dq_log writes per-flag index/status/note fields, all open on a fresh run", {
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
    list(data = tibble::tibble(a = 1), log = tibble::tibble(row = integer()), flags = flags),
    class = "dq_result"
  )

  eri_dq_log(res, "uga", "oncho", "surveillance", period = "2024-01")
  expect_equal(captured$flags[[1]]$index, 1L)
  expect_equal(captured$flags[[2]]$index, 2L)
  expect_true(all(vapply(captured$flags, function(f) f$status, character(1L)) == "open"))
})

test_that(".eri_dq_log_write returns the log_path alongside n_flags/status", {
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) invisible(dest),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  flags <- tibble::tibble(row = 1L, column = "Age", value = "250", issue = "out of range")
  res <- structure(
    list(data = tibble::tibble(a = 1), log = tibble::tibble(row = integer()), flags = flags),
    class = "dq_result"
  )

  written <- .eri_dq_log_write(res, "uga", "oncho", "surveillance", period = "2024-01")
  expect_equal(written$n_flags, 1L)
  expect_equal(written$status, "needs_review")
  expect_match(written$log_path, "^uga/oncho/surveillance/logs/")
  expect_length(written$flags, 1L)
})

# --- eri_dq_flag_resolve ----------------------------------------------------

test_that("eri_dq_flag_resolve updates one flag's status/note without touching others", {
  path  <- "uga/oncho/surveillance/logs/20260604_120000_dq_flags_2024-01.yaml"
  entry <- list(
    operation = "dq_flags", status = "needs_review",
    flags = list(
      list(index = 1, column = "Age", status = "open", note = NA_character_,
          resolved_by = NA_character_, resolved_at = NA_character_),
      list(index = 2, column = "Sex", status = "open", note = NA_character_,
          resolved_by = NA_character_, resolved_at = NA_character_)
    )
  )
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
    .eri_analyst_id = function(...) "tester",
    .package = "erifunctions"
  )

  flag_id <- paste0(path, "::2")
  res <- eri_dq_flag_resolve(flag_id, "fixed", note = "corrected upstream")
  expect_true(res)
  expect_equal(captured$flags[[1]]$status, "open")       # untouched
  expect_equal(captured$flags[[2]]$status, "fixed")
  expect_equal(captured$flags[[2]]$note, "corrected upstream")
  expect_equal(captured$flags[[2]]$resolved_by, "tester")
  expect_false(is.na(captured$flags[[2]]$resolved_at))
})

test_that("eri_dq_flag_resolve rejects a malformed flag_id and an unknown index", {
  expect_error(eri_dq_flag_resolve("not-a-valid-id", "fixed"), "must be")

  path  <- "uga/oncho/surveillance/logs/x.yaml"
  entry <- list(flags = list(list(index = 1, status = "open")))
  local_mocked_bindings(
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(entry, dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  expect_error(eri_dq_flag_resolve(paste0(path, "::99"), "fixed"), "No flag with index")
})

test_that("eri_dq_flag_resolve gives a clear error against a pre-per-flag-triage log entry", {
  path  <- "uga/oncho/surveillance/logs/old.yaml"
  # An entry written before this feature: flags exist but carry none of the
  # new index/status/note/resolved_by/resolved_at fields.
  entry <- list(
    operation = "dq_flags", status = "needs_review",
    flags = list(list(row = 1L, column = "Age", value = "250", issue = "out of range"))
  )
  local_mocked_bindings(
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(entry, dest); invisible(dest)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  expect_error(eri_dq_flag_resolve(paste0(path, "::1"), "fixed"), "predates per-flag triage")
})

test_that("eri_logs_resolve degrades gracefully against a pre-per-flag-triage / flag-less log entry", {
  path  <- "uga/oncho/surveillance/logs/old.yaml"
  entry <- make_op_log()   # no $flags field at all, matches a plain op-log (e.g. eri_approve's own)
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

  res <- eri_logs_resolve(path)   # no note, no per-flag statuses to summarize from
  expect_true(res)
  expect_true(is.na(captured$triage$note))   # blank, exactly like before this feature existed
})

test_that("eri_logs_resolve auto-summarizes from per-flag statuses when no note is given", {
  path  <- "uga/oncho/surveillance/logs/x.yaml"
  entry <- list(
    operation = "dq_flags", status = "needs_review",
    flags = list(
      list(index = 1, status = "fixed"),
      list(index = 2, status = "not_important"),
      list(index = 3, status = "fixed")
    )
  )
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

  eri_logs_resolve(path)   # no note passed
  expect_match(captured$triage$note, "fixed")
  expect_match(captured$triage$note, "not important")
})

test_that("eri_logs_resolve still accepts an explicit note over the auto-summary", {
  path  <- "uga/oncho/surveillance/logs/x.yaml"
  entry <- list(flags = list(list(index = 1, status = "fixed")))
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

  eri_logs_resolve(path, note = "my own summary")
  expect_equal(captured$triage$note, "my own summary")
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
