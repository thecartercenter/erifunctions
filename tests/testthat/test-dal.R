#### Tests for eri_data_path ####

test_that("eri_data_path builds correct paths without filename", {
  expect_equal(
    eri_data_path("dr", "malaria", "surveillance", "staged"),
    "dr/malaria/surveillance/staged"
  )
  expect_equal(
    eri_data_path("ht", "lf", "cmr", "processed"),
    "ht/lf/cmr/processed"
  )
  expect_equal(
    eri_data_path("ug", "oncho", "odk", "raw"),
    "ug/oncho/odk/raw"
  )
})

test_that("eri_data_path appends filename when provided", {
  expect_equal(
    eri_data_path("dr", "malaria", "surveillance", "raw", "2024_dr_malaria.parquet"),
    "dr/malaria/surveillance/raw/2024_dr_malaria.parquet"
  )
})

test_that("eri_data_path rejects invalid data_type", {
  expect_error(
    eri_data_path("dr", "malaria", "invalid_type", "staged"),
    "data_type"
  )
})

test_that("eri_data_path rejects invalid layer", {
  expect_error(
    eri_data_path("dr", "malaria", "surveillance", "archive"),
    "layer"
  )
})

#### Tests for eri_approve error paths (no Azure needed) ####

test_that("eri_approve errors informatively when staged dir does not exist", {
  mock_container <- structure(list(), class = "mock_container")

  with_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    .package = "AzureStor",
    {
      expect_error(
        eri_approve("dr", "malaria", "surveillance", "2024-W01",
                    azcontainer = mock_container),
        "does not exist"
      )
    }
  )
})

test_that("eri_approve errors when no files match period", {
  mock_container <- structure(list(), class = "mock_container")
  empty_tbl      <- tibble::tibble(name = character(0), size = integer(0))

  with_mocked_bindings(
    storage_dir_exists    = function(...) TRUE,
    list_storage_files    = function(...) empty_tbl,
    .package = "AzureStor",
    {
      expect_error(
        eri_approve("dr", "malaria", "surveillance", "2024-W01",
                    azcontainer = mock_container),
        "No staged files"
      )
    }
  )
})
