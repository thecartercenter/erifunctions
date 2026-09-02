#### Helpers ####

.make_dq_result <- function(data) {
  structure(
    list(
      data  = data,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
}

#### LF TAS schemas ####

test_that("dr_lf_tas schema loads from package", {
  schema <- load_dq_schema("dr", "lf_tas", azcontainer = NULL)
  expect_type(schema, "list")
  expect_equal(schema$country, "dr")
  expect_true("eu" %in% names(schema$columns))
  expect_true("fts_result" %in% names(schema$columns))
  expect_true(!is.null(schema$derived$discordant_fts_rdt))
  expect_true(!is.null(schema$consistency$no_discordant_fts_rdt))
})

test_that("ht_lf_tas schema loads from package", {
  schema <- load_dq_schema("ht", "lf_tas", azcontainer = NULL)
  expect_type(schema, "list")
  expect_equal(schema$country, "ht")
  expect_true(!is.null(schema$derived$discordant_fts_rdt))
})

test_that("dr_lf_tas discordant flag computed by run_dq_checks", {
  schema <- load_dq_schema("dr", "lf_tas", azcontainer = NULL)
  df <- tibble::tibble(
    eu          = c("EU1", "EU2", "EU3"),
    survey_type = c("TAS-1", "TAS-1", "TAS-2"),
    fts_result  = c("Negative", "Negative", "Positive"),
    rdt_result  = c("Positive", "Negative", NA_character_),
    lat         = c(18.5, 18.6, 18.7),
    lon         = c(-70.0, -70.1, -70.2)
  )
  result <- suppressMessages(suppressWarnings(run_dq_checks(df, schema)))
  expect_true("discordant_fts_rdt" %in% names(result$data))
  expect_equal(result$data$discordant_fts_rdt, c(1L, 0L, 0L))
})

test_that("dr_lf_tas consistency flags discordant FTS/RDT pair", {
  schema <- load_dq_schema("dr", "lf_tas", azcontainer = NULL)
  df <- tibble::tibble(
    eu                  = c("EU1", "EU2"),
    survey_type         = c("TAS-1", "TAS-1"),
    fts_result          = c("Negative", "Negative"),
    rdt_result          = c("Positive", "Negative"),
    lat                 = c(18.5, 18.6),
    lon                 = c(-70.0, -70.1),
    discordant_fts_rdt  = c(1L, 0L)
  )
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 1L)
  expect_true(grepl("discordant", out$issue))
})

test_that("dr_lf_tas consistency passes when no discordant pairs", {
  schema <- load_dq_schema("dr", "lf_tas", azcontainer = NULL)
  df <- tibble::tibble(
    eu                 = c("EU1", "EU2"),
    fts_result         = c("Positive", "Negative"),
    rdt_result         = c("Positive", "Negative"),
    discordant_fts_rdt = c(0L, 0L)
  )
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 0L)
})

#### LF MDA schemas ####

test_that("dr_lf_mda schema loads from package", {
  schema <- load_dq_schema("dr", "lf_mda", azcontainer = NULL)
  expect_type(schema, "list")
  expect_equal(schema$country, "dr")
  expect_true("doses_distributed" %in% names(schema$columns))
  expect_true("target_pop" %in% names(schema$columns))
  expect_true(!is.null(schema$consistency$implausible_overcoverage))
})

test_that("ht_lf_mda schema loads from package", {
  schema <- load_dq_schema("ht", "lf_mda", azcontainer = NULL)
  expect_type(schema, "list")
  expect_equal(schema$country, "ht")
})

test_that("dr_lf_mda consistency flags doses exceeding target_pop", {
  schema <- load_dq_schema("dr", "lf_mda", azcontainer = NULL)
  df <- tibble::tibble(
    eu                = c("EU1", "EU2", "EU3"),
    year              = c(2022L, 2022L, 2022L),
    round             = c(1L, 1L, 1L),
    target_pop        = c(10000L, 5000L, 8000L),
    doses_distributed = c(9500L, 5500L, 7000L),  # row 2 violates
    coverage_pct      = c(95, 110, 87.5)
  )
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 2L)
})

test_that("dr_lf_mda consistency passes when doses within target", {
  schema <- load_dq_schema("dr", "lf_mda", azcontainer = NULL)
  df <- tibble::tibble(
    eu                = c("EU1", "EU2"),
    year              = c(2022L, 2022L),
    round             = c(1L, 1L),
    target_pop        = c(10000L, 5000L),
    doses_distributed = c(9500L, 4800L),
    coverage_pct      = c(95, 96)
  )
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 0L)
})

#### DR Malaria Case schema ####

test_that("dr_malaria_case schema loads from package", {
  schema <- load_dq_schema("dr", "malaria_case", azcontainer = NULL)
  expect_type(schema, "list")
  expect_equal(schema$country, "dr")
  expect_true("province" %in% names(schema$columns))
  expect_true("sample_date" %in% names(schema$columns))
  expect_true(!is.null(schema$derived$imported_flag))
})

test_that("dr_malaria_case imported_flag derived correctly", {
  schema <- load_dq_schema("dr", "malaria_case", azcontainer = NULL)
  df <- tibble::tibble(
    year        = c(2023L, 2023L, 2023L),
    epiweek     = c(10L, 10L, 10L),
    province    = c("Distrito Nacional", "Haiti", "Santo Domingo"),
    municipality= c("Mun A", "Mun B", "Mun C"),
    sample_date = as.Date(c("2023-03-05", "2023-03-05", "2023-03-05"))
  )
  result <- suppressMessages(suppressWarnings(run_dq_checks(df, schema)))
  expect_true("imported_flag" %in% names(result$data))
  expect_equal(result$data$imported_flag, c(0L, 1L, 0L))
})

test_that("dr_malaria_case epiweek range check flags out-of-range", {
  schema <- load_dq_schema("dr", "malaria_case", azcontainer = NULL)
  df <- tibble::tibble(
    epiweek = c(1L, 54L, 26L)
  )
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 2L)
})

#### HT Malaria Case schema ####

test_that("ht_malaria_case schema loads from package", {
  schema <- load_dq_schema("ht", "malaria_case", azcontainer = NULL)
  expect_type(schema, "list")
  expect_equal(schema$country, "ht")
  expect_true("department" %in% names(schema$columns))
  expect_true("commune" %in% names(schema$columns))
  expect_true("cases" %in% names(schema$columns))
  expect_true("population" %in% names(schema$columns))
})

test_that("ht_malaria_case consistency flags negative cases", {
  schema <- load_dq_schema("ht", "malaria_case", azcontainer = NULL)
  df <- tibble::tibble(
    year       = c(2023L, 2023L),
    epiweek    = c(10L, 10L),
    department = c("Ouest", "Nord"),
    commune    = c("Port-au-Prince", "Cap-Haitien"),
    cases      = c(-1L, 5L),
    population = c(1000L, 2000L)
  )
  out <- add_anomaly_consistency(df, schema)
  neg_case_rows <- out[grepl("Negative case", out$issue), ]
  expect_gte(nrow(neg_case_rows), 1L)
  expect_equal(neg_case_rows$row[1], 1L)
})

test_that("ht_malaria_case consistency flags zero population", {
  schema <- load_dq_schema("ht", "malaria_case", azcontainer = NULL)
  df <- tibble::tibble(
    year       = c(2023L, 2023L),
    epiweek    = c(10L, 10L),
    department = c("Ouest", "Nord"),
    commune    = c("Port-au-Prince", "Cap-Haitien"),
    cases      = c(5L, 10L),
    population = c(0L, 2000L)
  )
  out <- add_anomaly_consistency(df, schema)
  pop_rows <- out[grepl("population", tolower(out$issue)), ]
  expect_gte(nrow(pop_rows), 1L)
  expect_equal(pop_rows$row[1], 1L)
})
