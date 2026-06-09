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

test_that("eri_spatial_load(cache=TRUE) caches the single file via the real pull chain and records provenance", {
  skip_if_not_installed("sf")
  proj <- withr::local_tempdir()
  withr::local_dir(proj)

  # A minimal research project so eri_research_pull records provenance.
  yaml::write_yaml(
    list(
      project_name = "p", country = "dr", disease = "malaria", description = "d",
      created_at = "t", created_by = "u", azure_path = "research/p/",
      pulled_data = list(), artifacts_used = list(), log = list(),
      snapshots = list(), outputs = list(), tags = list()
    ),
    file.path(proj, "research.yaml")
  )

  fake_sf <- sf::st_sf(
    adm2_name = "Azua",
    geometry  = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
  )

  downloaded_src <- NULL
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "fake_con",
    eri_file_exists              = function(...) TRUE,
    .package = "erifunctions"
  )
  # Let the REAL eri_research_pull run; only mock Azure. storage_file_exists = TRUE
  # exercises the single-file branch; storage_download writes the boundary locally.
  local_mocked_bindings(
    storage_file_exists = function(...) TRUE,
    storage_download    = function(container, src, dest, ...) {
      downloaded_src <<- src
      saveRDS(fake_sf, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  out <- eri_spatial_load("dr", 2, cache = TRUE)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 1L)
  expect_equal(downloaded_src, "spatial/dr/adm2.rds")  # canonical single-file path

  # provenance was recorded through the pull entry point (ADR-0005/0007)
  manifest <- yaml::read_yaml(file.path(proj, "research.yaml"))
  expect_equal(length(manifest$pulled_data), 1L)
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

#### eri_spatial_reconcile ####

# Two adjacent localities in different municipalities of one province.
recon_shp <- function() {
  sf::st_sf(
    adm4_name = c("Jínova", "Las Zanjas"),
    adm3_name = c("Juan de Herrera", "San Juan"),
    adm2_name = c("San Juan", "San Juan"),
    geometry  = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0, 2,0, 2,1, 1,1, 1,0), ncol = 2, byrow = TRUE)))
    ),
    crs = 4326
  )
}

recon_cols <- list(
  loc_cols   = c("loc", "mun", "prov"),
  admin_cols = c("adm4_name", "adm3_name", "adm2_name")
)

test_that(".eri_normalize_name lower-cases, strips accents/punctuation, squishes space", {
  expect_equal(.eri_normalize_name("  Áéí  Test "), "aei test")
  expect_equal(.eri_normalize_name("Jínova"), "jinova")
  expect_equal(.eri_normalize_name("San Juan (D.M.)"), "san juan d m")
})

test_that("eri_spatial_reconcile matches exactly without geocoding", {
  skip_no_sf()
  local_mocked_bindings(
    .eri_geocode = function(...) stop("must not geocode a matched row"),
    .package = "erifunctions"
  )
  df <- tibble::tibble(
    loc  = "jinova",  # different case/accent from canonical "Jínova"
    mun  = "Juan de Herrera",
    prov = "San Juan",
    cases = 3L
  )
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "matched")
  expect_equal(out$loc, "Jínova")           # replaced in place with canonical
  expect_equal(out$cases, 3L)               # untouched columns preserved
  expect_true(all(is.na(c(out$longitude, out$latitude))))
})

test_that("eri_spatial_reconcile scopes matching by coarser levels", {
  skip_no_sf()
  # "Jínova" exists, but under the wrong municipality -> no match (no geocode).
  local_mocked_bindings(.eri_geocode = function(...) stop("no geocode"), .package = "erifunctions")
  df  <- tibble::tibble(loc = "Jínova", mun = "San Juan", prov = "San Juan")
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(),
                               recon_cols$admin_cols, method = NULL)
  expect_equal(out$reconcile_status, "unresolved")
  expect_equal(out$loc, "Jínova")           # original kept
})

test_that("eri_spatial_reconcile fuzzy-matches the finest level within max_dist", {
  skip_no_sf()
  df <- tibble::tibble(loc = "Jinoba", mun = "Juan de Herrera", prov = "San Juan")  # 1 edit
  exact <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(),
                                 recon_cols$admin_cols, method = NULL, max_dist = 0)
  expect_equal(exact$reconcile_status, "unresolved")
  fuzzy <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(),
                                 recon_cols$admin_cols, method = NULL, max_dist = 1)
  expect_equal(fuzzy$reconcile_status, "matched")
  expect_equal(fuzzy$loc, "Jínova")
})

test_that("eri_spatial_reconcile geocodes the unmatched and assigns admin units", {
  skip_no_sf()
  local_mocked_bindings(
    .eri_geocode = function(addresses, ...) {
      tibble::tibble(address = addresses, longitude = 0.5, latitude = 0.5)  # inside Jínova
    },
    .package = "erifunctions"
  )
  df  <- tibble::tibble(loc = "El Rincon", mun = "Juan de Herrera", prov = "San Juan")
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "geocoded")
  expect_equal(out$loc, "Jínova")           # assigned by point-in-polygon
  expect_equal(out$longitude, 0.5)
  expect_equal(out$latitude, 0.5)
})

test_that("eri_spatial_reconcile marks geocoded-but-outside points unresolved", {
  skip_no_sf()
  local_mocked_bindings(
    .eri_geocode = function(addresses, ...) {
      tibble::tibble(address = addresses, longitude = 50, latitude = 50)  # outside all polys
    },
    .package = "erifunctions"
  )
  df  <- tibble::tibble(loc = "Nowhere", mun = "Juan de Herrera", prov = "San Juan")
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "unresolved")
  expect_equal(out$loc, "Nowhere")          # original kept
  expect_equal(out$longitude, 50)           # coords still recorded for inspection
})

test_that("eri_spatial_reconcile records NA coords as unresolved", {
  skip_no_sf()
  local_mocked_bindings(
    .eri_geocode = function(addresses, ...) {
      tibble::tibble(address = addresses, longitude = NA_real_, latitude = NA_real_)
    },
    .package = "erifunctions"
  )
  df  <- tibble::tibble(loc = "Unfindable", mun = "Juan de Herrera", prov = "San Juan")
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "unresolved")
  expect_true(is.na(out$longitude))
})

test_that("eri_spatial_reconcile flags a low-confidence (partial) geocode for review", {
  skip_no_sf()
  local_mocked_bindings(
    .eri_geocode = function(addresses, ...) {
      tibble::tibble(address = addresses, longitude = 0.5, latitude = 0.5, partial = TRUE)
    },
    .package = "erifunctions"
  )
  df  <- tibble::tibble(loc = "El Rincon", mun = "Juan de Herrera", prov = "San Juan")
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "geocoded_review")
  expect_equal(out$loc, "El Rincon")   # names NOT overwritten on a flagged geocode
  expect_equal(out$longitude, 0.5)     # coordinates still recorded for inspection
})

test_that("eri_spatial_reconcile flags a parent-inconsistent geocode for review", {
  skip_no_sf()
  # Point falls in Jínova (mun "Juan de Herrera"), but the analyst claimed "San Juan".
  local_mocked_bindings(
    .eri_geocode = function(addresses, ...) {
      tibble::tibble(address = addresses, longitude = 0.5, latitude = 0.5, partial = FALSE)
    },
    .package = "erifunctions"
  )
  df  <- tibble::tibble(loc = "Somewhere", mun = "San Juan", prov = "San Juan")
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "geocoded_review")
  expect_equal(out$mun, "San Juan")    # claimed parent kept, not overwritten
})

test_that("eri_spatial_reconcile resolves a boundary point to a single row", {
  skip_no_sf()
  # x = 1 lies on the shared edge of Jínova (0-1) and Las Zanjas (1-2): the
  # point-in-polygon join matches both, but the result must stay one row per input.
  local_mocked_bindings(
    .eri_geocode = function(addresses, ...) {
      tibble::tibble(address = addresses, longitude = 1, latitude = 0.5, partial = FALSE)
    },
    .package = "erifunctions"
  )
  # Parent levels left NA so the parent-consistency check (which polygon a boundary
  # point dedups to is arbitrary) does not interfere with the single-row assertion.
  df  <- tibble::tibble(loc = "Edge", mun = NA_character_, prov = NA_character_)
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(nrow(out), 1L)
  expect_equal(out$reconcile_status, "geocoded")
})

test_that("eri_spatial_reconcile skips geocoding when no place name is available", {
  skip_no_sf()
  local_mocked_bindings(
    .eri_geocode = function(...) stop("must not geocode an empty address"),
    .package = "erifunctions"
  )
  df <- tibble::tibble(
    loc = NA_character_, mun = NA_character_, prov = NA_character_
  )
  out <- eri_spatial_reconcile(df, recon_cols$loc_cols, recon_shp(), recon_cols$admin_cols)
  expect_equal(out$reconcile_status, "unresolved")
  expect_true(is.na(out$longitude))
})

test_that("eri_spatial_reconcile validates its arguments", {
  skip_no_sf()
  shp <- recon_shp()
  df  <- tibble::tibble(loc = "x", mun = "y", prov = "z")
  expect_error(
    eri_spatial_reconcile(df, c("loc", "mun"), shp, recon_cols$admin_cols),
    regexp = "same length"
  )
  expect_error(
    eri_spatial_reconcile(df, "nope", shp, "adm4_name"),
    regexp = "not found in.*data"
  )
  expect_error(
    eri_spatial_reconcile(df, "loc", shp, "no_such_col"),
    regexp = "not found in.*shapefile"
  )
  bad <- tibble::tibble(loc = "x", mun = "y", prov = "z", reconcile_status = 1)
  expect_error(
    eri_spatial_reconcile(bad, recon_cols$loc_cols, shp, recon_cols$admin_cols),
    regexp = "already exist"
  )
})

#### .eri_geocode key preflight ####

test_that(".eri_geocode aborts early when a keyed method has no API key", {
  withr::local_envvar(GOOGLEGEOCODE_API_KEY = "")
  expect_error(
    .eri_geocode("Somewhere, Country", method = "google"),
    regexp = "needs an API key|GOOGLEGEOCODE_API_KEY"
  )
})

test_that(".eri_geocode skips the key check for keyless methods", {
  # If the key check did not fire for "osm", the next gate is the tidygeocoder
  # requireNamespace error. Skip when tidygeocoder is installed (would hit network).
  skip_if(requireNamespace("tidygeocoder", quietly = TRUE),
          "tidygeocoder installed; keyless path would make a network call")
  withr::local_envvar(GOOGLEGEOCODE_API_KEY = "")
  expect_error(.eri_geocode("Somewhere", method = "osm"), regexp = "tidygeocoder")
})

test_that(".eri_geocode passes the key gate when the key is present", {
  # A set key clears the preflight; the next gate is the tidygeocoder requireNamespace
  # error. Skip when tidygeocoder is installed (proceeding would make a network call).
  skip_if(requireNamespace("tidygeocoder", quietly = TRUE),
          "tidygeocoder installed; passing the gate would make a network call")
  withr::local_envvar(GOOGLEGEOCODE_API_KEY = "dummy-key")
  expect_error(.eri_geocode("Somewhere", method = "google"), regexp = "tidygeocoder")
})
