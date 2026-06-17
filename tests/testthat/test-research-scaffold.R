#### Tests for eri_research_scaffold ####

.mock_init_azure <- function() {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions", .env = parent.frame()
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    .package = "AzureStor", .env = parent.frame()
  )
}

test_that("eri_research_scaffold creates a full repo skeleton", {
  tmp <- withr::local_tempdir()
  .mock_init_azure()

  repo <- eri_research_scaffold("dr_irs_2024", "dr", "malaria", "ITS analysis", dest = tmp)

  expect_equal(repo, file.path(tmp, "dr_irs_2024"))
  expect_true(file.exists(file.path(repo, "README.md")))
  expect_true(file.exists(file.path(repo, ".gitignore")))
  expect_true(file.exists(file.path(repo, ".github", "workflows", "ci.yaml")))
  # CI must restore the geospatial/Azure stack on Linux: PPM binaries (no source build) plus the
  # system libs sf/AzureStor need at load, else curl/sf/gdal fail to install (issue from PR #149).
  ci <- readLines(file.path(repo, ".github", "workflows", "ci.yaml"))
  expect_true(any(grepl("use-public-rspm: true", ci, fixed = TRUE)))
  expect_true(any(grepl("libgdal-dev", ci, fixed = TRUE)))
  expect_true(file.exists(file.path(repo, "analysis", "workflow.qmd")))
  expect_true(file.exists(file.path(repo, "research.yaml")))
  expect_true(dir.exists(file.path(repo, "data")))
  expect_true(dir.exists(file.path(repo, "figs")))
  expect_true(dir.exists(file.path(repo, "outputs")))
})

test_that("eri_research_scaffold gitignores data and wires reproducibility into the README", {
  tmp <- withr::local_tempdir()
  .mock_init_azure()

  repo <- eri_research_scaffold("study", "dr", "malaria", "desc", dest = tmp)

  gi <- readLines(file.path(repo, ".gitignore"))
  expect_true("data/" %in% gi)        # data must never be committed
  expect_true("outputs/" %in% gi)

  readme <- readLines(file.path(repo, "README.md"))
  expect_true(any(grepl("study", readme)))
  expect_true(any(grepl("eri_research_tag", readme)))   # reproducibility guidance
  expect_true(any(grepl("renv::init", readme)))         # renv bootstrap instructions

  manifest <- yaml::read_yaml(file.path(repo, "research.yaml"))
  expect_equal(manifest$project_name, "study")
})

test_that("eri_research_scaffold errors on a non-empty existing directory", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "p"))
  writeLines("x", file.path(tmp, "p", "existing.txt"))
  expect_error(
    eri_research_scaffold("p", "dr", "malaria", "d", dest = tmp),
    "not empty"
  )
})

test_that("eri_research_scaffold validates name", {
  tmp <- withr::local_tempdir()
  expect_error(eri_research_scaffold("", "dr", "malaria", "d", dest = tmp), "non-empty")
})
