#### Tests for add_anomaly_consistency ####

test_that("add_anomaly_consistency flags field-to-field violation", {
  schema <- list(
    consistency = list(
      pos_le_tested = list(lhs = "pos", op = "<=", rhs = "tested",
                           message = "Positives exceed tested")
    )
  )
  df <- tibble::tibble(tested = c(100L, 50L, 80L),
                       pos    = c(10L,  60L, 20L))  # row 2 violates
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 2L)
  expect_equal(out$column, "pos")
  expect_true(grepl("pos_le_tested", out$issue))
})

test_that("add_anomaly_consistency flags field-to-value violation", {
  schema <- list(
    consistency = list(
      age_nonneg = list(lhs = "age", op = ">=", rhs_value = 0,
                        message = "Age is negative")
    )
  )
  df  <- tibble::tibble(age = c(10L, -1L, 5L))
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 2L)
})

test_that("add_anomaly_consistency returns empty tibble when all pass", {
  schema <- list(
    consistency = list(
      pos_le_tested = list(lhs = "pos", op = "<=", rhs = "tested",
                           message = "Positives exceed tested")
    )
  )
  df  <- tibble::tibble(tested = c(100L, 50L), pos = c(10L, 20L))
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 0L)
})

test_that("add_anomaly_consistency returns empty tibble when no rules defined", {
  schema <- list()
  df     <- tibble::tibble(x = 1:3)
  out    <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 0L)
})

test_that("add_anomaly_consistency skips NA values without error", {
  schema <- list(
    consistency = list(
      pos_le_tested = list(lhs = "pos", op = "<=", rhs = "tested",
                           message = "test")
    )
  )
  df  <- tibble::tibble(tested = c(100L, NA_integer_, 80L),
                        pos    = c(10L,  60L,         90L))  # row 3 violates; row 2 is NA
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 3L)
})

test_that("add_anomaly_consistency works on dq_result and appends flags", {
  schema <- list(
    consistency = list(
      pos_le_tested = list(lhs = "pos", op = "<=", rhs = "tested",
                           message = "test")
    )
  )
  df <- tibble::tibble(tested = c(100L, 50L), pos = c(10L, 60L))
  dqr <- structure(
    list(
      data  = df,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
  out <- add_anomaly_consistency(dqr, schema)
  expect_s3_class(out, "dq_result")
  expect_equal(nrow(out$flags), 1L)
  expect_true(grepl("consistency", out$flags$issue))
})

test_that("add_anomaly_consistency uses Haiti schema rules correctly", {
  schema <- load_dq_schema("haiti", "malaria", azcontainer = NULL)
  df <- tibble::tibble(
    NumTestedMicro     = c(100L, 50L),
    NumMicroPos        = c(10L,  60L),   # row 2: 60 > 50, violation
    NumTestedTDRInstit = c(200L, 200L),
    NumRDTPosInstit    = c(20L,  20L),
    NumTestedComm      = c(300L, 300L),
    NumRDTPosComm      = c(30L,  30L),
    NumPosInstit       = c(15L,  15L),
    NumDeaths          = c(1L,   1L)
  )
  out <- add_anomaly_consistency(df, schema)
  expect_equal(nrow(out), 1L)
  expect_equal(out$column, "NumMicroPos")
})

#### Shared helpers ####

make_surveillance <- function() {
  tibble::tibble(
    Year     = c(rep(2024L, 6), rep(2025L, 4)),
    EpiWeek  = c(1L, 2L, 3L, 4L, 5L, 6L, 1L, 2L, 3L, 4L),
    Province = c(rep("North", 5), rep("South", 5)),
    n_cases  = c(10L, 11L, 12L, 50L, 13L,
                 5L,  6L,  5L,  6L,  5L)
  )
}

make_gapped <- function() {
  # Week 3 missing for North; complete for South
  tibble::tibble(
    Year     = rep(2024L, 9),
    EpiWeek  = c(1L, 2L, 4L, 5L,   # North: week 3 missing
                 1L, 2L, 3L, 4L, 5L),
    Province = c(rep("North", 4), rep("South", 5)),
    n_cases  = c(10L, 11L, 13L, 14L, 5L, 6L, 5L, 6L, 5L)
  )
}

test_that("add_anomaly_gaps detects missing week", {
  df   <- make_gapped()
  gaps <- add_anomaly_gaps(df, "EpiWeek", "week",
                            group_cols = "Province", year_col = "Year")
  expect_equal(nrow(gaps), 1L)
  expect_equal(gaps$Province, "North")
  expect_equal(gaps$EpiWeek, 3L)
  expect_equal(gaps$issue, "structural_gap")
})

test_that("add_anomaly_gaps returns empty tibble when no gaps", {
  df   <- make_surveillance()
  gaps <- add_anomaly_gaps(df, "EpiWeek", "week",
                            group_cols = "Province", year_col = "Year")
  expect_equal(nrow(gaps), 0L)
})

test_that("add_anomaly_gaps errors on missing period_col", {
  df <- tibble::tibble(week = 1:3, n = 1:3)
  expect_error(add_anomaly_gaps(df, "EpiWeek", "week"), "period_col")
})

test_that("add_anomaly_gaps works on dq_result and appends flags", {
  df  <- make_gapped()
  dqr <- structure(
    list(
      data  = df,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
  out <- add_anomaly_gaps(dqr, "EpiWeek", "week",
                           group_cols = "Province", year_col = "Year")
  expect_s3_class(out, "dq_result")
  expect_gt(nrow(out$flags), 0L)
  expect_true(all(grepl("structural_gap", out$flags$issue)))
  expect_true(all(is.na(out$flags$row)))
})

#### Tests for add_anomaly_pct_change ####

test_that("add_anomaly_pct_change flags known spike", {
  df  <- make_surveillance()
  out <- add_anomaly_pct_change(df, "n_cases", "EpiWeek",
                                 threshold  = 0.5,
                                 group_cols = "Province",
                                 year_col   = "Year")

  flag_col <- "anomaly_pct_change_n_cases"
  pct_col  <- "pct_change_n_cases"

  expect_true(flag_col %in% names(out))
  expect_true(pct_col  %in% names(out))

  # Row where North jumps from 12 to 50 should be flagged
  north_spike <- out[out$Province == "North" & out$EpiWeek == 4 & out$Year == 2024, ]
  expect_true(north_spike[[flag_col]])
  expect_gt(north_spike[[pct_col]], 2)  # >200% change
})

test_that("add_anomaly_pct_change does not flag stable series", {
  df  <- make_surveillance()
  out <- add_anomaly_pct_change(df, "n_cases", "EpiWeek",
                                 threshold  = 0.5,
                                 group_cols = "Province",
                                 year_col   = "Year")

  south_rows <- out[out$Province == "South", ]
  expect_false(any(south_rows[["anomaly_pct_change_n_cases"]], na.rm = TRUE))
})

test_that("add_anomaly_pct_change produces NA pct_change for first row per group", {
  df  <- make_surveillance()
  out <- add_anomaly_pct_change(df, "n_cases", "EpiWeek",
                                 group_cols = "Province",
                                 year_col   = "Year")

  first_per_group <- out |>
    dplyr::group_by(Province) |>
    dplyr::slice_min(order_by = Year * 1000 + EpiWeek, n = 1) |>
    dplyr::ungroup()

  expect_true(all(is.na(first_per_group[["pct_change_n_cases"]])))
})

test_that("add_anomaly_pct_change works without group_cols", {
  df  <- tibble::tibble(period = 1:5, n = c(10, 11, 12, 50, 13))
  out <- add_anomaly_pct_change(df, "n", "period", threshold = 0.5)
  expect_true("anomaly_pct_change_n" %in% names(out))
  expect_true(out$anomaly_pct_change_n[4])  # 50/12 - 1 > 0.5
})

test_that("add_anomaly_pct_change errors on missing value_col", {
  df <- tibble::tibble(period = 1:3, n = 1:3)
  expect_error(add_anomaly_pct_change(df, "missing", "period"), "value_col")
})

test_that("add_anomaly_pct_change works on dq_result and appends flags", {
  df  <- make_surveillance()
  # Build a minimal dq_result by hand
  dqr <- structure(
    list(
      data  = df,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
  out <- add_anomaly_pct_change(dqr, "n_cases", "EpiWeek",
                                 threshold  = 0.5,
                                 group_cols = "Province",
                                 year_col   = "Year")

  expect_s3_class(out, "dq_result")
  expect_true("anomaly_pct_change_n_cases" %in% names(out$data))
  expect_gt(nrow(out$flags), 0)
  expect_true(all(out$flags$column == "n_cases"))
  expect_true(all(grepl("% change anomaly", out$flags$issue)))
})

#### Tests for add_anomaly_spatial ####

test_that("add_anomaly_spatial returns empty flags tibble when admin block absent", {
  df     <- tibble::tibble(Province = c("Santo Domingo", "Santiago"))
  schema <- list()
  out    <- suppressMessages(add_anomaly_spatial(df, schema, azcontainer = NULL))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_true(all(c("row", "column", "value", "issue") %in% names(out)))
})

test_that("add_anomaly_spatial returns empty flags when all names match", {
  df     <- tibble::tibble(Province = c("Santo Domingo", "Santiago"))
  schema <- list(
    admin = list(admin1_col = "Province", admin1_spatial = "fake.shp",
                 admin1_name_field = "adm1_name")
  )
  with_mocked_bindings(
    .eri_load_spatial_names = function(...) c("Santo Domingo", "Santiago", "La Vega"),
    {
      out <- add_anomaly_spatial(df, schema, azcontainer = NULL)
    }
  )
  expect_equal(nrow(out), 0L)
})

test_that("add_anomaly_spatial flags unrecognized admin name", {
  df     <- tibble::tibble(Province = c("Santo Domingo", "Typo Province"))
  schema <- list(
    admin = list(admin1_col = "Province", admin1_spatial = "fake.shp",
                 admin1_name_field = "adm1_name")
  )
  with_mocked_bindings(
    .eri_load_spatial_names = function(...) c("Santo Domingo", "Santiago"),
    {
      out <- suppressWarnings(add_anomaly_spatial(df, schema, azcontainer = NULL))
    }
  )
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 2L)
  expect_equal(out$column, "Province")
  expect_equal(out$value, "Typo Province")
  expect_equal(out$issue, "unrecognized admin name")
})

test_that("add_anomaly_spatial warns and skips when spatial ref unavailable", {
  df     <- tibble::tibble(Province = c("Santo Domingo"))
  schema <- list(
    admin = list(admin1_col = "Province", admin1_spatial = "fake.shp",
                 admin1_name_field = "adm1_name")
  )
  with_mocked_bindings(
    .eri_load_spatial_names = function(...) NULL,
    {
      expect_warning(
        out <- add_anomaly_spatial(df, schema, azcontainer = NULL),
        "Spatial reference unavailable"
      )
    }
  )
  expect_equal(nrow(out), 0L)
})

test_that("add_anomaly_spatial appends to dq_result flags", {
  df <- tibble::tibble(Province = c("Santo Domingo", "BADNAME"))
  dqr <- structure(
    list(
      data  = df,
      log   = tibble::tibble(row = integer(), column = character(),
                             original_value = character(), corrected_value = character(),
                             rule = character(), action = character()),
      flags = tibble::tibble(row = integer(), column = character(),
                             value = character(), issue = character())
    ),
    class = "dq_result"
  )
  schema <- list(
    admin = list(admin1_col = "Province", admin1_spatial = "fake.shp",
                 admin1_name_field = "adm1_name")
  )
  with_mocked_bindings(
    .eri_load_spatial_names = function(...) c("Santo Domingo"),
    {
      out <- suppressWarnings(add_anomaly_spatial(dqr, schema, azcontainer = NULL))
    }
  )
  expect_s3_class(out, "dq_result")
  expect_equal(nrow(out$flags), 1L)
  expect_equal(out$flags$row, 2L)
  expect_equal(out$flags$issue, "unrecognized admin name")
})

test_that("add_anomaly_spatial skips admin2 when name_field not in schema", {
  df     <- tibble::tibble(Province = c("Santo Domingo"), Commune = c("Bad Commune"))
  schema <- list(
    admin = list(
      admin1_col = "Province", admin1_spatial = "fake.shp", admin1_name_field = "adm1_name",
      admin2_col = "Commune",  admin2_spatial = "fake2.shp"
      # admin2_name_field intentionally absent
    )
  )
  call_count <- 0L
  with_mocked_bindings(
    .eri_load_spatial_names = function(...) { call_count <<- call_count + 1L; c("Santo Domingo") },
    {
      out <- add_anomaly_spatial(df, schema, azcontainer = NULL)
    }
  )
  # Only admin1 check fires
  expect_equal(call_count, 1L)
  expect_equal(nrow(out), 0L)
})

test_that("dq_report surfaces example offending values and points to result$flags", {
  result <- list(
    data = tibble::tibble(a = 1:10),
    log  = tibble::tibble(row = integer(), column = character(), original_value = character(),
                          corrected_value = character(), rule = character(), action = character()),
    flags = tibble::tibble(
      row    = c(4L, 2L),
      column = c("species", "species"),
      value  = c("P.vivax", "P.ovale"),
      issue  = c("not in allowed_values", "not in allowed_values")
    )
  )

  # collapse + squash whitespace so a wrapped line never splits a token
  out <- gsub("[[:space:]]+", " ", paste(cli::cli_fmt(dq_report(result)), collapse = " "))

  expect_true(grepl("P.vivax", out, fixed = TRUE))        # the offending value
  expect_true(grepl("row 4",   out, fixed = TRUE))        # and its row number
  expect_true(grepl("result$flags", out, fixed = TRUE))   # pointer to detail
})

test_that("dq_report truncates the example list with a '+N more' suffix", {
  result <- list(
    data = tibble::tibble(a = 1:10),
    log  = tibble::tibble(row = integer(), column = character(), original_value = character(),
                          corrected_value = character(), rule = character(), action = character()),
    flags = tibble::tibble(
      row    = 1:6,
      column = rep("epiweek", 6),
      value  = as.character(60:65),
      issue  = rep("out of range", 6)
    )
  )

  out <- gsub("[[:space:]]+", " ", paste(cli::cli_fmt(dq_report(result)), collapse = " "))
  expect_true(grepl("+3 more", out, fixed = TRUE))   # 6 rows, 3 shown
})
