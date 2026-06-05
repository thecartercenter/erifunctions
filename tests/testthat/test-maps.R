#### Tests for maps.R ####

skip_no_sf <- function() {
  if (!requireNamespace("sf", quietly = TRUE)) skip("sf not installed")
}

.make_poly_sf <- function() {
  sf::st_sf(
    adm1_name = c("North", "South"),
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(0,-1,1,-1,1,0,0,0,0,-1), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
}

#### eri_map_choropleth ####

test_that("eri_map_choropleth returns a ggplot", {
  skip_no_sf()
  poly <- .make_poly_sf()
  dat  <- tibble::tibble(adm1_name = c("North", "South"), n_cases = c(10L, 5L))
  p    <- eri_map_choropleth(poly, dat, "n_cases", "adm1_name",
                              scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "gg")
})

test_that("eri_map_choropleth errors when admin_col missing from shapefile", {
  skip_no_sf()
  poly <- .make_poly_sf()
  dat  <- tibble::tibble(adm1_name = "North", n_cases = 10L)
  expect_error(
    eri_map_choropleth(poly, dat, "n_cases", "no_such_col",
                       scale_bar = FALSE, north_arrow = FALSE),
    "no_such_col"
  )
})

test_that("eri_map_choropleth errors when admin_col missing from fill_data", {
  skip_no_sf()
  poly <- .make_poly_sf()
  dat  <- tibble::tibble(other_col = "North", n_cases = 10L)
  expect_error(
    eri_map_choropleth(poly, dat, "n_cases", "adm1_name",
                       scale_bar = FALSE, north_arrow = FALSE),
    "adm1_name"
  )
})

test_that("eri_map_choropleth errors when fill_col missing from fill_data", {
  skip_no_sf()
  poly <- .make_poly_sf()
  dat  <- tibble::tibble(adm1_name = "North")
  expect_error(
    eri_map_choropleth(poly, dat, "no_col", "adm1_name",
                       scale_bar = FALSE, north_arrow = FALSE),
    "no_col"
  )
})

#### eri_map_incidence ####

test_that("eri_map_incidence returns a ggplot with incidence_class fill", {
  skip_no_sf()
  poly <- .make_poly_sf()
  dat  <- tibble::tibble(
    adm1_name = c("North", "South"),
    n_cases   = c(5L, 50L),
    pop       = c(10000L, 5000L)
  )
  p <- eri_map_incidence(poly, dat, "n_cases", "pop", "adm1_name",
                          scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "gg")
  built <- ggplot2::ggplot_build(p)
  expect_true(!is.null(built$data))
})

test_that("eri_map_incidence errors on missing columns", {
  skip_no_sf()
  poly <- .make_poly_sf()
  dat  <- tibble::tibble(adm1_name = "North", n_cases = 5L)
  expect_error(
    eri_map_incidence(poly, dat, "n_cases", "pop", "adm1_name",
                      scale_bar = FALSE, north_arrow = FALSE),
    "pop"
  )
})

#### eri_map_points ####

test_that("eri_map_points returns a ggplot", {
  skip_no_sf()
  poly <- .make_poly_sf()
  pts  <- tibble::tibble(lat = c(0.5, -0.5), lon = c(0.5, 0.5), result = c("Pos", "Neg"))
  p    <- eri_map_points(poly, pts, "lat", "lon",
                          scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "gg")
})

test_that("eri_map_points with fill_col returns a ggplot", {
  skip_no_sf()
  poly <- .make_poly_sf()
  pts  <- tibble::tibble(lat = c(0.5, -0.5), lon = c(0.5, 0.5), result = c("Pos", "Neg"))
  p    <- eri_map_points(poly, pts, "lat", "lon", fill_col = "result",
                          scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "gg")
})

test_that("eri_map_points errors on missing lat/lon column", {
  skip_no_sf()
  poly <- .make_poly_sf()
  pts  <- tibble::tibble(x = 0.5, y = 0.5)
  expect_error(eri_map_points(poly, pts, "lat", "lon",
                              scale_bar = FALSE, north_arrow = FALSE),
               "lat")
})

#### eri_map_inset ####

test_that("eri_map_inset returns a ggplot/cowplot object", {
  skip_no_sf()
  if (!requireNamespace("cowplot", quietly = TRUE)) skip("cowplot not installed")
  poly1 <- sf::st_sf(
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,2,0,2,2,0,2,0,0), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
  poly2 <- .make_poly_sf()
  main  <- eri_map_choropleth(
    poly2,
    tibble::tibble(adm1_name = c("North", "South"), n_cases = c(10L, 5L)),
    "n_cases", "adm1_name",
    scale_bar = FALSE, north_arrow = FALSE
  )
  result <- eri_map_inset(main, poly1, poly2)
  expect_s3_class(result, "gg")
})

test_that("eri_map_inset errors when position has wrong length", {
  skip_no_sf()
  if (!requireNamespace("cowplot", quietly = TRUE)) skip("cowplot not installed")
  poly   <- .make_poly_sf()
  main   <- ggplot2::ggplot()
  expect_error(eri_map_inset(main, poly, poly, position = c(0.5, 0.5)), "length 4")
})
