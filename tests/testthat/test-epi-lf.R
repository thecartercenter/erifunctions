#### Tests for epi_lf.R ####

skip_no_sf <- function() {
  if (!requireNamespace("sf", quietly = TRUE)) skip("sf not installed")
}

#### eri_lf_pooled_prev ####

test_that("eri_lf_pooled_prev returns correct prevalence", {
  # 1 - ((1 - 3/100)^(1/5)) = 1 - (0.97^0.2) ≈ 0.006097
  result <- eri_lf_pooled_prev(3, 100, 5)
  expect_type(result, "double")
  expect_equal(round(result, 4), round(1 - (1 - 3/100)^(1/5), 4))
})

test_that("eri_lf_pooled_prev returns 0 when npos is 0", {
  result <- eri_lf_pooled_prev(0, 100, 5)
  expect_equal(result, 0)
})

test_that("eri_lf_pooled_prev is vectorized", {
  result <- eri_lf_pooled_prev(c(0, 1, 5), c(100, 100, 100), c(5, 5, 5))
  expect_equal(length(result), 3L)
  expect_equal(result[1], 0)
  expect_true(result[3] > result[2])
})

test_that("eri_lf_pooled_prev warns when npos > npool", {
  expect_warning(eri_lf_pooled_prev(c(5, 120), c(100, 100), c(5, 5)), "npos")
  result <- suppressWarnings(eri_lf_pooled_prev(c(5, 120), c(100, 100), c(5, 5)))
  expect_true(is.na(result[2]))
})

test_that("eri_lf_pooled_prev errors when npool <= 0", {
  expect_error(eri_lf_pooled_prev(5, 0, 5), "npool")
})

#### eri_lf_program_levels ####

test_that("eri_lf_program_levels returns character vector of length 5", {
  result <- eri_lf_program_levels()
  expect_type(result, "character")
  expect_equal(length(result), 5L)
})

test_that("eri_lf_program_levels starts with Non-endemic and ends with PTS TAS-3", {
  result <- eri_lf_program_levels()
  expect_equal(result[1], "Non-endemic")
  expect_equal(result[5], "PTS (Passed TAS-3)")
})

test_that("eri_lf_program_levels can be used to create a factor", {
  lvls   <- eri_lf_program_levels()
  f      <- factor(c("MDA started", "Non-endemic"), levels = lvls)
  expect_equal(as.integer(f), c(3L, 1L))  # Non-endemic = 1, MDA started = 3
})

#### eri_lf_tas_summary ####

test_that("eri_lf_tas_summary produces correct cross-tab", {
  df <- tibble::tibble(
    fts = c("Positive", "Negative", "Negative", "Positive"),
    rdt = c("Positive", "Negative", "Negative", "Negative")
  )
  result <- eri_lf_tas_summary(df, "fts", "rdt")
  expect_s3_class(result, "tbl_df")
  expect_true("fts_result" %in% names(result))
  expect_true("rdt_result" %in% names(result))
  expect_true("n" %in% names(result))
  expect_true("pct" %in% names(result))
  expect_equal(sum(result$n), 4L)
})

test_that("eri_lf_tas_summary preserves unknown FTS/RDT values", {
  df <- tibble::tibble(
    fts = c("Positive", "Inconclusive", "Negative"),
    rdt = c("Positive", "Negative", "Negative")
  )
  result <- eri_lf_tas_summary(df, "fts", "rdt")
  expect_true("Inconclusive" %in% result$fts_result)
})

test_that("eri_lf_tas_summary with group_col returns one block per group", {
  df <- tibble::tibble(
    eu  = c("EU1", "EU1", "EU2", "EU2"),
    fts = c("Positive", "Negative", "Negative", "Negative"),
    rdt = c("Positive", "Negative", "Negative", "Negative")
  )
  result <- eri_lf_tas_summary(df, "fts", "rdt", group_col = "eu")
  expect_true("eu" %in% names(result))
  eu1_rows <- result[result$eu == "EU1", ]
  expect_equal(sum(eu1_rows$n), 2L)
})

test_that("eri_lf_tas_summary errors on missing column", {
  df <- tibble::tibble(fts = "Positive", rdt = "Negative")
  expect_error(eri_lf_tas_summary(df, "missing_col", "rdt"), "missing_col")
})

#### eri_lf_status_map ####

test_that("eri_lf_status_map returns a ggplot", {
  skip_no_sf()
  poly <- sf::st_sf(
    eu_name  = c("EU1", "EU2"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(0,-1,1,-1,1,0,0,0,0,-1), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
  dat <- tibble::tibble(
    eu_name = c("EU1", "EU2"),
    status  = c("MDA started", "PTS (Passed TAS-1)")
  )
  p <- eri_lf_status_map(poly, dat, "eu_name", "status",
                          scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "gg")
})

test_that("eri_lf_status_map handles NA status values without error", {
  skip_no_sf()
  poly <- sf::st_sf(
    eu_name  = c("EU1", "EU2"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(0,-1,1,-1,1,0,0,0,0,-1), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
  dat <- tibble::tibble(
    eu_name = c("EU1"),
    status  = c("MDA started")
  )
  p <- eri_lf_status_map(poly, dat, "eu_name", "status",
                          scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "gg")
})
