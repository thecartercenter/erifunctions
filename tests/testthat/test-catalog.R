#### Tests for data catalog ####

# --- helpers ------------------------------------------------------------------

make_catalog <- function(...) list(entries = list(...))

make_entry <- function(
    path      = "uga/oncho/surveillance/processed/2024_W01.parquet",
    country   = "uga",
    disease   = "oncho",
    data_type = "surveillance",
    layer     = "processed",
    period    = "2024-W01"
) {
  list(
    path             = path,
    country          = country,
    disease          = disease,
    data_type        = data_type,
    layer            = layer,
    period           = period,
    file_format      = "parquet",
    row_count        = NA_integer_,
    size_bytes       = NA_integer_,
    registered_at    = "2026-06-04T12:00:00Z",
    registered_by    = "test.user",
    last_verified_at = NA_character_,
    checksum         = NA_character_
  )
}

# --- register -----------------------------------------------------------------

test_that("eri_catalog_register adds a new entry", {
  stored <- list(entries = list())

  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    storage_dir_exists  = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      stored$entries <<- yaml::read_yaml(src)$entries
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_catalog_register(
    path      = "uga/oncho/surveillance/processed/2024_W01.parquet",
    country   = "uga",
    disease   = "oncho",
    data_type = "surveillance",
    layer     = "processed",
    period    = "2024-W01"
  )

  expect_equal(out$path, "uga/oncho/surveillance/processed/2024_W01.parquet")
  expect_equal(out$country, "uga")
  expect_equal(out$file_format, "parquet")
  expect_length(stored$entries, 1L)
})

test_that("eri_catalog_register upserts existing entry by path", {
  entry1 <- make_entry()
  stored <- make_catalog(entry1)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    storage_dir_exists  = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      stored <<- yaml::read_yaml(src)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  eri_catalog_register(
    path      = entry1$path,
    country   = "uga",
    disease   = "oncho",
    data_type = "surveillance",
    layer     = "processed",
    period    = "2024-W01",
    row_count = 500L
  )

  expect_length(stored$entries, 1L)
  expect_equal(stored$entries[[1]]$row_count, 500L)
})

# --- query --------------------------------------------------------------------

test_that("eri_catalog_query returns empty typed tibble when catalog is empty", {
  local_mocked_bindings(
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_catalog_query()
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_true("path" %in% names(out))
  expect_true("last_verified_at" %in% names(out))
})

test_that("eri_catalog_query filters by country", {
  e1 <- make_entry(country = "uga", path = "uga/oncho/surveillance/processed/f1.parquet")
  e2 <- make_entry(country = "nga", disease = "lf", path = "nga/lf/surveillance/processed/f2.parquet")
  stored <- make_catalog(e1, e2)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_catalog_query(country = "uga")
  expect_equal(nrow(out), 1L)
  expect_equal(out$country, "uga")
})

test_that("eri_catalog_query filters by multiple dimensions", {
  e1 <- make_entry(country = "uga", disease = "oncho", layer = "processed",
                   path = "uga/oncho/surveillance/processed/f1.parquet")
  e2 <- make_entry(country = "uga", disease = "lf", layer = "processed",
                   path = "uga/lf/surveillance/processed/f2.parquet")
  e3 <- make_entry(country = "uga", disease = "oncho", layer = "staged",
                   path = "uga/oncho/surveillance/staged/f3.parquet")
  stored <- make_catalog(e1, e2, e3)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_catalog_query(country = "uga", disease = "oncho", layer = "processed")
  expect_equal(nrow(out), 1L)
  expect_equal(out$path, e1$path)
})

# --- verify -------------------------------------------------------------------

test_that("eri_catalog_verify returns exists column", {
  e1 <- make_entry(path = "uga/oncho/surveillance/processed/exists.parquet")
  e2 <- make_entry(path = "uga/oncho/surveillance/processed/missing.parquet",
                   period = "2024-W02")
  stored <- make_catalog(e1, e2)

  local_mocked_bindings(
    storage_file_exists = function(container, path, ...) {
      if (path == erifunctions:::.ERI_CATALOG_PATH) return(TRUE)
      grepl("exists\\.parquet", path)
    },
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    storage_dir_exists  = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      stored <<- yaml::read_yaml(src)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- suppressWarnings(eri_catalog_verify())
  expect_true("exists" %in% names(out))
  expect_equal(out$exists[out$path == e1$path], TRUE)
  expect_equal(out$exists[out$path == e2$path], FALSE)
})

test_that("eri_catalog_verify updates last_verified_at for existing entries", {
  e1 <- make_entry()
  stored <- make_catalog(e1)

  local_mocked_bindings(
    storage_file_exists = function(container, path, ...) {
      if (path == erifunctions:::.ERI_CATALOG_PATH) return(TRUE)
      TRUE
    },
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    storage_dir_exists  = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      stored <<- yaml::read_yaml(src)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  eri_catalog_verify()
  expect_false(is.na(stored$entries[[1]]$last_verified_at))
})

# --- remove -------------------------------------------------------------------

test_that("eri_catalog_remove deletes the matching entry by path", {
  e1 <- make_entry(path = "atlantis/malaria/surveillance/processed/keep.parquet")
  e2 <- make_entry(path = "atlantis/malaria/surveillance/processed/drop.parquet",
                   period = "2024-02")
  stored <- make_catalog(e1, e2)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    storage_dir_exists  = function(...) TRUE,
    storage_upload = function(container, src, dest, ...) {
      stored <<- yaml::read_yaml(src)
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- eri_catalog_remove("atlantis/malaria/surveillance/processed/drop.parquet")
  expect_true(out)
  expect_length(stored$entries, 1L)
  expect_equal(stored$entries[[1]]$path, e1$path)
})

test_that("eri_catalog_remove returns FALSE when no entry matches", {
  e1 <- make_entry(path = "atlantis/malaria/surveillance/processed/keep.parquet")
  stored <- make_catalog(e1)

  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download = function(container, src, dest, ...) yaml::write_yaml(stored, dest),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  expect_false(suppressWarnings(eri_catalog_remove("nope/not/here.parquet")))
  expect_length(stored$entries, 1L)
})

# --- eri_approve integration --------------------------------------------------

test_that("eri_approve calls eri_catalog_register for each moved file", {
  catalog_paths <- character(0)
  staged_files  <- tibble::tibble(name = "uga/oncho/surveillance/staged/2024_W01.parquet")

  local_mocked_bindings(
    storage_dir_exists   = function(...) TRUE,
    list_storage_files   = function(...) staged_files,
    storage_download     = function(container, src, dest, ...) file.create(dest),
    storage_upload       = function(...) invisible(NULL),
    delete_storage_file  = function(...) invisible(NULL),
    .package = "AzureStor"
  )
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .eri_log_session = function(...) invisible(NULL),
    .eri_write_log   = function(...) invisible(NULL),
    eri_catalog_register = function(path, ...) {
      catalog_paths <<- c(catalog_paths, path)
      invisible(NULL)
    },
    .package = "erifunctions"
  )

  eri_approve("uga", "oncho", "surveillance", period = "2024_W01")
  expect_length(catalog_paths, 1L)
  expect_match(catalog_paths[[1]], "processed")
})
