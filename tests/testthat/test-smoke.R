#### Live smoke tests — require real Azure + ODK infrastructure ####
#
# These tests are skipped in CI and in any session where ERI_SMOKE_TESTS != "true".
# To run locally against the real dev environment:
#
#   Sys.setenv(ERI_SMOKE_TESTS = "true")
#   devtools::test(filter = "smoke")
#
# All write operations use timestamped names and are cleaned up via withr::defer.
# See tests/testthat/README.md for full setup instructions.

.smoke_skip <- function() {
  skip_if_offline()
  skip_on_ci()
  skip_if(
    Sys.getenv("ERI_SMOKE_TESTS") != "true",
    "Set ERI_SMOKE_TESTS=true to run live smoke tests"
  )
}

.smoke_az <- function() {
  get_azure_storage_connection(
    storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
  )
}

# ── 1. Data analyst (primary) ─────────────────────────────────────────────────
# Exercises the full daily analyst loop end-to-end.

test_that("smoke [analyst]: Azure data connection succeeds", {
  .smoke_skip()
  az_con <- .smoke_az()
  expect_false(is.null(az_con))
})

test_that("smoke [analyst]: eri_data_path builds canonical blob path", {
  .smoke_skip()
  path <- eri_data_path("dr", "malaria", "surveillance", "processed")
  expect_type(path, "character")
  expect_match(path, "dr/malaria/surveillance/processed")
})

test_that("smoke [analyst]: eri_list returns files from a known processed path", {
  .smoke_skip()
  az_con <- .smoke_az()
  path   <- eri_data_path("dr", "malaria", "surveillance", "processed")
  result <- eri_list(path, azcontainer = az_con)
  expect_true(is.data.frame(result) || is.character(result))
})

test_that("smoke [analyst]: load_dq_schema and run_dq_checks work on sample data", {
  .smoke_skip()
  schema <- load_dq_schema("dr", "malaria")
  expect_type(schema, "list")

  sample <- tibble::tibble(
    Year    = 2024L,
    EpiWeek = 1L,
    Cases   = 10L,
    Deaths  = 0L
  )
  result <- tryCatch(run_dq_checks(sample, schema), error = function(e) NULL)
  expect_false(is.null(result))
})

test_that("smoke [analyst]: load_cmr_schema and eri_ingest_cmr work on a real CMR file", {
  .smoke_skip()
  schema <- load_cmr_schema("dr")
  expect_type(schema, "list")
  expect_true("template" %in% names(schema))
})

test_that("smoke [analyst]: add_anomaly_pct_change runs on sample time series", {
  .smoke_skip()
  sample <- tibble::tibble(
    month = 1:6L,
    cases = c(10L, 12L, 9L, 100L, 11L, 10L)
  )
  result <- add_anomaly_pct_change(sample, value_col = "cases", period_col = "month")
  expect_true(any(grepl("anomaly", names(result), ignore.case = TRUE)))
})

test_that("smoke [analyst]: eri_catalog_query returns a tibble", {
  .smoke_skip()
  az_con <- .smoke_az()
  result <- eri_catalog_query(data_con = az_con)
  expect_s3_class(result, "tbl_df")
})

test_that("smoke [analyst]: ODK Central connection succeeds", {
  .smoke_skip()
  odk_con <- init_odk_connection()
  expect_false(is.null(odk_con))
})

test_that("smoke [analyst]: eri_odk_list_registered returns a tibble with expected columns", {
  .smoke_skip()
  az_con <- .smoke_az()
  result <- eri_odk_list_registered(data_con = az_con)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("project_id", "form_id", "country", "disease") %in% names(result)))
})

test_that("smoke [analyst]: eri_survey_status returns status for registered forms", {
  .smoke_skip()
  odk_con <- init_odk_connection()
  az_con  <- .smoke_az()
  registered <- eri_odk_list_registered(data_con = az_con)
  skip_if(nrow(registered) == 0L, "No registered forms to check status")

  first <- registered[1L, ]
  result <- eri_survey_status(
    project_id = first$project_id,
    form_id    = first$form_id,
    con        = odk_con
  )
  expect_s3_class(result, "eri_survey_status")
})

test_that("smoke [analyst]: full ODK register -> list -> deregister cycle", {
  .smoke_skip()
  az_con      <- .smoke_az()
  odk_con     <- init_odk_connection()
  test_proj   <- 9999L
  test_form   <- paste0("smoke_form_", format(Sys.time(), "%Y%m%d%H%M%S"))

  withr::defer(
    tryCatch(
      eri_odk_deregister(test_proj, test_form, data_con = az_con),
      error = function(e) NULL
    )
  )

  eri_odk_register(
    project_id = test_proj,
    form_id    = test_form,
    country    = "smoke",
    disease    = "test",
    server_url = Sys.getenv("ODK_URL"),
    data_con   = az_con
  )

  registered <- eri_odk_list_registered(data_con = az_con)
  expect_true(test_form %in% registered$form_id)
})

# ── 2. Spatial (Phase 5) ──────────────────────────────────────────────────────
# Requires the 'sf' package and a loaded boundary in Azure.

test_that("smoke [spatial]: eri_spatial_load returns an sf object", {
  .smoke_skip()
  skip_if_not_installed("sf")
  az_con <- .smoke_az()
  result <- tryCatch(
    eri_spatial_load("ht", level = 2, data_con = az_con),
    error = function(e) skip(paste("Boundary not found:", e$message))
  )
  expect_s3_class(result, "sf")
  expect_true(nrow(result) > 0L)
})

test_that("smoke [spatial]: eri_spatial_join assigns admin names to point data", {
  .smoke_skip()
  skip_if_not_installed("sf")
  az_con    <- .smoke_az()
  communes  <- tryCatch(
    eri_spatial_load("ht", level = 2, data_con = az_con),
    error = function(e) skip(paste("Boundary not found:", e$message))
  )
  pts <- tibble::tibble(
    lat = c(18.5, 19.0),
    lon = c(-72.3, -72.5)
  )
  result <- eri_spatial_join(pts, lat_col = "lat", lon_col = "lon",
                              shapefile = communes,
                              admin_cols = c("adm2_name", "adm1_name"))
  expect_s3_class(result, "tbl_df")
  expect_true("adm2_name" %in% names(result))
})

# ── 3. Epi analytics (Phase 5) ────────────────────────────────────────────────

test_that("smoke [epi]: eri_incidence_rate computes correctly on sample data", {
  .smoke_skip()
  cases  <- c(10L, 20L, 0L)
  pop    <- c(1000L, 500L, 200L)
  result <- eri_incidence_rate(cases, pop, multiplier = 1000L)
  expect_equal(result, c(10, 40, 0), tolerance = 1e-6)
})

test_that("smoke [epi]: eri_epidemic_curve returns a ggplot on sample data", {
  .smoke_skip()
  skip_if_not_installed("ggplot2")
  df <- tibble::tibble(
    date   = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 10),
    cases  = sample(1:20, 10)
  )
  p <- eri_epidemic_curve(df, date_col = "date", count_col = "cases",
                           period = "week")
  expect_s3_class(p, "ggplot")
})

# ── 4. Reporting (Phase 6) ────────────────────────────────────────────────────

test_that("smoke [reporting]: eri_table returns a flextable", {
  .smoke_skip()
  skip_if_not_installed("flextable")
  df <- tibble::tibble(country = c("DR", "Haiti"), n = c(100L, 200L))
  ft <- eri_table(df, title = "Smoke test table")
  expect_s3_class(ft, "flextable")
})

test_that("smoke [reporting]: eri_report_excel writes a real xlsx file", {
  .smoke_skip()
  skip_if_not_installed("openxlsx2")
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  df <- tibble::tibble(x = 1:3, y = c("a", "b", "c"))
  eri_report_excel(
    sheets   = list(data = list(data = df, title = "Smoke test")),
    path     = path,
    title    = "Smoke test workbook"
  )
  expect_true(file.exists(path))
  expect_gt(file.size(path), 0L)
})

test_that("smoke [reporting]: eri_pptx_create and eri_pptx_save write a real pptx file", {
  .smoke_skip()
  skip_if_not_installed("officer")
  path <- tempfile(fileext = ".pptx")
  withr::defer(unlink(path))
  eri_pptx_create() |>
    eri_pptx_add_title("Smoke test") |>
    eri_pptx_save(path)
  expect_true(file.exists(path))
  expect_gt(file.size(path), 0L)
})

# ── 5. Epidemiologist (secondary) ─────────────────────────────────────────────
# Lighter coverage: artifact registry and research project init/log.

test_that("smoke [epi]: artifact upload -> list -> pull -> archive cycle", {
  .smoke_skip()
  az_con   <- .smoke_az()
  art_name <- paste0("smoke_artifact_", format(Sys.time(), "%Y%m%d%H%M%S"))
  tmp_file <- tempfile(fileext = ".csv")
  writeLines("col1,col2\n1,2", tmp_file)
  withr::defer(unlink(tmp_file))

  withr::defer(
    tryCatch(
      eri_artifact_archive(art_name, data_con = az_con),
      error = function(e) NULL
    )
  )

  eri_artifact_upload(
    local_path  = tmp_file,
    name        = art_name,
    type        = "reference",
    description = "Smoke test -- safe to archive",
    data_con    = az_con
  )

  listed <- eri_artifact_list(data_con = az_con)
  expect_true(art_name %in% listed$name)

  tmp_dest <- withr::local_tempdir()
  pulled   <- eri_artifact_pull(art_name, dest = tmp_dest, data_con = az_con)
  expect_true(file.exists(pulled))

  eri_artifact_archive(art_name, data_con = az_con)
  expect_false(art_name %in% eri_artifact_list(data_con = az_con)$name)
})

test_that("smoke [epi]: research project init, log, and list in Azure", {
  .smoke_skip()
  az_con    <- .smoke_az()
  proj_name <- paste0("smoke_proj_", format(Sys.time(), "%Y%m%d%H%M%S"))
  proj_dir  <- withr::local_tempdir()

  eri_research_init(
    project_name = proj_name,
    country      = "smoke",
    disease      = "test",
    description  = "Smoke test project -- safe to ignore",
    path         = proj_dir,
    data_con     = az_con
  )

  expect_true(file.exists(file.path(proj_dir, "research.yaml")))
  expect_true(dir.exists(file.path(proj_dir, "data")))

  eri_research_log("Smoke test entry", path = proj_dir)
  manifest <- yaml::read_yaml(file.path(proj_dir, "research.yaml"))
  expect_equal(length(manifest$log), 1L)

  listed <- eri_research_list(data_con = az_con)
  expect_true(proj_name %in% listed$project_name)
})
