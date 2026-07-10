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

test_that("load_dq_schema error enumerates available bundled schemas", {
  expect_error(
    load_dq_schema("dr", "nonexistent_disease", azcontainer = NULL),
    "Available bundled schemas"
  )
  # the helpful list includes the real (renamed) schema the user is probably after
  expect_error(
    load_dq_schema("dr", "nonexistent_disease", azcontainer = NULL),
    "dr_malaria_surveillance_case"
  )
})

test_that("load_dq_schema resolves the ADR-0012 identity and legacy aliases", {
  # new (country, disease, data_source, data_type) identity
  s1 <- load_dq_schema("dr", "malaria", "surveillance", "case", azcontainer = NULL)
  expect_equal(s1$data_source, "surveillance")
  expect_equal(s1$data_type, "case")
  # research lane (optional/flexible measure)
  s2 <- load_dq_schema("dr", "lf", "research", "tas", azcontainer = NULL)
  expect_equal(s2$data_source, "research")
  expect_equal(s2$format, "odk")
  # legacy two-argument form aliases old keys to the new files
  expect_equal(load_dq_schema("dr", "malaria_case", azcontainer = NULL)$data_type, "case")
  expect_equal(load_dq_schema("schisto", "mda", azcontainer = NULL)$data_type, "treatment")
  expect_equal(load_dq_schema("haiti", "malaria", azcontainer = NULL)$data_type, "aggregate")
  expect_equal(load_dq_schema("ht", "malaria_case", azcontainer = NULL)$data_type, "case")
})

#### Tests for the real-field-code CMR treatment schemas (uga/ssd/sdn) ####

test_that("uga_oncho_programmatic_treatment schema resolves the real #rbtrt_ field codes", {
  schema <- load_dq_schema("uga", "oncho", "programmatic", "treatment", azcontainer = NULL)
  expect_true("district" %in% names(schema$columns))
  expect_true("#rbtrt_adm2" %in% schema$columns$district$aliases)
  expect_true("#rbtrt_tot" %in% schema$columns$treated$aliases)
  # rewritten schema: only district/year/treated required, NOT the old
  # community-level fields (round/sub_county/community), which the real CMR
  # does not carry at this grain
  expect_true(schema$columns$district$required)
  expect_true(schema$columns$treated$required)
  expect_false(isTRUE(schema$columns$sub_county$required))
})

test_that("uga_oncho schema flags a present-but-zero target_pop, not a missing one", {
  schema <- load_dq_schema("uga", "oncho", "programmatic", "treatment", azcontainer = NULL)
  df <- tibble::tibble(
    `#rbtrt_year` = c("2026", "2026", "2026"),
    `#rbtrt_adm2` = c("Arua", "Gulu", "Jinja"),
    `#rbtrt_tot`  = c("100", "200", "300"),
    `#rbtrt_trttarget` = c("0", NA_character_, "500")   # zero flagged; NA not required
  )
  res <- run_dq_checks(df, schema)
  expect_equal(nrow(res$flags[res$flags$column == "target_pop", ]), 1L)
  expect_equal(res$flags$row[res$flags$column == "target_pop"], 1L)
})

test_that("uga_oncho schema flags a district not in the real allowed_values list", {
  schema <- load_dq_schema("uga", "oncho", "programmatic", "treatment", azcontainer = NULL)
  df <- tibble::tibble(
    `#rbtrt_year` = "2026", `#rbtrt_adm2` = "Not A Real District", `#rbtrt_tot` = "50"
  )
  res <- run_dq_checks(df, schema)
  expect_true(any(res$flags$column == "district"))
})

test_that("uga_sch_programmatic_treatment schema loads and resolves #schtrt_ codes", {
  schema <- load_dq_schema("uga", "sch", "programmatic", "treatment", azcontainer = NULL)
  expect_true("#schtrt_adm2" %in% schema$columns$district$aliases)
  expect_true("Moyo" %in% schema$columns$district$allowed_values)
})

test_that("ssd_oncho_programmatic_treatment schema loads with the real district list", {
  schema <- load_dq_schema("ssd", "oncho", "programmatic", "treatment", azcontainer = NULL)
  expect_true("Juba" %in% schema$columns$district$allowed_values)
  expect_true("#rbtrt_adm2" %in% schema$columns$district$aliases)
})

test_that("sdn_oncho_programmatic_treatment schema loads and flags a zero target", {
  schema <- load_dq_schema("sdn", "oncho", "programmatic", "treatment", azcontainer = NULL)
  df <- tibble::tibble(
    `#rbtrt_year` = "2026", `#rbtrt_adm2` = "Barbar",
    `#rbtrt_tot` = "10", `#rbtrt_trttarget` = "0"
  )
  res <- run_dq_checks(df, schema)
  expect_true(any(res$flags$column == "target_pop"))
})

#### Tests for run_dq_checks()/schema carrying schema_source/schema_hash ####

test_that("load_dq_schema tags a bundled load with schema_source and a hash", {
  schema <- load_dq_schema("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  expect_equal(schema$schema_source, "bundled")
  expect_true(nzchar(schema$schema_hash))
})

test_that("run_dq_checks carries schema_source/schema_hash from the schema into the dq_result", {
  schema <- list(schema_source = "local_override", schema_hash = "abc123",
                 columns = list(x = list(required = FALSE, type = "numeric")))
  res <- run_dq_checks(tibble::tibble(x = 1), schema)
  expect_equal(res$schema_source, "local_override")
  expect_equal(res$schema_hash, "abc123")
})

test_that("run_dq_checks defaults schema_source/schema_hash to NA when the schema has none", {
  schema <- list(columns = list(x = list(required = FALSE, type = "numeric")))
  res <- run_dq_checks(tibble::tibble(x = 1), schema)
  expect_true(is.na(res$schema_source))
  expect_true(is.na(res$schema_hash))
})

test_that(".eri_dq_log_write records schema_source/schema_hash in the envelope", {
  schema <- list(schema_source = "local_override", schema_hash = "abc123",
                 columns = list(x = list(required = FALSE, type = "numeric")))
  res <- run_dq_checks(tibble::tibble(x = 1), schema)

  logged <- NULL
  local_mocked_bindings(
    .eri_write_log = function(op_log, con, dir, ...) { logged <<- op_log; "fake/log/path.yaml" },
    .package = "erifunctions"
  )
  suppressWarnings(
    .eri_dq_log_write(res, "atlantis", "oncho", "programmatic", "treatment", data_con = structure(list(), class = "mock"))
  )
  expect_equal(logged$schema_source, "local_override")
  expect_equal(logged$schema_hash, "abc123")
})

#### Tests for the DQ schema local override lifecycle ####

test_that("eri_dq_schema_edit forks the bundled schema and records a sidecar", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )

  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_true(file.exists(path))
  expect_true(file.exists(file.path(override_dir, "atlantis_oncho_programmatic_treatment.meta.yaml")))

  meta <- yaml::read_yaml(file.path(override_dir, "atlantis_oncho_programmatic_treatment.meta.yaml"))
  expect_equal(meta$base_source, "bundled")
  expect_true(nzchar(meta$base_hash))
})

test_that("load_dq_schema prefers a live local override over the bundled schema", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )

  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  # A typed edit a DA might make: widen the target_pop range
  override <- yaml::read_yaml(path)
  override$columns$target_pop$range <- list(0, 99999999)
  yaml::write_yaml(override, path)

  schema <- suppressWarnings(
    load_dq_schema("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_equal(schema$schema_source, "local_override")
  expect_equal(schema$columns$target_pop$range[[2]], 99999999)
})

test_that("eri_dq_schema_path returns the override path when one is live", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  found <- suppressWarnings(
    eri_dq_schema_path("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_equal(found, path)
})

test_that("load_dq_schema retires a stale override (base_hash no longer matches upstream)", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  meta_path <- file.path(override_dir, "atlantis_oncho_programmatic_treatment.meta.yaml")
  meta <- yaml::read_yaml(meta_path)
  meta$base_hash <- "not-the-real-hash"   # simulate the upstream having changed since the fork
  yaml::write_yaml(meta, meta_path)

  schema <- suppressWarnings(
    load_dq_schema("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_equal(schema$schema_source, "bundled")   # fell back to upstream
  expect_false(file.exists(path))                 # override renamed away, not left in place
  expect_false(file.exists(meta_path))
  retired <- list.files(override_dir, pattern = "\\.retired-.*\\.yaml$")
  expect_length(retired, 2L)   # the .yaml and the .meta.yaml
})

test_that("eri_dq_schema_status reports a stale override without retiring it", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  meta_path <- file.path(override_dir, "atlantis_oncho_programmatic_treatment.meta.yaml")
  meta <- yaml::read_yaml(meta_path)
  meta$base_hash <- "not-the-real-hash"
  yaml::write_yaml(meta, meta_path)

  status <- suppressWarnings(eri_dq_schema_status(azcontainer = NULL))
  expect_equal(status$status[status$stem == "atlantis_oncho_programmatic_treatment"],
               "stale (will be retired on next load)")
  # read-only: the override must still be exactly where it was
  expect_true(file.exists(path))
  expect_true(file.exists(meta_path))
})

test_that("eri_dq_schema_status reports no overrides when there are none", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  status <- eri_dq_schema_status(azcontainer = NULL)
  expect_equal(nrow(status), 0L)
})

test_that("eri_dq_schema_reset deletes an override and leaves retired ones alone", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  meta_path <- file.path(override_dir, "atlantis_oncho_programmatic_treatment.meta.yaml")

  # non-interactive test session -> confirm prompt is skipped, deletes directly
  ok <- eri_dq_schema_reset("atlantis", "oncho", "programmatic", "treatment")
  expect_true(ok)
  expect_false(file.exists(path))
  expect_false(file.exists(meta_path))
})

test_that("eri_dq_schema_reset is a no-op when there is nothing to reset", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  ok <- eri_dq_schema_reset("atlantis", "oncho", "programmatic", "treatment")
  expect_false(ok)
})

test_that("eri_dq_schema_edit is idempotent when the existing override is still fresh", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path1 <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  # A DA's edit -- must survive a second eri_dq_schema_edit() call, not be
  # silently clobbered by a fresh fork.
  override <- yaml::read_yaml(path1)
  override$columns$target_pop$range <- list(0, 42)
  yaml::write_yaml(override, path1)

  path2 <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_equal(path1, path2)
  expect_equal(yaml::read_yaml(path2)$columns$target_pop$range[[2]], 42)
})

test_that("load_dq_schema falls back to a live override, not an abort, when upstream is unreachable", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )

  # Now simulate "upstream unreachable" (Azure down AND no bundled copy for
  # this stem) -- a live override must still be usable, not treated the same
  # as a network outage meaning "abort" or "this fix is stale."
  local_mocked_bindings(
    .eri_dq_schema_upstream = function(stem, azcontainer) NULL,
    .package = "erifunctions"
  )

  schema <- suppressWarnings(
    load_dq_schema("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_equal(schema$schema_source, "local_override")
  expect_true(file.exists(path))   # not retired -- staleness couldn't be checked, so it's left alone
})

test_that("eri_dq_schema_edit returns the existing override, not an abort, when upstream is unreachable", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  path <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )

  local_mocked_bindings(
    .eri_dq_schema_upstream = function(stem, azcontainer) NULL,
    .package = "erifunctions"
  )

  path2 <- suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  expect_equal(path, path2)
  expect_true(file.exists(path2))
})

test_that("eri_dq_schema_status reports 'unknown' (not an error) when upstream is unreachable", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  suppressWarnings(
    eri_dq_schema_edit("atlantis", "oncho", "programmatic", "treatment", azcontainer = NULL)
  )
  local_mocked_bindings(
    .eri_dq_schema_upstream = function(stem, azcontainer) NULL,
    .package = "erifunctions"
  )
  status <- eri_dq_schema_status(azcontainer = NULL)
  expect_equal(status$status[status$stem == "atlantis_oncho_programmatic_treatment"],
               "unknown (upstream unreachable)")
})

test_that(".eri_dq_schema_retire numbers a second same-second retirement instead of colliding", {
  override_dir <- withr::local_tempdir()
  stem  <- "atlantis_oncho_programmatic_treatment"
  paths <- list(yaml = file.path(override_dir, paste0(stem, ".yaml")),
               meta = file.path(override_dir, paste0(stem, ".meta.yaml")))
  writeLines("a: 1", paths$yaml); writeLines("b: 2", paths$meta)

  # Pre-seed a retirement for "right now" so a second one in the same second
  # would collide if not guarded.
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  writeLines("x", file.path(override_dir, paste0(stem, ".retired-", stamp, ".yaml")))
  writeLines("x", file.path(override_dir, paste0(stem, ".retired-", stamp, ".meta.yaml")))

  ok <- .eri_dq_schema_retire(stem, paths)
  expect_true(ok)
  expect_false(file.exists(paths$yaml))
  expect_false(file.exists(paths$meta))
  # 2 pre-seeded (.yaml + .meta.yaml) + 2 newly retired with a numeric suffix
  # to avoid colliding with them
  retired <- list.files(override_dir, pattern = "\\.retired-.*\\.yaml$")
  expect_length(retired, 4L)
  expect_true(any(grepl(paste0(stem, "\\.retired-", stamp, "-1\\.yaml$"), retired)))
})

test_that("load_dq_schema legacy two-argument form never resolves a local override", {
  override_dir <- withr::local_tempdir()
  local_mocked_bindings(
    .eri_schema_override_dir = function() override_dir,
    .package = "erifunctions"
  )
  suppressWarnings(
    eri_dq_schema_edit("dr", "malaria", "surveillance", "case", azcontainer = NULL)
  )
  # Modify the override so a leak would be detectable
  override_path <- file.path(override_dir, "dr_malaria_surveillance_case.yaml")
  override <- yaml::read_yaml(override_path)
  override$columns$year$range <- list(1, 2)  # absurd, would be obviously wrong if it leaked in
  yaml::write_yaml(override, override_path)

  schema <- load_dq_schema("dr", "malaria_case", azcontainer = NULL)  # legacy form
  expect_equal(schema$schema_source, "bundled")
  expect_false(identical(schema$columns$year$range, list(1, 2)))
})
