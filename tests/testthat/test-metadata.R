#### Tests for the concurrency-safe metadata store (ADR-0002) ####

# A minimal stand-in for the httr response object that AzureStor returns when
# `http_status_handler = "pass"`: a list with $status_code, $content (raw body)
# and $headers (named, lower-cased).
fake_resp <- function(status, body = "", etag = NULL) {
  list(
    status_code = as.integer(status),
    content     = charToRaw(body),
    headers     = if (is.null(etag)) list() else list(etag = etag)
  )
}

# --- .eri_yaml_read_versioned -------------------------------------------------

test_that(".eri_yaml_read_versioned returns the default and NULL etag on 404", {
  local_mocked_bindings(
    do_container_op = function(...) fake_resp(404L),
    .package = "AzureStor"
  )
  out <- erifunctions:::.eri_yaml_read_versioned("con", "p.yaml",
                                                 default = list(entries = list()))
  expect_equal(out$data, list(entries = list()))
  expect_null(out$etag)
})

test_that(".eri_yaml_read_versioned parses the body and captures the ETag on 200", {
  body <- yaml::as.yaml(list(entries = list(list(path = "a"))))
  local_mocked_bindings(
    do_container_op = function(...) fake_resp(200L, body = body, etag = "\"v1\""),
    .package = "AzureStor"
  )
  out <- erifunctions:::.eri_yaml_read_versioned("con", "p.yaml")
  expect_equal(out$data$entries[[1]]$path, "a")
  expect_equal(out$etag, "\"v1\"")
})

# --- .eri_yaml_write_conditional ----------------------------------------------

test_that(".eri_yaml_write_conditional sends If-None-Match:* to create (NULL etag)", {
  seen <- NULL
  local_mocked_bindings(
    do_container_op = function(container, operation, headers = list(), ...) {
      seen <<- headers
      fake_resp(201L)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_create_azure_dir = function(...) invisible(NULL),
    .package = "erifunctions"
  )
  ok <- erifunctions:::.eri_yaml_write_conditional("con", "d/p.yaml",
                                                   list(entries = list()), etag = NULL)
  expect_true(ok)
  expect_equal(seen[["If-None-Match"]], "*")
  expect_null(seen[["If-Match"]])
})

test_that(".eri_yaml_write_conditional sends If-Match for an update and reports 412 conflicts", {
  seen <- NULL
  local_mocked_bindings(
    do_container_op = function(container, operation, headers = list(), ...) {
      seen <<- headers
      fake_resp(412L)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_create_azure_dir = function(...) invisible(NULL),
    .package = "erifunctions"
  )
  ok <- erifunctions:::.eri_yaml_write_conditional("con", "d/p.yaml",
                                                   list(entries = list()), etag = "\"v1\"")
  expect_false(ok)                       # conflict -> caller retries
  expect_equal(seen[["If-Match"]], "\"v1\"")
})

# --- .eri_blob_metadata_con (ADLS Gen2 -> blob routing, ADR-0016) -------------

test_that(".eri_blob_metadata_con routes an ADLS (dfs) container to the blob endpoint", {
  seen_url <- NULL; seen_name <- NULL
  local_mocked_bindings(
    blob_endpoint = function(endpoint, ...) {
      seen_url <<- endpoint
      structure(list(url = endpoint), class = "blob_endpoint")
    },
    storage_container = function(endpoint, name) {
      seen_name <<- name
      structure(list(endpoint = endpoint, name = name),
                class = c("blob_container", "storage_container"))
    },
    .package = "AzureStor"
  )
  adls <- structure(
    list(
      endpoint = structure(
        list(url = "https://eridev.dfs.core.windows.net/",
             token = "T", key = NULL, sas = NULL),
        class = "adls_endpoint"),
      name = "data"),
    class = c("adls_filesystem", "storage_container"))

  out <- erifunctions:::.eri_blob_metadata_con(adls)
  expect_equal(seen_url, "https://eridev.blob.core.windows.net/")  # dfs host -> blob host
  expect_equal(seen_name, "data")                                  # same filesystem
  expect_s3_class(out, "blob_container")
})

test_that(".eri_blob_metadata_con leaves a non-ADLS container unchanged", {
  expect_identical(erifunctions:::.eri_blob_metadata_con("con"), "con")   # test double
  blob <- structure(list(name = "data"), class = c("blob_container", "storage_container"))
  expect_identical(erifunctions:::.eri_blob_metadata_con(blob), blob)     # already blob
})

# --- .eri_yaml_update (retry / re-apply) --------------------------------------

test_that(".eri_yaml_update commits the mutated value when there is no conflict", {
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)

  erifunctions:::.eri_yaml_update("con", "p.yaml", function(d) {
    d$entries <- c(d$entries, list(list(path = "mine")))
    d
  }, default = list(entries = list()))

  expect_length(store$data$entries, 1L)
  expect_equal(store$data$entries[[1]]$path, "mine")
})

test_that(".eri_yaml_update re-reads and re-applies after a 412, losing no entry", {
  store <- new_yaml_store(list(entries = list()))
  # On the first write a *concurrent* writer commits {path: other}; our write
  # then 412s. The retry must re-read that and add ours on top.
  local_yaml_store(store, concurrent = function(d) {
    d$entries <- c(d$entries, list(list(path = "other")))
    d
  })
  store$conflict_once <- TRUE

  erifunctions:::.eri_yaml_update("con", "p.yaml", function(d) {
    if (is.null(d$entries)) d$entries <- list()
    d$entries <- c(d$entries, list(list(path = "mine")))
    d
  }, default = list(entries = list()))

  paths <- vapply(store$data$entries, function(e) e$path, character(1))
  expect_setequal(paths, c("other", "mine"))   # neither writer was clobbered
})

test_that(".eri_yaml_update aborts after exhausting retries", {
  local_mocked_bindings(
    .eri_yaml_read_versioned = function(con, path, default = list()) {
      list(data = default, etag = "stale")
    },
    .eri_yaml_write_conditional = function(con, path, data, etag) FALSE,  # always conflicts
    .package = "erifunctions"
  )
  expect_error(
    erifunctions:::.eri_yaml_update("con", "p.yaml", function(d) d, retries = 2L),
    "concurrent-write retries"
  )
})

# --- .eri_catalog_entry_from_path (rebuild path parser) -----------------------

test_that(".eri_catalog_entry_from_path parses a five-axis processed path", {
  e <- erifunctions:::.eri_catalog_entry_from_path(
    "uga/oncho/programmatic/treatment/processed/2024_06.parquet"
  )
  expect_equal(e$country, "uga")
  expect_equal(e$disease, "oncho")
  expect_equal(e$data_source, "programmatic")
  expect_equal(e$data_type, "treatment")
  expect_equal(e$layer, "processed")
  expect_equal(e$period, "2024_06")
  expect_equal(e$registered_by, "rebuilt")
})

test_that(".eri_catalog_entry_from_path parses a legacy four-axis path with NA data_type", {
  e <- erifunctions:::.eri_catalog_entry_from_path(
    "dr/malaria/surveillance/processed/2024_W01.parquet"
  )
  expect_equal(e$data_source, "surveillance")
  expect_true(is.na(e$data_type))
})

test_that(".eri_catalog_entry_from_path ignores non-processed and non-parquet paths", {
  expect_null(erifunctions:::.eri_catalog_entry_from_path("uga/oncho/surveillance/raw/x.parquet"))
  expect_null(erifunctions:::.eri_catalog_entry_from_path("uga/oncho/surveillance/processed/x.csv"))
  expect_null(erifunctions:::.eri_catalog_entry_from_path("_catalog/data_catalog.yaml"))
  expect_null(erifunctions:::.eri_catalog_entry_from_path("spatial/foo/processed/a/b.parquet"))
})

# --- eri_catalog_rebuild ------------------------------------------------------

test_that("eri_catalog_rebuild reconstructs the catalog from the processed listing", {
  listing <- c(
    "uga/oncho/programmatic/treatment/processed/2024_06.parquet",
    "dr/malaria/surveillance/processed/2024_W01.parquet",
    "uga/oncho/surveillance/raw/skip.parquet",          # not processed -> skip
    "_catalog/data_catalog.yaml"                         # metadata -> skip
  )
  store <- new_yaml_store(list(entries = list()))
  local_yaml_store(store)
  local_mocked_bindings(
    list_storage_files = function(...) listing,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_catalog_read = function(data_con) store$data,   # for the closing query
    .package = "erifunctions"
  )

  suppressMessages(eri_catalog_rebuild(data_con = "mock_con"))

  expect_length(store$data$entries, 2L)
  paths <- vapply(store$data$entries, function(e) e$path, character(1))
  expect_setequal(paths, listing[1:2])
})
