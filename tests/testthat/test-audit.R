#### Tests for eri_audit() and its event-exploder ####

# --- .eri_audit_events(): fixture YAMLs for each envelope type --------------

test_that(".eri_audit_events turns a generic op-log with files into one event", {
  entry <- list(
    operation = "eri_ingest", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
    parameters = list(country = "atlantis", disease = "malaria", data_source = "surveillance",
                      data_type = "case", period = "2024-01"),
    status = "success", files = list("atlantis/malaria/surveillance/case/staged/x.parquet")
  )
  out <- .eri_audit_events(entry, "atlantis/malaria/surveillance/case/logs/f.yaml")
  expect_length(out, 1L)
  expect_equal(out[[1]]$event, "eri_ingest")
  expect_equal(out[[1]]$timestamp, "2026-06-01T10:00:00Z")
  expect_equal(out[[1]]$actor, "u")
  expect_match(out[[1]]$detail, "x.parquet", fixed = TRUE)
  expect_equal(out[[1]]$country, "atlantis")
  expect_equal(out[[1]]$period, "2024-01")
})

test_that(".eri_audit_events surfaces an error entry's message as the detail", {
  entry <- list(operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
               parameters = list(country = "uga", disease = "oncho", data_source = "surveillance",
                                 period = "2024-01"),
               status = "error", error = "No staged files found matching '2024-01'.")
  out <- .eri_audit_events(entry, "uga/oncho/surveillance/logs/f.yaml")
  expect_length(out, 1L)
  expect_equal(out[[1]]$event, "eri_approve")
  expect_match(out[[1]]$detail, "No staged files")
})

test_that(".eri_audit_events shows an eri_split_cmr's plan as the detail", {
  entry <- list(
    operation = "eri_split_cmr", analyst = "u", started_at = "2026-06-01T09:00:00Z",
    parameters = list(country = "atlantis", period = "202607"),
    status = "success",
    plan = list(
      list(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
           dest = "atlantis/oncho/programmatic/treatment/staged/x_rb_treatment.parquet", n_rows = 3L)
    )
  )
  out <- .eri_audit_events(entry, "atlantis/rblf/cmr/logs/f.yaml")
  expect_length(out, 1L)
  expect_equal(out[[1]]$event, "eri_split_cmr")
  expect_match(out[[1]]$detail, "RB Treatment -> x_rb_treatment.parquet (3 rows)", fixed = TRUE)
})

test_that(".eri_audit_events shows eri_approve_cmr's measures and dq_reviewed cross-refs", {
  entry <- list(
    operation = "eri_approve_cmr", analyst = "u", timestamp = "2026-06-01T11:00:00Z",
    parameters = list(country = "atlantis", period = "202607"),
    status = "success",
    measures = list("oncho/treatment"),
    dq_reviewed = list("atlantis/oncho/programmatic/treatment/logs/dq_flags_202607.yaml")
  )
  out <- .eri_audit_events(entry, "atlantis/rblf/cmr/logs/f.yaml")
  expect_length(out, 1L)
  expect_equal(out[[1]]$event, "eri_approve_cmr")
  expect_match(out[[1]]$detail, "oncho/treatment", fixed = TRUE)
  expect_match(out[[1]]$detail, "dq_reviewed: dq_flags_202607.yaml", fixed = TRUE)
  expect_false(out[[1]]$forced)
})

test_that(".eri_audit_events marks a forced eri_approve_cmr entry and shows its justification/bypassed detail", {
  entry <- list(
    operation = "eri_approve_cmr", analyst = "u", timestamp = "2026-06-01T11:00:00Z",
    parameters = list(country = "atlantis", period = "202607"),
    status = "success", measures = list("oncho/treatment"),
    forced = TRUE, justification = "Known template quirk.",
    bypassed = list(list(disease = "oncho", data_type = "treatment",
                        issue = "3 unresolved DQ flag(s)", log_path = "x/y/logs/dq.yaml"))
  )
  out <- .eri_audit_events(entry, "atlantis/rblf/cmr/logs/f.yaml")
  expect_length(out, 1L)
  expect_true(out[[1]]$forced)
  expect_match(out[[1]]$detail, "justification: Known template quirk.", fixed = TRUE)
  expect_match(out[[1]]$detail, "bypassed: oncho/treatment (3 unresolved DQ flag(s))", fixed = TRUE)
})

test_that(".eri_audit_events renders a forced-bypass triage block as 'log_resolved (forced bypass)'", {
  entry <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "needs_review", n_flags = 1L,
    flags = list(list(index = 1, status = "open", resolved_at = NA_character_,
                      resolved_by = NA_character_, note = NA_character_)),
    triage = list(handled = TRUE, handled_by = "maintainer", handled_at = "2026-06-03T10:00:00Z",
                 note = "Bypassed by a forced approval.", forced = TRUE)
  )
  out <- .eri_audit_events(entry, "atlantis/oncho/programmatic/treatment/logs/f.yaml")
  events <- vapply(out, function(e) e$event, character(1L))
  expect_true("log_resolved (forced bypass)" %in% events)
  bypass_event <- out[[which(events == "log_resolved (forced bypass)")]]
  expect_true(bypass_event$forced)
})

test_that(".eri_audit_events keeps a genuine (non-forced) triage block as plain 'log_resolved'", {
  entry <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
    parameters = list(country = "uga", disease = "oncho", data_source = "surveillance"),
    status = "success",
    triage = list(handled = TRUE, handled_by = "u", handled_at = "2026-06-02T10:00:00Z",
                 note = "genuinely resolved", forced = FALSE)
  )
  out <- .eri_audit_events(entry, "uga/oncho/surveillance/logs/f.yaml")
  events <- vapply(out, function(e) e$event, character(1L))
  expect_true("log_resolved" %in% events)
  expect_false(any(grepl("forced", events)))
})

test_that(".eri_audit_events produces one dq_flags event and no flag_resolved rows for an unresolved entry", {
  entry <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    schema_source = "bundled", status = "needs_review", n_flags = 2L,
    flags = list(
      list(index = 1, status = "open", resolved_at = NA_character_, resolved_by = NA_character_, note = NA_character_),
      list(index = 2, status = "open", resolved_at = NA_character_, resolved_by = NA_character_, note = NA_character_)
    )
  )
  out <- .eri_audit_events(entry, "atlantis/oncho/programmatic/treatment/logs/f.yaml")
  expect_length(out, 1L)
  expect_equal(out[[1]]$event, "dq_flags")
  expect_match(out[[1]]$detail, "2 flags")
  expect_match(out[[1]]$detail, "schema: bundled", fixed = TRUE)
})

test_that(".eri_audit_events adds one flag_resolved event per resolved flag, none for still-open ones", {
  entry <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "needs_review", n_flags = 2L,
    flags = list(
      list(index = 1, status = "fixed", resolved_by = "dana", resolved_at = "2026-06-02T08:00:00Z",
           note = "corrected district spelling"),
      list(index = 2, status = "open", resolved_at = NA_character_, resolved_by = NA_character_, note = NA_character_)
    )
  )
  out <- .eri_audit_events(entry, "atlantis/oncho/programmatic/treatment/logs/f.yaml")
  expect_length(out, 2L)  # 1 dq_flags + 1 flag_resolved (not 2 -- flag #2 is still open)
  resolved <- out[[2]]
  expect_equal(resolved$event, "flag_resolved")
  expect_equal(resolved$timestamp, "2026-06-02T08:00:00Z")
  expect_equal(resolved$actor, "dana")
  expect_match(resolved$detail, "flag #1 -> fixed", fixed = TRUE)
  expect_match(resolved$detail, "corrected district spelling", fixed = TRUE)
})

test_that(".eri_audit_events appends a log_resolved event when a triage block is present, on any entry type", {
  entry <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "needs_review", n_flags = 0L, flags = list(),
    triage = list(handled = TRUE, handled_by = "maintainer", handled_at = "2026-06-03T10:00:00Z",
                 note = "all clean")
  )
  out <- .eri_audit_events(entry, "atlantis/oncho/programmatic/treatment/logs/f.yaml")
  expect_length(out, 2L)  # dq_flags + log_resolved
  resolved <- out[[2]]
  expect_equal(resolved$event, "log_resolved")
  expect_equal(resolved$actor, "maintainer")
  expect_equal(resolved$detail, "all clean")
})

test_that(".eri_audit_events ignores an untriaged (handled = FALSE) entry's triage block", {
  entry <- list(operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
               parameters = list(country = "uga", disease = "oncho", data_source = "surveillance"),
               status = "success")
  out <- .eri_audit_events(entry, "uga/oncho/surveillance/logs/f.yaml")
  expect_length(out, 1L)
  expect_false(any(vapply(out, function(e) e$event, character(1L)) == "log_resolved"))
})

test_that(".eri_audit_events produces zero events for an unrecognized envelope shape (no operation/parameters/steps/flags)", {
  # A malformed/future-shaped entry -- must NOT fall through to a garbage
  # all-NA event row (the bug this test guards against: coalescing a missing
  # `operation` to NA_character_ before the not-null check made the generic
  # branch's condition always true).
  entry <- list(status = "weird_future_shape")
  out <- .eri_audit_events(entry, "atlantis/x/y/logs/f.yaml")
  expect_length(out, 0L)
})

test_that(".eri_audit_events produces dq_flags + every flag_resolved + log_resolved together for one fully-triaged entry", {
  entry <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "needs_review", n_flags = 2L,
    flags = list(
      list(index = 1, status = "fixed", resolved_by = "dana", resolved_at = "2026-06-02T08:00:00Z", note = NA_character_),
      list(index = 2, status = "not_important", resolved_by = "dana", resolved_at = "2026-06-02T08:01:00Z", note = NA_character_)
    ),
    triage = list(handled = TRUE, handled_by = "maintainer", handled_at = "2026-06-03T10:00:00Z",
                 note = "2 fixed, 1 not important")
  )
  out <- .eri_audit_events(entry, "atlantis/oncho/programmatic/treatment/logs/f.yaml")
  events <- vapply(out, function(e) e$event, character(1L))
  expect_equal(events, c("dq_flags", "flag_resolved", "flag_resolved", "log_resolved"))
})

# --- eri_audit(): end-to-end against a mocked backlog -----------------------

local_audit_store <- function(store) {
  files <- tibble::tibble(name = names(store), size = 100L, isdir = FALSE,
                          lastModified = Sys.time())
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    list_storage_files = function(container, path, ...)
      files[startsWith(files$name, path), , drop = FALSE],
    storage_download = function(container, src, dest, ...) {
      yaml::write_yaml(store[[src]], dest); invisible(dest)
    },
    .package = "AzureStor",
    .env = parent.frame()
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions",
    .env = parent.frame()
  )
}

test_that("eri_audit returns a chronological (oldest-first) timeline across multiple logs", {
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/20260601_split.yaml"]] <- list(
    operation = "eri_split_cmr", analyst = "u", started_at = "2026-06-01T09:00:00Z",
    parameters = list(country = "atlantis", period = "202607"), status = "success",
    plan = list(list(sheet = "RB Treatment", dest = "x_rb_treatment.parquet", n_rows = 3L))
  )
  store[["atlantis/oncho/programmatic/treatment/logs/20260601_dq.yaml"]] <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "needs_review", n_flags = 1L,
    flags = list(list(index = 1, status = "fixed", resolved_by = "dana",
                      resolved_at = "2026-06-02T08:00:00Z", note = NA_character_))
  )
  store[["atlantis/oncho/programmatic/treatment/logs/20260603_approve.yaml"]] <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-06-03T12:00:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "success", files = list("atlantis/oncho/programmatic/treatment/processed/x.parquet")
  )
  local_audit_store(store)

  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment")
  expect_s3_class(out, "eri_audit_trail")
  expect_s3_class(out, "tbl_df")
  # 1 split + 1 dq_flags + 1 flag_resolved + 1 eri_approve = 4 events
  expect_equal(nrow(out), 4L)
  expect_equal(out$event, c("eri_split_cmr", "dq_flags", "flag_resolved", "eri_approve"))  # oldest first
  expect_true(all(out$period == "202607"))
})

test_that("eri_audit filters by period", {
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202606"),
    status = "success"
  )
  store[["atlantis/oncho/programmatic/treatment/logs/b.yaml"]] <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-07-01T10:00:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "success"
  )
  local_audit_store(store)

  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment", period = "202607")
  expect_equal(nrow(out), 1L)
  expect_equal(out$period, "202607")
})

test_that("eri_audit returns a typed empty trail when there are no log directories", {
  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(get_azure_storage_connection = function(...) "mock_con", .package = "erifunctions")

  out <- suppressMessages(eri_audit("nowhere"))
  expect_s3_class(out, "eri_audit_trail")
  expect_equal(nrow(out), 0L)
})

test_that("print.eri_audit_trail renders without error for both empty and populated trails", {
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    status = "success"
  )
  local_audit_store(store)
  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment")
  rendered <- paste(cli::cli_fmt(print(out)), collapse = " ")
  expect_match(rendered, "Audit trail")
  expect_match(rendered, "eri_approve")

  empty <- .eri_audit_empty()
  expect_no_error(cli::cli_fmt(print(empty)))
})

test_that("eri_audit carries source_hash from the entry onto every event row", {
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "dq_flags", analyst = "u", timestamp = "2026-06-01T09:30:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"),
    source_hash = "abc123", status = "needs_review", n_flags = 1L,
    flags = list(list(index = 1, status = "fixed", resolved_by = "dana",
                      resolved_at = "2026-06-02T08:00:00Z", note = NA_character_))
  )
  local_audit_store(store)

  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment")
  expect_true(all(out$source_hash == "abc123"))
})

test_that(".eri_audit_parse_ts parses both whole- and fractional-second ISO-8601 timestamps", {
  parsed <- .eri_audit_parse_ts(c("2026-06-01T12:00:01Z", "2026-06-01T12:00:01.500Z"))
  expect_false(anyNA(parsed))
  expect_true(parsed[2] > parsed[1])
})

test_that("eri_audit sorts a fractional-second timestamp correctly relative to whole-second ones", {
  # A raw string sort would put "...12:00:01.500Z" BEFORE "...12:00:01Z", even
  # though it is chronologically AFTER -- "." sorts before "Z" in ASCII. Keyed
  # so the LATER event is listed/read FIRST (file "a.yaml" before "b.yaml"):
  # if sorting silently no-ops (e.g. every timestamp fails to parse), the
  # untouched read order would put the later event first, and this test would
  # catch that -- unlike a store already in chronological order, which cannot
  # tell a working sort from a sort that quietly does nothing.
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T12:00:01.500Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"), status = "success"
  )
  store[["atlantis/oncho/programmatic/treatment/logs/b.yaml"]] <- list(
    operation = "eri_split_cmr", analyst = "u", started_at = "2026-06-01T12:00:01Z",
    parameters = list(country = "atlantis", period = "202607"), status = "success"
  )
  local_audit_store(store)

  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment")
  expect_equal(out$event, c("eri_split_cmr", "eri_approve"))
})

test_that("eri_audit informs which periods were actually found when the period filter matches nothing", {
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "eri_approve", analyst = "u", completed_at = "2026-06-01T10:00:00Z",
    parameters = list(country = "atlantis", disease = "oncho", data_source = "programmatic",
                      data_type = "treatment", period = "202607"), status = "success"
  )
  local_audit_store(store)

  expect_message(
    out <- eri_audit("atlantis", "oncho", "programmatic", "treatment", period = "2024-06"),
    "202607"
  )
  expect_equal(nrow(out), 0L)
})

test_that("eri_audit carries the forced column through and print.eri_audit_trail renders it prominently", {
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "eri_approve_cmr", analyst = "u", timestamp = "2026-06-01T11:00:00Z",
    parameters = list(country = "atlantis", period = "202607"), status = "success",
    measures = list("oncho/treatment"), forced = TRUE, justification = "Deadline override.",
    bypassed = list(list(disease = "oncho", data_type = "treatment", issue = "3 unresolved DQ flag(s)",
                        log_path = NA_character_))
  )
  local_audit_store(store)

  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment")
  expect_true(out$forced[out$event == "eri_approve_cmr"])

  rendered <- paste(cli::cli_fmt(print(out)), collapse = " ")
  expect_match(rendered, "FORCED")
  expect_match(rendered, "Deadline override.", fixed = TRUE)
})

test_that("print.eri_audit_trail does not crash on a forced justification containing literal braces", {
  # A justification is free text a DA types -- e.g. quoting a template
  # placeholder or a formula -- and could easily contain "{"/"}". The forced
  # row is rendered by building the whole line as a plain string first; it
  # must be interpolated as a glue VARIABLE, not passed as the glue template
  # itself, or a stray brace crashes the entire print (not just that row).
  store <- list()
  store[["atlantis/oncho/programmatic/treatment/logs/a.yaml"]] <- list(
    operation = "eri_approve_cmr", analyst = "u", timestamp = "2026-06-01T11:00:00Z",
    parameters = list(country = "atlantis", period = "202607"), status = "success",
    measures = list("oncho/treatment"), forced = TRUE,
    justification = "Matches the {district} placeholder in last month's template.",
    bypassed = list(list(disease = "oncho", data_type = "treatment", issue = "3 unresolved DQ flag(s)",
                        log_path = NA_character_))
  )
  local_audit_store(store)

  out <- eri_audit("atlantis", "oncho", "programmatic", "treatment")
  expect_no_error(rendered <- paste(cli::cli_fmt(print(out)), collapse = " "))
  expect_match(rendered, "district", fixed = TRUE)
})
