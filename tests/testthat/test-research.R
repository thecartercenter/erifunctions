#### Tests for research project scaffolding ####

test_that("eri_research_status surfaces promotions to canonical", {
  proj <- withr::local_tempdir()
  yaml::write_yaml(
    list(
      project_name = "p", country = "dr", disease = "malaria", description = "d",
      created_at = "t", created_by = "u", azure_path = "research/p/",
      pulled_data = list(), artifacts_used = list(), log = list(),
      snapshots = list(), outputs = list(), tags = list(),
      promoted_data = list(list(
        type = "boundary", country = "dr", level = 3L,
        azure_path = "spatial/dr/adm3.rds", replaced = TRUE,
        promoted_at = "2026-06-17T12:00:00Z", promoted_by = "u"
      ))
    ),
    file.path(proj, "research.yaml")
  )
  expect_message(
    expect_message(eri_research_status(path = proj), "1 promotion"),
    "spatial/dr/adm3.rds"
  )
})

.mock_research_con <- function() {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists  = function(...) FALSE,
    create_storage_dir  = function(...) invisible(NULL),
    .package = "AzureStor"
  )
}

# --- eri_research_init --------------------------------------------------------

test_that("eri_research_init dry_run returns NULL without writing files", {
  tmp <- withr::local_tempdir()
  result <- eri_research_init(
    "dr_irs_2024", "dr", "malaria", "ITS analysis",
    path = tmp, dry_run = TRUE
  )
  expect_null(result)
  expect_false(file.exists(file.path(tmp, "research.yaml")))
  expect_false(dir.exists(file.path(tmp, "data")))
})

test_that("eri_research_init scaffolds local dirs and research.yaml", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  result <- eri_research_init(
    "dr_irs_2024", "dr", "malaria", "ITS analysis",
    path = tmp
  )

  expect_equal(result, file.path(tmp, "research.yaml"))
  expect_true(file.exists(file.path(tmp, "research.yaml")))
  expect_true(dir.exists(file.path(tmp, "data")))
  expect_true(dir.exists(file.path(tmp, "figs")))
  expect_true(dir.exists(file.path(tmp, "outputs")))

  manifest <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(manifest$project_name, "dr_irs_2024")
  expect_equal(manifest$country,      "dr")
  expect_equal(manifest$disease,      "malaria")
  expect_equal(manifest$azure_path,   "research/dr_irs_2024/")
  expect_true(is.list(manifest$pulled_data))
  expect_true(is.list(manifest$artifacts_used))
  expect_true(is.list(manifest$log))
  expect_true(is.list(manifest$snapshots))
  expect_true(is.list(manifest$outputs))
})

test_that("eri_research_init prints the registered next-step hint on success (task-registry epilogue)", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  expect_message(
    eri_research_init("dr_irs_2024", "dr", "malaria", "ITS analysis", path = tmp),
    "Next:"
  )
})

test_that("eri_research_init errors if project already exists locally", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_init("my_proj", "dr", "malaria", "first", path = tmp)
  expect_error(
    eri_research_init("my_proj", "dr", "malaria", "second", path = tmp),
    "already exists"
  )
})

test_that("eri_research_init creates Azure directory", {
  tmp     <- withr::local_tempdir()
  created <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    create_storage_dir = function(con, path, ...) {
      created <<- c(created, path)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  eri_research_init("my_proj", "dr", "malaria", "desc", path = tmp)
  expect_true(any(grepl("research/my_proj", created)))
})

# --- eri_research_resume ------------------------------------------------------

test_that("eri_research_resume reads manifest and prints without error", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    project_name   = "dr_irs_2024",
    country        = "dr",
    disease        = "malaria",
    description    = "ITS analysis",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = "research/dr_irs_2024/",
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(
      list(timestamp = "2026-06-04T01:00:00Z", note = "Started analysis")
    ),
    snapshots      = list(),
    outputs        = list()
  )
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  result <- eri_research_resume(path = tmp)
  expect_equal(result$project_name, "dr_irs_2024")
  expect_equal(result$country,      "dr")
})

test_that("eri_research_resume errors when research.yaml is missing", {
  tmp <- withr::local_tempdir()
  expect_error(eri_research_resume(path = tmp), "research.yaml")
})

test_that("eri_research_resume handles project with no pulls and no log", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    project_name   = "empty_proj",
    country        = "uga",
    disease        = "oncho",
    description    = "Empty",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = "research/empty_proj/",
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list()
  )
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  expect_no_error(eri_research_resume(path = tmp))
})

# --- eri_research_log ---------------------------------------------------------

test_that("eri_research_log appends entry with timestamp to research.yaml", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    project_name   = "test_proj",
    country        = "dr",
    disease        = "malaria",
    description    = "test",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = "research/test_proj/",
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list()
  )
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))

  eri_research_log("First note", path = tmp)

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$log), 1L)
  expect_equal(updated$log[[1L]]$note, "First note")
  expect_true(nchar(updated$log[[1L]]$timestamp) > 0L)
})

test_that("eri_research_log appends multiple entries sequentially", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    project_name = "test_proj", country = "dr", disease = "malaria",
    description = "test", created_at = "2026-06-04T00:00:00Z",
    created_by = "test.user", azure_path = "research/test_proj/",
    pulled_data = list(), artifacts_used = list(), log = list(),
    snapshots = list(), outputs = list()
  )
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))

  eri_research_log("Note 1", path = tmp)
  eri_research_log("Note 2", path = tmp)

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$log), 2L)
  expect_equal(updated$log[[2L]]$note, "Note 2")
})

test_that("eri_research_log errors when research.yaml is missing", {
  tmp <- withr::local_tempdir()
  expect_error(eri_research_log("note", path = tmp), "research.yaml")
})

# --- eri_research_list --------------------------------------------------------

test_that("eri_research_list returns typed empty tibble when no projects found", {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) character(0L),
    .package = "AzureStor"
  )

  result <- eri_research_list()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true(all(c("project_name", "azure_path") %in% names(result)))
})

test_that("eri_research_list returns one row per project", {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    list_storage_files = function(...) {
      c("research/dr_irs_2024/research.yaml",
        "research/dr_irs_2024/outputs/figure1.png",
        "research/uga_oncho_2025/research.yaml")
    },
    .package = "AzureStor"
  )

  result <- eri_research_list()
  expect_equal(nrow(result), 2L)
  expect_true("dr_irs_2024" %in% result$project_name)
  expect_true("uga_oncho_2025" %in% result$project_name)
})
