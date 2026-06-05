#### Spatial data management ####

.ERI_SPATIAL_ADMIN_ROOT   <- "spatial"
.ERI_SPATIAL_LANDSCAN_DIR <- "spatial/landscan"

#' @keywords internal
.eri_spatial_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#' @keywords internal
.eri_spatial_admin_path <- function(country, level) {
  paste0(.ERI_SPATIAL_ADMIN_ROOT, "/", country, "/adm", level, ".rds")
}

#' @keywords internal
.eri_spatial_landscan_path <- function(year) {
  paste0(.ERI_SPATIAL_LANDSCAN_DIR, "/landscan-global-", year, ".tif")
}

#### eri_spatial_load ####

#' Load admin boundary from Azure
#'
#' Reads an admin boundary `sf` object from `data/spatial/{country}/adm{level}.rds`
#' in the `data/` Azure blob. Returns it ready for mapping or spatial joins.
#'
#' @param country `chr` Country code (e.g. `"dr"`, `"ht"`).
#' @param level `int` Admin level (0 = country, 1 = region/department, 2 = province/commune,
#'   3 = municipality/locality, 4 = sub-locality).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @param cache `lgl` If `TRUE`, cache the boundary into the local research project and read it
#'   from there instead of reading directly from Azure. Caching delegates to
#'   [eri_research_pull()], which downloads into `dest` and records the pull in `research.yaml`
#'   when present -- so a study's spatial inputs are reproducible and frozen by
#'   [eri_research_tag()]. Default `FALSE` (read directly from Azure). See ADR-0007.
#' @param dest `chr` Directory to cache into when `cache = TRUE`. Defaults to the project
#'   `data/` directory.
#' @returns An `sf` object with the admin boundary geometries.
#' @examples
#' \dontrun{
#' haiti_communes <- eri_spatial_load("ht", level = 2)
#' dr_provinces   <- eri_spatial_load("dr", level = 2)
#'
#' # Inside a research project: cache the boundary and record its provenance.
#' dr_loc <- eri_spatial_load("dr", level = 4, cache = TRUE)
#' }
#' @export
eri_spatial_load <- function(country, level, data_con = NULL, cache = FALSE, dest = NULL) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_load}.")
  }

  level <- suppressWarnings(as.integer(level))
  if (is.na(level) || level < 0L || level > 4L) {
    cli::cli_abort("{.arg level} must be an integer between 0 and 4, got {.val {level}}.")
  }

  con       <- .eri_spatial_con(data_con)
  blob_path <- .eri_spatial_admin_path(country, level)

  if (!eri_file_exists(blob_path, azcontainer = con)) {
    cli::cli_abort(c(
      "Admin boundary not found in Azure: {.path {blob_path}}",
      "i" = "Upload it first with:",
      " " = "{.code eri_spatial_upload(local_path, country = \"{country}\", level = {level})}"
    ))
  }

  if (isTRUE(cache)) {
    # Source reproducibly: cache into the research project and record provenance through
    # the pull entry point (ADR-0005/0007), then read the local copy.
    if (!file.exists(file.path(getwd(), "research.yaml"))) {
      cli::cli_warn(c(
        "{.arg cache = TRUE} but no {.file research.yaml} in the working directory.",
        "i" = "The boundary is cached locally, but its provenance is NOT recorded -- run {.fn eri_research_init} first for a reproducible pull."
      ))
    }
    local_paths <- eri_research_pull(path = blob_path, dest = dest, data_con = con)
    if (length(local_paths) == 0L) {
      cli::cli_abort("Failed to cache {.path {blob_path}}.")
    }
    sf_obj <- readRDS(local_paths[[1L]])
    cli::cli_alert_success(
      "Loaded {.val {country}} admin level {level} from cache {.path {local_paths[[1L]]}} ({nrow(sf_obj)} feature{?s})."
    )
    return(sf_obj)
  }

  sf_obj <- eri_read(blob_path, azcontainer = con)
  cli::cli_alert_success(
    "Loaded {.val {country}} admin level {level} boundaries ({nrow(sf_obj)} feature{?s})."
  )
  sf_obj
}

#### eri_spatial_upload ####

#' Upload an admin boundary shapefile to Azure
#'
#' Validates and uploads a local shapefile (or any sf-readable format) to
#' `data/spatial/{country}/adm{level}.rds` in the `data/` Azure blob.
#'
#' The file is validated before upload:
#' - Must have a defined CRS.
#' - Must have no empty geometries.
#' - Must contain a column named `adm{level}_name` holding the canonical admin unit names.
#'
#' If validation fails the upload is blocked with a clear error explaining what to fix.
#'
#' @param local_path `chr` Path to the local shapefile (`.shp`, `.gpkg`, `.geojson`, etc.).
#' @param country `chr` Country code (e.g. `"dr"`, `"ht"`).
#' @param level `int` Admin level (0–4).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The Azure blob path (invisibly).
#' @examples
#' \dontrun{
#' eri_spatial_upload("data/dom_admin_boundaries/dom_admin3.shp", country = "dr", level = 3)
#' eri_spatial_upload("data/hti_admin_boundaries/hti_admin2.shp", country = "ht", level = 2)
#' }
#' @export
eri_spatial_upload <- function(local_path, country, level, data_con = NULL) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_upload}.")
  }

  level <- suppressWarnings(as.integer(level))
  if (is.na(level) || level < 0L || level > 4L) {
    cli::cli_abort("{.arg level} must be an integer between 0 and 4.")
  }

  if (!file.exists(local_path)) {
    cli::cli_abort("File not found: {.path {local_path}}")
  }

  sf_obj <- tryCatch(
    sf::st_read(local_path, quiet = TRUE),
    error = function(e) {
      cli::cli_abort("Could not read {.path {local_path}}: {e$message}")
    }
  )

  # --- Validation ---
  issues <- list()

  if (is.na(sf::st_crs(sf_obj))) {
    issues <- c(issues, list(c(
      "x" = "Shapefile has no CRS.",
      "i" = "Assign one before uploading, e.g.:",
      " " = "{.code sf_obj <- sf::st_set_crs(sf_obj, 4326)}"
    )))
  }

  n_empty <- sum(sf::st_is_empty(sf_obj))
  if (n_empty > 0L) {
    issues <- c(issues, list(c(
      "x" = "{n_empty} feature{?s} {?has/have} empty geometry.",
      "i" = "Remove them before uploading:",
      " " = "{.code sf_obj <- sf_obj[!sf::st_is_empty(sf_obj), ]}"
    )))
  }

  expected_col <- paste0("adm", level, "_name")
  if (!expected_col %in% names(sf_obj)) {
    issues <- c(issues, list(c(
      "x" = "Required column {.val {expected_col}} not found.",
      "i" = "Rename your admin name column to {.val {expected_col}} before uploading, e.g.:",
      " " = "{.code names(sf_obj)[names(sf_obj) == 'NAME_2'] <- '{expected_col}'}"
    )))
  }

  if (length(issues) > 0L) {
    cli::cli_abort(c(
      "Shapefile validation failed -- upload blocked.",
      unlist(issues)
    ))
  }

  # --- Upload ---
  tmp <- tempfile(fileext = ".rds")
  withr::defer(unlink(tmp))
  readr::write_rds(sf_obj, tmp)

  con       <- .eri_spatial_con(data_con)
  blob_path <- .eri_spatial_admin_path(country, level)

  eri_upload(tmp, blob_path, azcontainer = con)
  cli::cli_alert_success(
    "Uploaded {.val {country}} admin level {level} to {.path {blob_path}}."
  )
  invisible(blob_path)
}

#### eri_bbox_expand ####

#' Expand a bounding box by a distance in metres
#'
#' Takes an `sf` bounding box and expands it by `X` metres in the east-west
#' direction and `Y` metres in the north-south direction. Useful for adding
#' padding around a study area before mapping.
#'
#' Ported from `sirfunctions::f.expand.bbox()` /
#' basemapR.
#'
#' @param bbox A bounding box produced by [sf::st_bbox()].
#' @param X `num` Padding in metres on the west side (and east if `X2` is not given).
#' @param Y `num` Padding in metres on the south side (and north if `Y2` is not given).
#' @param X2 `num` Padding in metres on the east side. Defaults to `X`.
#' @param Y2 `num` Padding in metres on the north side. Defaults to `Y`.
#' @param crs_out `int` EPSG code for the output CRS. Defaults to `4326` (WGS84 lat/lng).
#' @returns A bounding box object (`bbox`). Convert to an `sf` polygon with
#'   [sf::st_as_sfc()].
#' @examples
#' \dontrun{
#' haiti <- eri_spatial_load("ht", level = 0)
#' bbox  <- sf::st_bbox(haiti) |> eri_bbox_expand(X = 10000, Y = 10000)
#' }
#' @export
eri_bbox_expand <- function(bbox, X, Y, X2 = X, Y2 = Y, crs_out = 4326) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_bbox_expand}.")
  }

  bbox <- bbox |>
    sf::st_as_sfc() |>
    sf::st_transform(crs = 4326) |>
    sf::st_bbox()

  bbox["xmin"] <- bbox["xmin"] - (X  / 6370000) * (180 / pi) / cos(bbox["xmin"] * pi / 180)
  bbox["xmax"] <- bbox["xmax"] + (X2 / 6370000) * (180 / pi) / cos(bbox["xmax"] * pi / 180)
  bbox["ymin"] <- bbox["ymin"] - (Y  / 6370000) * (180 / pi)
  bbox["ymax"] <- bbox["ymax"] + (Y2 / 6370000) * (180 / pi)

  bbox |>
    sf::st_as_sfc() |>
    sf::st_transform(crs = crs_out) |>
    sf::st_bbox()
}

#### eri_spatial_join ####

#' Join point data to admin boundaries
#'
#' Converts a data frame with latitude/longitude columns to an `sf` points
#' object, spatially joins it to a polygon `sf` object, and returns the result
#' as a plain tibble. Rows with `NA` coordinates are dropped with a warning.
#'
#' @param data A data frame or tibble with coordinate columns.
#' @param lat_col `chr` Name of the latitude column.
#' @param lon_col `chr` Name of the longitude column.
#' @param shapefile An `sf` polygon object (e.g. from [eri_spatial_load()]).
#' @param admin_cols `chr` vector of column names to attach from `shapefile`.
#'   If `NULL` (default), all non-geometry columns are attached.
#' @returns A tibble with the original `data` columns plus the selected columns
#'   from `shapefile`. Geometry is dropped from the result.
#' @examples
#' \dontrun{
#' communes  <- eri_spatial_load("ht", level = 2)
#' case_data <- eri_spatial_join(
#'   tas_data,
#'   lat_col    = "lat",
#'   lon_col    = "lon",
#'   shapefile  = communes,
#'   admin_cols = c("adm2_name", "adm1_name")
#' )
#' }
#' @export
eri_spatial_join <- function(data, lat_col, lon_col, shapefile, admin_cols = NULL) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_join}.")
  }

  data <- tibble::as_tibble(data)

  if (!lat_col %in% names(data)) {
    cli::cli_abort("{.arg lat_col} {.val {lat_col}} not found in data.")
  }
  if (!lon_col %in% names(data)) {
    cli::cli_abort("{.arg lon_col} {.val {lon_col}} not found in data.")
  }

  n_na <- sum(is.na(data[[lat_col]]) | is.na(data[[lon_col]]))
  if (n_na > 0L) {
    cli::cli_warn(
      "{n_na} row{?s} with NA coordinate{?s} dropped before spatial join."
    )
    data <- data[!is.na(data[[lat_col]]) & !is.na(data[[lon_col]]), ]
  }

  if (!is.null(admin_cols)) {
    missing_cols <- setdiff(admin_cols, names(shapefile))
    if (length(missing_cols) > 0L) {
      cli::cli_abort("Column{?s} {.val {missing_cols}} not found in shapefile.")
    }
    geo_col   <- attr(shapefile, "sf_column")
    shapefile <- shapefile[, c(admin_cols, geo_col), drop = FALSE]
  }

  pts <- sf::st_as_sf(
    data,
    coords = c(lon_col, lat_col),
    crs    = sf::st_crs(shapefile),
    remove = FALSE
  )

  sf::st_join(pts, shapefile) |>
    sf::st_drop_geometry() |>
    tibble::as_tibble()
}

#### eri_landscan_upload ####

#' Upload a LandScan population raster to Azure
#'
#' Validates and uploads a local LandScan `.tif` raster to
#' `data/spatial/landscan/landscan-global-{year}.tif` in the `data/` Azure blob.
#' Only the plain raster file should be uploaded (not the colorized version).
#'
#' LandScan rasters are ~100 MB. Upload only the latest year; older years are
#' automatically kept and accessible via [eri_landscan_list()].
#'
#' @param local_path `chr` Local path to the LandScan `.tif` file, e.g.
#'   `"data/LandScan/landscan-global-2024/landscan-global-2024.tif"`.
#' @param year `int` The LandScan dataset year (e.g. `2024`).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The Azure blob path (invisibly).
#' @examples
#' \dontrun{
#' eri_landscan_upload(
#'   local_path = "data/LandScan/landscan-global-2024/landscan-global-2024.tif",
#'   year       = 2024
#' )
#' }
#' @export
eri_landscan_upload <- function(local_path, year, data_con = NULL) {
  year <- suppressWarnings(as.integer(year))
  if (is.na(year) || year < 2000L || year > as.integer(format(Sys.Date(), "%Y"))) {
    cli::cli_abort("{.arg year} must be a valid 4-digit year between 2000 and the current year.")
  }

  if (!file.exists(local_path)) {
    cli::cli_abort("File not found: {.path {local_path}}")
  }

  filename <- basename(local_path)
  expected <- paste0("landscan-global-", year, ".tif")
  if (!identical(filename, expected)) {
    cli::cli_abort(c(
      "Unexpected filename: {.val {filename}}",
      "i" = "Expected exactly {.val {expected}}.",
      "i" = "Do not upload the colorized version (e.g. {.val landscan-global-{year}-colorized.tif}).",
      "i" = "If the file is correctly named, copy it to a directory and pass that path."
    ))
  }

  con       <- .eri_spatial_con(data_con)
  blob_path <- .eri_spatial_landscan_path(year)

  cli::cli_alert_info("Uploading LandScan {year} (~100 MB) -- this may take a moment...")
  eri_upload(local_path, blob_path, azcontainer = con)
  cli::cli_alert_success("LandScan {year} uploaded to {.path {blob_path}}.")
  invisible(blob_path)
}

#### eri_landscan_list ####

#' List LandScan rasters available in Azure
#'
#' Returns a tibble of LandScan rasters stored in
#' `data/spatial/landscan/` in the `data/` Azure blob, sorted by year descending
#' (most recent first).
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns `year`, `name`, `size`, `lastModified`.
#' @examples
#' \dontrun{
#' eri_landscan_list()
#' }
#' @export
eri_landscan_list <- function(data_con = NULL) {
  con <- .eri_spatial_con(data_con)

  files <- tryCatch(
    eri_list(.ERI_SPATIAL_LANDSCAN_DIR, azcontainer = con),
    error = function(e) {
      cli::cli_warn("Could not list Azure LandScan directory: {e$message}")
      return(tibble::tibble(name = character(), size = integer(),
                            isdir = logical(), lastModified = as.POSIXct(character())))
    }
  )

  tif_rows <- files[grepl("landscan-global-\\d{4}\\.tif$", files$name, perl = TRUE), ]

  if (nrow(tif_rows) == 0L) {
    cli::cli_alert_info(
      "No LandScan rasters found in Azure. Upload one with {.fn eri_landscan_upload}."
    )
    return(tibble::tibble(year = integer(), name = character()))
  }

  tif_rows$year <- as.integer(
    regmatches(tif_rows$name, regexpr("\\d{4}", tif_rows$name))
  )

  out <- tif_rows[order(tif_rows$year, decreasing = TRUE),
                  intersect(c("year", "name", "size", "lastModified"), names(tif_rows))]
  tibble::as_tibble(out)
}

#### eri_spatial_pop ####

#' Extract population from LandScan into spatial polygons
#'
#' Downloads a LandScan raster from Azure, extracts population counts for each
#' feature in `shapefile` using `exactextractr::exact_extract()`, and returns
#' the `sf` object with a `pop` column added.
#'
#' By default the most recent LandScan year available in Azure is used. Older
#' years are accessible via `year`. Run [eri_landscan_list()] to see what is
#' available.
#'
#' @param shapefile An `sf` polygon object (e.g. from [eri_spatial_load()]).
#' @param year `int` LandScan year to use. If `NULL` (default), uses the latest
#'   year available in Azure.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @param fun `chr` Summary function passed to `exactextractr::exact_extract()`.
#'   Default `"sum"` returns total population per polygon.
#' @returns The input `shapefile` with a `pop` column added (numeric).
#' @examples
#' \dontrun{
#' communes <- eri_spatial_load("ht", level = 2) |>
#'   eri_spatial_pop()
#'
#' # Use a specific year
#' communes_2022 <- eri_spatial_load("ht", level = 2) |>
#'   eri_spatial_pop(year = 2022)
#' }
#' @export
eri_spatial_pop <- function(shapefile, year = NULL, data_con = NULL, fun = "sum") {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_pop}.")
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} must be installed to use {.fn eri_spatial_pop}.")
  }
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg exactextractr} must be installed to use {.fn eri_spatial_pop}."
    )
  }

  con <- .eri_spatial_con(data_con)

  if (is.null(year)) {
    available <- eri_landscan_list(data_con = con)
    if (nrow(available) == 0L) {
      cli::cli_abort(c(
        "No LandScan rasters found in Azure.",
        "i" = "Upload one with {.fn eri_landscan_upload}."
      ))
    }
    year <- available$year[[1L]]
    cli::cli_alert_info("Using LandScan {year} (latest available).")
  }

  year      <- as.integer(year)
  blob_path <- .eri_spatial_landscan_path(year)

  if (!eri_file_exists(blob_path, azcontainer = con)) {
    avail <- eri_landscan_list(data_con = con)
    cli::cli_abort(c(
      "LandScan {year} not found in Azure.",
      "i" = "Available year{?s}: {.val {avail$year}}",
      "i" = "Upload with {.fn eri_landscan_upload}."
    ))
  }

  tmp_tif <- tempfile(fileext = ".tif")
  withr::defer(unlink(tmp_tif))

  cli::cli_alert_info("Downloading LandScan {year} from Azure...")
  AzureStor::storage_download(con, blob_path, tmp_tif, overwrite = TRUE)

  cli::cli_alert_info("Extracting population for {nrow(shapefile)} feature{?s}...")
  rast_obj <- terra::rast(tmp_tif)
  shapefile$pop <- exactextractr::exact_extract(rast_obj, shapefile, fun = fun)

  cli::cli_alert_success(
    "Population extracted using LandScan {year}. Column {.val pop} added to shapefile."
  )
  shapefile
}
