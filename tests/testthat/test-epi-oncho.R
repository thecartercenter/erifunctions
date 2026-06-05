#### eri_oncho_program_levels ####

test_that("eri_oncho_program_levels returns correct 5-level vector", {
  lvls <- eri_oncho_program_levels()
  expect_type(lvls, "character")
  expect_length(lvls, 5L)
  expect_equal(lvls[1], "Non-endemic")
  expect_equal(lvls[5], "Verified free of transmission")
})

test_that("eri_oncho_program_levels levels are ordered by program progression", {
  lvls <- eri_oncho_program_levels()
  expect_true("MDA ongoing" %in% lvls)
  expect_true("MDA stopped - under surveillance" %in% lvls)
  mda_idx  <- which(lvls == "MDA ongoing")
  stop_idx <- which(lvls == "MDA stopped - under surveillance")
  free_idx <- which(lvls == "Verified free of transmission")
  expect_lt(mda_idx, stop_idx)
  expect_lt(stop_idx, free_idx)
})

#### eri_oncho_status_map ####

test_that("eri_oncho_status_map errors if sf not inheriting correctly", {
  skip_if_not_installed("sf")
  bad_input <- data.frame(focus = "A", status = "MDA ongoing")
  expect_error(eri_oncho_status_map(bad_input, bad_input, "focus", "status"),
               "sf object")
})

test_that("eri_oncho_status_map errors on missing eu_col in shapefile", {
  skip_if_not_installed("sf")
  shp <- sf::st_sf(
    wrong_col = "Focus A",
    geometry  = sf::st_sfc(sf::st_point(c(-75, 18))),
    crs       = 4326
  )
  df <- tibble::tibble(focus = "Focus A", status = "MDA ongoing")
  expect_error(eri_oncho_status_map(shp, df, "focus", "status"), "eu_col")
})

test_that("eri_oncho_status_map errors on missing status_col in status_data", {
  skip_if_not_installed("sf")
  shp <- sf::st_sf(
    focus    = "Focus A",
    geometry = sf::st_sfc(sf::st_point(c(-75, 18))),
    crs      = 4326
  )
  df <- tibble::tibble(focus = "Focus A", wrong_col = "MDA ongoing")
  expect_error(eri_oncho_status_map(shp, df, "focus", "status"), "status_col")
})

test_that("eri_oncho_status_map returns a ggplot object", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  shp <- sf::st_sf(
    focus    = c("Focus A", "Focus B"),
    geometry = sf::st_sfc(
      sf::st_point(c(-75, 18)),
      sf::st_point(c(-74, 17))
    ),
    crs = 4326
  )
  df <- tibble::tibble(
    focus  = c("Focus A", "Focus B"),
    status = c("MDA ongoing", "Non-endemic")
  )
  p <- eri_oncho_status_map(shp, df, "focus", "status", title = "Test Map",
                             scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("eri_oncho_status_map factors status using program levels", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  shp <- sf::st_sf(
    focus    = "Focus A",
    geometry = sf::st_sfc(sf::st_point(c(-75, 18))),
    crs      = 4326
  )
  df <- tibble::tibble(focus = "Focus A", status = "MDA ongoing")
  p <- eri_oncho_status_map(shp, df, "focus", "status",
                             scale_bar = FALSE, north_arrow = FALSE)
  plot_data <- ggplot2::ggplot_build(p)$data[[1]]
  expect_false(is.null(plot_data))
})
