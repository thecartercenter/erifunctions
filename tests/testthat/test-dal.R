#### Tests for .eri_create_azure_dir ####

test_that(".eri_create_azure_dir trims trailing slash and creates each missing parent", {
  created <- character(0)
  local_mocked_bindings(
    storage_dir_exists = function(con, path) FALSE,
    create_storage_dir = function(con, path) created <<- c(created, path),
    .package = "AzureStor"
  )
  out <- .eri_create_azure_dir("mock_con", "research/dr_irs/data/")
  # trailing slash trimmed, every level created in order
  expect_equal(created, c("research", "research/dr_irs", "research/dr_irs/data"))
  expect_equal(out, "research/dr_irs/data")
})

test_that(".eri_create_azure_dir skips levels that already exist", {
  created <- character(0)
  local_mocked_bindings(
    storage_dir_exists = function(con, path) path != "a/b/c",  # only the leaf is missing
    create_storage_dir = function(con, path) created <<- c(created, path),
    .package = "AzureStor"
  )
  .eri_create_azure_dir("mock_con", "a/b/c")
  expect_equal(created, "a/b/c")
})

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

test_that("eri_data_path builds 5-axis paths (data_source + data_type)", {
  expect_equal(
    eri_data_path("dr", "malaria", "surveillance", "case", "staged"),
    "dr/malaria/surveillance/case/staged"
  )
  expect_equal(
    eri_data_path("uga", "oncho", "programmatic", "treatment", "raw", "2024_06.parquet"),
    "uga/oncho/programmatic/treatment/raw/2024_06.parquet"
  )
})

test_that("eri_data_path warns (does not error) on an unregistered axis value", {
  # extensibility: unknown data_source/data_type warns so new data is never blocked
  expect_warning(
    p <- eri_data_path("dr", "malaria", "newchannel", "staged"),
    "data_source"
  )
  expect_equal(p, "dr/malaria/newchannel/staged")
  expect_warning(
    eri_data_path("dr", "malaria", "surveillance", "newmeasure", "processed"),
    "data_type"
  )
})

test_that("eri_data_path resolves the legacy named form (data_type = <source>)", {
  # old callers named the source with the previous 3rd-param name `data_type=`
  expect_equal(
    eri_data_path(country = "uga", disease = "oncho", data_type = "cmr", layer = "staged"),
    "uga/oncho/cmr/staged"
  )
})

test_that("eri_data_path errors clearly when data_source is genuinely missing", {
  expect_error(
    eri_data_path(country = "uga", disease = "oncho", data_type = "case", layer = "staged"),
    "data_source"
  )
})

test_that("eri_data_path rejects invalid layer", {
  expect_error(
    eri_data_path("dr", "malaria", "surveillance", "archive"),
    "layer"
  )
})

#### Tests for .eri_log_session ####

test_that(".eri_log_session sets the session_logged option", {
  withr::with_options(list(erifunctions.session_logged = NULL), {
    # SP credentials absent → skips Azure write but still sets the flag
    withr::with_envvar(list(ERIFUNCTIONS_SP_CLIENT_ID = "", ERIFUNCTIONS_SP_CLIENT_SECRET = ""), {
      .eri_log_session()
      expect_true(isTRUE(getOption("erifunctions.session_logged")))
    })
  })
})

test_that(".eri_log_session is a no-op when flag is already set", {
  withr::with_options(list(erifunctions.session_logged = TRUE), {
    # Should return immediately without touching anything
    expect_invisible(.eri_log_session())
  })
})

#### Tests for eri_trigger error paths (no Azure needed) ####

test_that("eri_trigger errors clearly when GITHUB_PAT is missing", {
  withr::with_envvar(list(GITHUB_PAT = ""), {
    expect_error(
      eri_trigger("hsp-mal", "dr", "malaria"),
      "GITHUB_PAT"
    )
  })
})

test_that("eri_trigger errors clearly for unknown pipeline", {
  withr::with_envvar(list(GITHUB_PAT = "fake-token"), {
    expect_error(
      eri_trigger("nonexistent-pipeline", "dr", "malaria"),
      "Unknown pipeline"
    )
  })
})

#### Tests for eri_stage error paths (no Azure needed) ####

test_that("eri_stage errors clearly for unknown pipeline", {
  expect_error(
    eri_stage("nonexistent-pipeline", "dr", "malaria",
              projects_con = structure(list(), class = "mock"),
              data_con     = structure(list(), class = "mock")),
    "Unknown pipeline"
  )
})

test_that("eri_stage errors clearly for unregistered country", {
  expect_error(
    eri_stage("hsp-mal", "zz", "malaria",
              projects_con = structure(list(), class = "mock"),
              data_con     = structure(list(), class = "mock")),
    "not registered"
  )
})

test_that("hsp-mal pipeline registry has required fields", {
  reg <- .eri_pipeline_registry[["hsp-mal"]]
  expect_false(is.null(reg))
  expect_true(all(c("owner", "repo", "workflow", "project_folder", "country_map") %in% names(reg)))
  expect_equal(reg$country_map[["dr"]], "dom")
  expect_equal(reg$country_map[["ht"]], "hti")
})

test_that("rb-expansion registry has correct project_folder and all CMR countries", {
  reg <- .eri_pipeline_registry[["rb-expansion"]]
  expect_false(is.null(reg))
  expect_equal(reg$project_folder, "health-rb-country-expansion-dev")
  expect_true(all(c("eth", "nga", "sdn", "ssd", "uga", "mad", "tcd") %in% names(reg$country_map)))
})

#### Tests for eri_stage_cmr error paths (no Azure needed) ####

test_that("eri_stage_cmr errors for unregistered country", {
  expect_error(
    eri_stage_cmr("zz",
                  projects_con = structure(list(), class = "mock"),
                  data_con     = structure(list(), class = "mock")),
    "not registered"
  )
})

test_that("eri_stage_cmr errors when source directory not found", {
  with_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    list_storage_files = function(...) tibble::tibble(
      name  = c("health-rb-country-expansion-dev/raw/filled_templates/uga/202603"),
      size  = 0L,
      isdir = TRUE
    ),
    .package = "AzureStor",
    {
      expect_error(
        eri_stage_cmr("uga", period = "202603",
                      projects_con = structure(list(), class = "mock"),
                      data_con     = structure(list(), class = "mock")),
        "Source directory not found"
      )
    }
  )
})

test_that("eri_stage_cmr errors when no period dirs exist (period = NULL)", {
  with_mocked_bindings(
    list_storage_files = function(...) tibble::tibble(
      name  = character(0),
      size  = integer(0),
      isdir = logical(0)
    ),
    .package = "AzureStor",
    {
      expect_error(
        eri_stage_cmr("uga",
                      projects_con = structure(list(), class = "mock"),
                      data_con     = structure(list(), class = "mock")),
        "No period directories"
      )
    }
  )
})

test_that("eri_stage_cmr selects most recent period when period = NULL", {
  mock_con <- structure(list(), class = "mock")

  period_listing <- tibble::tibble(
    name  = c(
      "health-rb-country-expansion-dev/raw/filled_templates/uga/202601",
      "health-rb-country-expansion-dev/raw/filled_templates/uga/202603",
      "health-rb-country-expansion-dev/raw/filled_templates/uga/202512"
    ),
    size  = c(0L, 0L, 0L),
    isdir = c(TRUE, TRUE, TRUE)
  )

  call_log <- character(0)

  with_mocked_bindings(
    list_storage_files = function(con, path, ...) {
      call_log <<- c(call_log, path)
      if (grepl("202603$", path)) {
        return(tibble::tibble(
          name  = paste0(path, "/uga_202603_report.xlsx"),
          size  = 1000L,
          isdir = FALSE
        ))
      }
      period_listing
    },
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    storage_download    = function(con, src, dest, ...) invisible(NULL),
    storage_upload      = function(...) invisible(NULL),
    create_storage_dir  = function(...) invisible(NULL),
    .package = "AzureStor",
    {
      with_mocked_bindings(
        .eri_write_log = function(...) invisible(NULL),
        {
          suppressMessages(
            eri_stage_cmr("uga", projects_con = mock_con, data_con = mock_con)
          )
        }
      )
    }
  )
  expect_true(any(grepl("202603", call_log)))
})

#### Tests for eri_ingest error paths (no Azure needed) ####

test_that("eri_ingest errors when file does not exist", {
  expect_error(
    eri_ingest("nonexistent/path/file.xlsx", "dr", "malaria",
               data_con = structure(list(), class = "mock")),
    "File not found"
  )
})

test_that("eri_ingest errors clearly for an unknown mirror pipeline (opt-in only)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(tibble::tibble(x = 1), tmp)
  # the pipeline registry is only consulted when mirror_pipeline is set; the error
  # fires up front, before any Azure I/O
  expect_error(
    eri_ingest(tmp, "dr", "malaria",
               mirror_pipeline = "nonexistent-pipeline",
               data_con        = structure(list(), class = "mock")),
    "Unknown pipeline"
  )
})

test_that("eri_ingest errors for a country not registered to the mirror pipeline", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(tibble::tibble(x = 1), tmp)
  expect_error(
    eri_ingest(tmp, "zz", "malaria",
               mirror_pipeline = "hsp-mal",
               data_con        = structure(list(), class = "mock")),
    "not registered"
  )
})

test_that("eri_ingest no longer needs .eri_schema_country_map (retired)", {
  expect_false(exists(".eri_schema_country_map", where = asNamespace("erifunctions")))
})

test_that("eri_ingest stages to the five-axis {data_source}/{data_type} path", {
  raw_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(Year = 2024L, EpiWeek = 1L), raw_csv, row.names = FALSE)

  schema <- list(
    country = "uga", disease = "oncho",
    data_source = "programmatic", data_type = "treatment",
    temporal = list(year_col = "Year", period_col = "EpiWeek"),
    columns  = list(
      Year    = list(required = TRUE, type = "numeric"),
      EpiWeek = list(required = TRUE, type = "numeric")
    )
  )

  staged_dest <- NULL
  logged_dir  <- NULL

  local_mocked_bindings(
    .eri_blob_write = function(con, src, dest, ...) { staged_dest <<- dest; invisible(NULL) },
    .eri_write_log  = function(op_log, con, dir, ...) { logged_dir <<- dir; invisible(NULL) },
    eri_dq_log      = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    .package = "AzureStor"
  )

  eri_ingest(raw_csv, "uga", "oncho",
             data_source = "programmatic", data_type = "treatment",
             schema = schema, data_con = structure(list(), class = "mock"))

  expect_match(staged_dest, "^uga/oncho/programmatic/treatment/staged/")
  expect_equal(logged_dir, "uga/oncho/programmatic/treatment/logs")
})

test_that("eri_ingest with data_type = NULL stays four-axis (no measure level)", {
  raw_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(Year = 2024L, EpiWeek = 1L), raw_csv, row.names = FALSE)

  schema <- list(
    country = "uga", disease = "oncho", data_source = "surveillance",
    temporal = list(year_col = "Year", period_col = "EpiWeek"),
    columns  = list(
      Year    = list(required = TRUE, type = "numeric"),
      EpiWeek = list(required = TRUE, type = "numeric")
    )
  )

  staged_dest <- NULL
  logged_dir  <- NULL

  local_mocked_bindings(
    .eri_blob_write = function(con, src, dest, ...) { staged_dest <<- dest; invisible(NULL) },
    .eri_write_log  = function(op_log, con, dir, ...) { logged_dir <<- dir; invisible(NULL) },
    eri_dq_log      = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    .package = "AzureStor"
  )

  eri_ingest(raw_csv, "uga", "oncho",
             data_source = "surveillance", data_type = NULL,
             schema = schema, data_con = structure(list(), class = "mock"))

  expect_match(staged_dest, "^uga/oncho/surveillance/staged/")
  expect_equal(logged_dir, "uga/oncho/surveillance/logs")
})

test_that("eri_ingest archives the original source file to raw/ before staging", {
  raw_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(Year = 2024L, EpiWeek = 1L), raw_csv, row.names = FALSE)

  schema <- list(
    country = "uga", disease = "oncho",
    data_source = "programmatic", data_type = "treatment",
    temporal = list(year_col = "Year", period_col = "EpiWeek"),
    columns  = list(
      Year    = list(required = TRUE, type = "numeric"),
      EpiWeek = list(required = TRUE, type = "numeric")
    )
  )

  written_dests  <- character(0)
  logged_op      <- NULL

  local_mocked_bindings(
    .eri_blob_write  = function(con, src, dest, ...) { written_dests <<- c(written_dests, dest); invisible(NULL) },
    .eri_write_log   = function(op_log, con, dir, ...) { logged_op <<- op_log; invisible(NULL) },
    eri_dq_log       = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    .package = "AzureStor"
  )

  eri_ingest(raw_csv, "uga", "oncho",
             data_source = "programmatic", data_type = "treatment",
             schema = schema, data_con = structure(list(), class = "mock"))

  raw_write <- written_dests[grepl("^uga/oncho/programmatic/treatment/raw/", written_dests)]
  expect_length(raw_write, 1L)
  # timestamp-suffixed, not the bare original filename, so re-ingesting the
  # same filename later doesn't collide with this archive
  expect_match(basename(raw_write), paste0("^", tools::file_path_sans_ext(basename(raw_csv)), "_\\d{8}T\\d{6}Z"))

  expect_false(is.null(logged_op$source_hash))
  expect_equal(logged_op$source_file, basename(raw_csv))
  expect_equal(logged_op$source_hash, unname(tools::md5sum(raw_csv)))
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

test_that(".eri_note_no_measure signposts the four-axis form once per session", {
  withr::local_options(erifunctions.noted_no_measure = NULL)
  expect_message(
    erifunctions:::.eri_note_no_measure(NULL),
    "no-measure"
  )
  # Once per session: a second four-axis call is silent.
  expect_no_message(erifunctions:::.eri_note_no_measure(NULL))
})

test_that(".eri_note_no_measure is silent when a measure is supplied", {
  withr::local_options(erifunctions.noted_no_measure = NULL)
  expect_no_message(erifunctions:::.eri_note_no_measure("case"))
  # ...and it did not arm the once-per-session guard, so a later no-measure call still notes.
  expect_message(erifunctions:::.eri_note_no_measure(NULL), "no-measure")
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
