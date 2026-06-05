#### Tests for spatial.R ####

skip_no_sf <- function() {
  if (!requireNamespace("sf", quietly = TRUE)) skip("sf not installed")
}

#### eri_bbox_expand ####

test_that("eri_bbox_expand expands all four sides", {
  skip_no_sf()
  poly   <- sf::st_sfc(sf::st_point(c(-71.7, 19.0)), crs = 4326) |>
    sf::st_buffer(0.1) |>
    sf::st_bbox() |>
    sf::st_as_sfc()
  bb_in  <- sf::st_bbox(poly)
  bb_out <- eri_bbox_expand(bb_in, X = 10000, Y = 10000)
  expect_lt(bb_out[["xmin"]], bb_in[["xmin"]])
  expect_gt(bb_out[["xmax"]], bb_in[["xmax"]])
  expect_lt(bb_out[["ymin"]], bb_in[["ymin"]])
  expect_gt(bb_out[["ymax"]], bb_in[["ymax"]])
})

test_that("eri_bbox_expand asymmetric X2 only expands east side", {
  skip_no_sf()
  poly  <- sf::st_sfc(sf::st_point(c(-72, 19)), crs = 4326) |>
    sf::st_buffer(0.1) |>
    sf::st_bbox() |>
    sf::st_as_sfc()
  bb_in  <- sf::st_bbox(poly)
  bb_out <- eri_bbox_expand(bb_in, X = 0, Y = 0, X2 = 20000, Y2 = 0)
  expect_equal(bb_out[["xmin"]], bb_in[["xmin"]])
  expect_gt(bb_out[["xmax"]], bb_in[["xmax"]])
  expect_equal(bb_out[["ymin"]], bb_in[["ymin"]])
  expect_equal(bb_out[["ymax"]], bb_in[["ymax"]])
})

#### eri_spatial_join ####

test_that("eri_spatial_join attaches polygon attributes to points", {
  skip_no_sf()
  poly <- sf::st_sf(
    adm1_name = c("North", "South"),
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(0,-1,1,-1,1,0,0,0,0,-1), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
  pts <- tibble::tibble(id = 1:2, lon = c(0.5, 0.5), lat = c(0.5, -0.5))
  result <- eri_spatial_join(pts, lat_col = "lat", lon_col = "lon", shapefile = poly)
  expect_s3_class(result, "tbl_df")
  expect_true("adm1_name" %in% names(result))
  expect_equal(result$adm1_name, c("North", "South"))
})

test_that("eri_spatial_join drops NA coordinates with a warning", {
  skip_no_sf()
  poly <- sf::st_sf(
    adm1_name = "Region",
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
  pts <- tibble::tibble(id = 1:3, lon = c(0.5, NA, 0.7), lat = c(0.5, 0.5, NA))
  expect_warning(
    result <- eri_spatial_join(pts, "lat", "lon", poly),
    regexp = "NA"
  )
  expect_equal(nrow(result), 1L)
})

test_that("eri_spatial_join errors on missing lat/lon column", {
  skip_no_sf()
  poly <- sf::st_sf(
    adm1_name = "A",
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,0), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
  df <- tibble::tibble(x = 1, y = 2)
  expect_error(eri_spatial_join(df, "lat", "lon", poly), "lat_col")
})

#### eri_spatial_upload validation ####

test_that("eri_spatial_upload errors when file not found", {
  expect_error(eri_spatial_upload("/no/such/file.shp", "dr", 2), "not found")
})

test_that("eri_spatial_upload errors for level out of range", {
  expect_error(eri_spatial_upload(tempfile(), "dr", 9), "level")
})

test_that("eri_spatial_upload blocks upload when CRS is missing", {
  skip_no_sf()
  tmp_dir <- withr::local_tempdir()
  # Write with a valid CRS, then remove the .prj file so it reads back with NA CRS
  sf_obj  <- sf::st_sf(
    adm2_name = "Dist A",
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  sf::st_write(sf_obj, file.path(tmp_dir, "test.shp"), quiet = TRUE)
  unlink(file.path(tmp_dir, "test.prj"))
  expect_error(
    eri_spatial_upload(file.path(tmp_dir, "test.shp"), "dr", 2),
    "CRS"
  )
})

test_that("eri_spatial_upload blocks upload when required name column is missing", {
  skip_no_sf()
  tmp_dir <- withr::local_tempdir()
  sf_obj  <- sf::st_sf(
    wrong_col = "Dist A",
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  sf::st_write(sf_obj, file.path(tmp_dir, "test.shp"), quiet = TRUE)
  expect_error(
    eri_spatial_upload(file.path(tmp_dir, "test.shp"), "dr", 2),
    "adm2_name"
  )
})

#### eri_spatial_load ####

test_that("eri_spatial_load errors informatively when file not in Azure", {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "fake_con",
    eri_file_exists              = function(...) FALSE,
    .package = "erifunctions"
  )
  expect_error(eri_spatial_load("dr", 2), "Upload it first")
})

test_that("eri_spatial_load(cache=TRUE) delegates to eri_research_pull and returns the sf", {
  skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()

  # The "downloaded" boundary that eri_research_pull would produce.
  fake_sf <- sf::st_sf(
    adm2_name = "Azua",
    geometry  = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
  )
  cached_path <- file.path(tmp, "adm2.rds")
  saveRDS(fake_sf, cached_path)

  pulled <- NULL
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "fake_con",
    eri_file_exists              = function(...) TRUE,
    eri_research_pull            = function(path, dest, data_con, ...) {
      pulled <<- list(path = path, dest = dest)
      cached_path
    },
    .package = "erifunctions"
  )

  out <- eri_spatial_load("dr", 2, cache = TRUE, dest = tmp)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 1L)
  # delegated to the pull entry point with the canonical spatial path
  expect_equal(pulled$path, "spatial/dr/adm2.rds")
  expect_equal(pulled$dest, tmp)
})

#### eri_landscan_upload validation ####

test_that("eri_landscan_upload errors on invalid year", {
  expect_error(eri_landscan_upload("some.tif", 1990), "year")
  expect_error(eri_landscan_upload("some.tif", 3000), "year")
})

test_that("eri_landscan_upload errors when file not found", {
  expect_error(eri_landscan_upload("/no/such/file.tif", 2024), "not found")
})

test_that("eri_landscan_upload errors when filename is the colorized version", {
  tmp_dir <- withr::local_tempdir()
  bad_file <- file.path(tmp_dir, "landscan-global-2024-colorized.tif")
  writeLines("", bad_file)
  expect_error(eri_landscan_upload(bad_file, 2024), "colorized")
})

test_that("eri_landscan_upload errors when year in filename does not match year arg", {
  tmp_dir  <- withr::local_tempdir()
  bad_file <- file.path(tmp_dir, "landscan-global-2023.tif")
  writeLines("", bad_file)
  expect_error(eri_landscan_upload(bad_file, 2024), "landscan-global-2024")
})

#### eri_landscan_list ####

test_that("eri_landscan_list parses year from filename and sorts descending", {
  fake_files <- tibble::tibble(
    name         = c(
      "spatial/landscan/landscan-global-2022.tif",
      "spatial/landscan/landscan-global-2024.tif",
      "spatial/landscan/landscan-global-2023.tif"
    ),
    size         = c(100L, 100L, 100L),
    isdir        = c(FALSE, FALSE, FALSE),
    lastModified = as.POSIXct(c("2022-01-01", "2024-01-01", "2023-01-01"))
  )
  local_mocked_bindings(
    eri_list = function(...) fake_files,
    .package = "erifunctions"
  )
  result <- eri_landscan_list(data_con = "fake_con")
  expect_s3_class(result, "tbl_df")
  expect_equal(result$year, c(2024L, 2023L, 2022L))
  expect_equal(nrow(result), 3L)
})

#### add_anomaly_spatial admin_match ####

test_that("add_anomaly_spatial admin_match flags unrecognized names", {
  skip_no_sf()
  fake_sf <- sf::st_sf(
    adm2_name = c("Province A", "Province B"),
    geometry  = sf::st_sfc(
      sf::st_point(c(0, 0)), sf::st_point(c(1, 1))
    ),
    crs = 4326
  )
  local_mocked_bindings(
    eri_spatial_load = function(...) fake_sf,
    .package = "erifunctions"
  )
  schema <- list(
    admin       = NULL,
    admin_match = list(
      list(col = "province", country = "dr", level = 2, label = "province")
    )
  )
  df  <- tibble::tibble(province = c("Province A", "Province X", "Province B"))
  out <- add_anomaly_spatial(df, schema, azcontainer = NULL)
  expect_equal(nrow(out), 1L)
  expect_equal(out$row, 2L)
  expect_match(out$issue, "admin_match")
})

test_that("add_anomaly_spatial admin_match returns no flags when all names valid", {
  skip_no_sf()
  fake_sf <- sf::st_sf(
    adm1_name = c("North", "South"),
    geometry  = sf::st_sfc(
      sf::st_point(c(0, 0)), sf::st_point(c(1, 1))
    ),
    crs = 4326
  )
  local_mocked_bindings(
    eri_spatial_load = function(...) fake_sf,
    .package = "erifunctions"
  )
  schema <- list(
    admin       = NULL,
    admin_match = list(
      list(col = "dept", country = "ht", level = 1, label = "department")
    )
  )
  df  <- tibble::tibble(dept = c("North", "South"))
  out <- add_anomaly_spatial(df, schema, azcontainer = NULL)
  expect_equal(nrow(out), 0L)
})

test_that("add_anomaly_spatial admin_match skips gracefully when eri_spatial_load errors", {
  local_mocked_bindings(
    eri_spatial_load = function(...) stop("Azure unavailable"),
    .package = "erifunctions"
  )
  schema <- list(
    admin       = NULL,
    admin_match = list(
      list(col = "province", country = "dr", level = 2)
    )
  )
  df <- tibble::tibble(province = c("A", "B"))
  expect_warning(
    out <- add_anomaly_spatial(df, schema, azcontainer = NULL),
    regexp = "could not load"
  )
  expect_equal(nrow(out), 0L)
})
