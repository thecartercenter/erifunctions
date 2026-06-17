#### Spatial data management ####

.ERI_SPATIAL_ADMIN_ROOT   <- "spatial"
.ERI_SPATIAL_LANDSCAN_DIR <- "spatial/landscan"
.ERI_SPATIAL_ARCHIVE_DIR  <- "spatial/_archive"

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

#### eri_spatial_upload / eri_spatial_promote ####

#' Validate a local admin boundary before it reaches the canonical store.
#'
#' Reads `local_path` as an `sf` object and checks it has a defined CRS, no empty
#' geometries, and the required `adm{level}_name` column. Aborts with a clear,
#' actionable error if any check fails. Shared by [eri_spatial_upload()] and
#' [eri_spatial_promote()].
#' @keywords internal
.eri_spatial_validate_boundary <- function(local_path, level, fn = "eri_spatial_upload") {
  if (!file.exists(local_path)) {
    cli::cli_abort("File not found: {.path {local_path}}")
  }

  # `.rds` (the canonical store format, and what eri_spatial_load() caches into a project) is
  # read directly; any other sf-readable format (shapefile, gpkg, geojson) goes through st_read.
  reader <- if (grepl("\\.rds$", local_path, ignore.case = TRUE)) readRDS else function(p) sf::st_read(p, quiet = TRUE)
  sf_obj <- tryCatch(
    reader(local_path),
    error = function(e) {
      cli::cli_abort("Could not read {.path {local_path}}: {e$message}")
    }
  )
  if (!inherits(sf_obj, "sf")) {
    cli::cli_abort("{.path {local_path}} did not read as an {.cls sf} object (got {.cls {class(sf_obj)[1]}}).")
  }

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
      "Shapefile validation failed -- {fn} blocked.",
      unlist(issues)
    ))
  }
  sf_obj
}

#' Write a validated boundary to the canonical `/spatial` store, guarding overwrites.
#'
#' Refuses to clobber an existing canonical boundary unless `overwrite = TRUE`,
#' because `/spatial` is shared cleaned reference data many users pull for figures
#' (ADR-0009). The escalation message differs by entry point. Returns a list with the canonical
#' `blob_path`, whether it `existed`, and where the prior version was `archived_to` (or `NULL`).
#' @keywords internal
.eri_spatial_write_canonical <- function(sf_obj, country, level, con, overwrite, via) {
  blob_path <- .eri_spatial_admin_path(country, level)
  existed   <- eri_file_exists(blob_path, azcontainer = con)

  if (!isTRUE(overwrite) && existed) {
    escalation <- if (identical(via, "eri_spatial_upload")) {
      c(
        "i" = "To deliberately replace it, promote a vetted copy with {.fn eri_spatial_promote},",
        "i" = "or re-run {.fn eri_spatial_upload} with {.code overwrite = TRUE} if you are sure."
      )
    } else {
      c("i" = "Re-run {.fn eri_spatial_promote} with {.code overwrite = TRUE} to confirm the replacement.")
    }
    cli::cli_abort(c(
      "Canonical boundary already exists: {.path {blob_path}}",
      "x" = "Refusing to overwrite -- {.path spatial/} is shared cleaned data many users pull for figures.",
      escalation
    ))
  }

  # Update + archival applied to canonical (ADR-0009): a deliberate overwrite first copies the prior
  # canonical version into spatial/_archive/<ts>/, so replacing shared reference data is reversible.
  archived_to <- NULL
  if (existed) {
    ts          <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
    archived_to <- paste0(.ERI_SPATIAL_ARCHIVE_DIR, "/", ts, "/", country, "/adm", level, ".rds")
    tmp_prev    <- tempfile(fileext = ".rds")
    on.exit(unlink(tmp_prev), add = TRUE)
    .eri_blob_read(con, blob_path, tmp_prev)
    .eri_create_azure_dir(con, dirname(archived_to))
    eri_upload(tmp_prev, archived_to, azcontainer = con)
    .eri_say_info("Archived prior canonical {.val {country}} adm{level} to {.path {archived_to}}.")
  }

  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  readr::write_rds(sf_obj, tmp)
  eri_upload(tmp, blob_path, azcontainer = con)
  list(blob_path = blob_path, existed = existed, archived_to = archived_to)
}

#' Upload a new admin boundary shapefile to Azure
#'
#' Validates and uploads a local shapefile (or any sf-readable format) to the
#' canonical `data/spatial/{country}/adm{level}.rds` in the `data/` Azure blob.
#'
#' The file is validated before upload:
#' - Must have a defined CRS.
#' - Must have no empty geometries.
#' - Must contain a column named `adm{level}_name` holding the canonical admin unit names.
#'
#' If validation fails the upload is blocked with a clear error explaining what to fix.
#'
#' The canonical `spatial/` store is **shared cleaned reference data** that many users pull
#' for figures, so this function is **overwrite-safe**: it refuses to clobber a boundary that
#' already exists. Use this for a brand-new boundary. To deliberately *replace* an existing
#' canonical boundary from a vetted research-project copy, use [eri_spatial_promote()] (which
#' records who promoted what, when). A deliberate `overwrite = TRUE` archives the prior canonical
#' version to `spatial/_archive/<timestamp>/` first, so the replacement is reversible. See ADR-0009.
#'
#' @param local_path `chr` Path to the local shapefile (`.shp`, `.gpkg`, `.geojson`, etc.).
#' @param country `chr` Country code (e.g. `"dr"`, `"ht"`).
#' @param level `int` Admin level (0–4).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @param overwrite `lgl` If `TRUE`, replace an existing canonical boundary. Default `FALSE`
#'   (refuse to overwrite shared data). Prefer [eri_spatial_promote()] for deliberate replacement.
#' @returns The Azure blob path (invisibly).
#' @examples
#' \dontrun{
#' eri_spatial_upload("data/dom_admin_boundaries/dom_admin3.shp", country = "dr", level = 3)
#' eri_spatial_upload("data/hti_admin_boundaries/hti_admin2.shp", country = "ht", level = 2)
#' }
#' @export
eri_spatial_upload <- function(local_path, country, level, data_con = NULL, overwrite = FALSE) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_upload}.")
  }

  level <- suppressWarnings(as.integer(level))
  if (is.na(level) || level < 0L || level > 4L) {
    cli::cli_abort("{.arg level} must be an integer between 0 and 4.")
  }

  sf_obj <- .eri_spatial_validate_boundary(local_path, level, fn = "eri_spatial_upload")
  con    <- .eri_spatial_con(data_con)
  res    <- .eri_spatial_write_canonical(
    sf_obj, country, level, con, overwrite = overwrite, via = "eri_spatial_upload"
  )

  cli::cli_alert_success(
    "Uploaded {.val {country}} admin level {level} to {.path {res$blob_path}}."
  )
  invisible(res$blob_path)
}

#### eri_spatial_promote ####

#' Promote a research-project boundary to the canonical `/spatial` store
#'
#' The explicit gate for pushing a boundary you have cleaned in a research project up to the
#' shared canonical `data/spatial/{country}/adm{level}.rds`, where other users and studies pull
#' it. Unlike [eri_spatial_upload()] (for brand-new boundaries), `eri_spatial_promote()` is the
#' deliberate way to *replace* an existing canonical boundary, and it records the promotion in
#' the project's `research.yaml` for provenance. Replacing an existing boundary still requires an
#' explicit `overwrite = TRUE` so shared data is never clobbered by accident, and the prior
#' canonical version is first archived to `spatial/_archive/<timestamp>/` so a replacement is
#' reversible. See ADR-0009.
#'
#' The boundary is validated exactly as in [eri_spatial_upload()] before promotion.
#'
#' @param local_path `chr` Path to the local boundary file to promote (typically a cleaned copy
#'   under the project `data/` directory).
#' @param country `chr` Country code (e.g. `"dr"`, `"ht"`).
#' @param level `int` Admin level (0–4).
#' @param overwrite `lgl` If `TRUE`, replace an existing canonical boundary. Default `FALSE`.
#' @param path `chr` Local project root (read for `research.yaml` to record provenance). Defaults
#'   to `getwd()`. If no `research.yaml` is found, the promotion proceeds but is not recorded
#'   (with a warning).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The canonical Azure blob path (invisibly).
#' @examples
#' \dontrun{
#' # After cleaning a boundary inside a research project, promote it to canonical.
#' eri_spatial_promote("data/dr_adm3_cleaned.rds", country = "dr", level = 3, overwrite = TRUE)
#' }
#' @export
eri_spatial_promote <- function(local_path, country, level, overwrite = FALSE,
                                path = getwd(), data_con = NULL) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_promote}.")
  }

  level <- suppressWarnings(as.integer(level))
  if (is.na(level) || level < 0L || level > 4L) {
    cli::cli_abort("{.arg level} must be an integer between 0 and 4.")
  }

  sf_obj <- .eri_spatial_validate_boundary(local_path, level, fn = "eri_spatial_promote")
  con    <- .eri_spatial_con(data_con)
  res    <- .eri_spatial_write_canonical(
    sf_obj, country, level, con, overwrite = overwrite, via = "eri_spatial_promote"
  )

  # Record the promotion in research.yaml when run inside a project (best-effort provenance).
  yaml_path <- .eri_research_yaml_path(path)
  if (file.exists(yaml_path)) {
    manifest <- .eri_research_read_manifest(path)
    entry <- list(
      type        = "boundary",
      country     = country,
      level       = level,
      source      = normalizePath(local_path, winslash = "/", mustWork = FALSE),
      azure_path  = res$blob_path,
      replaced    = res$existed,
      promoted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      promoted_by = Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
    )
    if (!is.null(res$archived_to)) entry$archived_prev <- res$archived_to
    if (is.null(manifest$promoted_data)) manifest$promoted_data <- list()
    manifest$promoted_data <- c(manifest$promoted_data, list(entry))
    .eri_research_write_manifest(manifest, path)
  } else {
    cli::cli_warn(c(
      "No {.file research.yaml} in {.path {path}} -- promotion was NOT recorded.",
      "i" = "Run {.fn eri_research_init} first to track promotions for provenance."
    ))
  }

  cli::cli_alert_success(
    "Promoted {.val {country}} admin level {level} to canonical {.path {res$blob_path}}{if (res$existed) ' (replaced existing)' else ''}."
  )
  invisible(res$blob_path)
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

#### eri_spatial_reconcile ####

#' @keywords internal
.eri_normalize_name <- function(x) {
  x <- as.character(x)
  # Transliterate accents to ASCII (e.g. "Tábara" -> "Tabara"); keep the
  # original where transliteration fails (returns NA).
  ascii <- suppressWarnings(iconv(x, to = "ASCII//TRANSLIT"))
  x <- ifelse(!is.na(ascii), ascii, x)
  x <- tolower(x)
  x <- gsub("[[:punct:]]", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

# Geocoding services that need an API key, mapped to the env var tidygeocoder reads
# (see `tidygeocoder::geocode()`). Keyless services (e.g. "osm") are not listed.
.ERI_GEOCODE_KEY_ENV <- c(
  google   = "GOOGLEGEOCODE_API_KEY",
  geocodio = "GEOCODIO_API_KEY",
  here     = "HERE_API_KEY",
  mapbox   = "MAPBOX_API_KEY",
  tomtom   = "TOMTOM_API_KEY",
  mapquest = "MAPQUEST_API_KEY",
  opencage = "OPENCAGE_KEY",
  bing     = "BINGMAPS_API_KEY",
  geoapify = "GEOAPIFY_KEY"
)

#' @keywords internal
.eri_geocode <- function(addresses, method = "osm", ...) {
  # Key preflight first: a pure environment check (needs no package) and the most
  # common setup gap for non-developer users. This is a key-*presence* check, not a
  # method allow-list: `method = NULL` and any unlisted method deliberately fall
  # through to tidygeocoder's own handling.
  key_env <- if (!is.null(method) && method %in% names(.ERI_GEOCODE_KEY_ENV)) {
    .ERI_GEOCODE_KEY_ENV[[method]]
  } else {
    NULL
  }
  if (!is.null(key_env) && !nzchar(Sys.getenv(key_env))) {
    cli::cli_abort(c(
      "Geocoding method {.val {method}} needs an API key, but {.envvar {key_env}} is not set.",
      "i" = "Sign up for your own key, then store it once in your user {.file .Renviron}:",
      "*" = "Run {.code usethis::edit_r_environ()} and add a line: {.code {key_env}=your_key}",
      "*" = "Save the file, then restart R so the key is loaded.",
      "i" = "No key is needed for {.code method = \"osm\"} (free) or {.code method = NULL} (match only)."
    ))
  }
  if (!requireNamespace("tidygeocoder", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg tidygeocoder} must be installed to geocode place names.",
      "i" = "Install it with {.code install.packages(\"tidygeocoder\")}.",
      "i" = "Or call {.fn eri_spatial_reconcile} with {.code method = NULL} to match only (no geocoding)."
    ))
  }
  df <- tibble::tibble(address = as.character(addresses))

  # Google returns `partial_match = TRUE` when it could not fully match the query and
  # substituted a coarser guess (e.g. a fabricated locality resolved to its parent) --
  # the signal a reconciliation should not trust. Request full results to capture it.
  # Methods that expose no such flag report `partial = NA` (not flagged).
  # `full_results` is managed here for google; do not also pass it via `...`.
  if (identical(method, "google")) {
    out     <- tidygeocoder::geocode(
      df, address = "address", method = method,
      lat = "latitude", long = "longitude", full_results = TRUE, ...
    )
    partial <- if ("partial_match" %in% names(out)) out[["partial_match"]] %in% TRUE else NA
  } else {
    out     <- tidygeocoder::geocode(
      df, address = "address", method = method,
      lat = "latitude", long = "longitude", ...
    )
    partial <- NA
  }
  tibble::tibble(
    address   = out[["address"]],
    longitude = out[["longitude"]],
    latitude  = out[["latitude"]],
    partial   = partial
  )
}

#' Reconcile free-text place names to canonical admin units
#'
#' A thin, opt-in **data-sourcing** helper that maps messy, free-text locality
#' names in incoming data to the canonical admin units in an authoritative
#' boundary `sf` object (from [eri_spatial_load()]). It does the
#' name-reconciliation step many studies do by hand before analysis -- it is
#' **not** an analysis tool (matching/windowing/modelling stay in the research
#' repo; see ADR-0006).
#'
#' The reconciliation runs in two passes (per issue #134):
#' 1. **Match first.** Free-text names are normalized (lower-cased, accent- and
#'    punctuation-stripped, whitespace-squished) and matched against the
#'    canonical names. Coarser levels must match exactly; the finest level may
#'    match approximately when `max_dist > 0` (Levenshtein distance via
#'    [utils::adist()]). Matched rows are **not** geocoded.
#' 2. **Geocode the residual.** Rows that don't match are geocoded from an
#'    address built from `loc_cols` (+ `country_name`), then assigned a canonical
#'    admin unit by point-in-polygon via [eri_spatial_join()]. Set
#'    `method = NULL` to skip geocoding entirely (match-only).
#'
#' A geocode is only **trusted** (status `"geocoded"`, names assigned) when the
#' service did not flag a partial/low-confidence match *and* the assigned coarser
#' admin units agree with the parent levels supplied in `loc_cols`. Otherwise the
#' row is flagged `"geocoded_review"`: its coordinates are recorded for inspection
#' but the analyst's names are left untouched. This guards against geocoders that
#' "best-guess" a fabricated or unmatched locality into a plausible nearby point
#' (issue #145). The partial-match signal is currently read from the `"google"`
#' method; methods that do not expose one rely on the parent-consistency check
#' alone.
#'
#' Only the place-name address strings are sent to the geocoder; no data records
#' leave the machine. The `"google"` method is the most accurate but requires
#' **your own API key** and is billed per call: sign up for a key, then store it
#' once in your user `.Renviron` as `GOOGLEGEOCODE_API_KEY` (e.g. via
#' `usethis::edit_r_environ()`) and restart R. The function checks for the key up
#' front and explains this if it is missing. The default `"osm"` (Nominatim) needs
#' no key. See [tidygeocoder::geocode()].
#'
#' @param data A data frame or tibble containing the free-text place-name columns.
#' @param loc_cols `chr` vector of free-text column names, ordered **finest to
#'   coarsest** (e.g. `c("loc", "mun", "prov")`). Used both to match and to build
#'   the geocoding address (finest first).
#' @param shapefile An admin-boundary `sf` object, e.g. from [eri_spatial_load()].
#' @param admin_cols `chr` vector of canonical name columns in `shapefile`,
#'   **parallel to `loc_cols`** (same length, same finest-to-coarsest order). This
#'   ordering is load-bearing: passing the columns coarsest-first silently produces
#'   wrong matches.
#' @param country_name `chr` Country name appended to each geocoding address
#'   (e.g. `"Dominican Republic"`), improving geocoder accuracy. Optional.
#' @param method `chr` Geocoding service passed to [tidygeocoder::geocode()]
#'   (e.g. `"osm"`, `"google"`). `NULL` disables geocoding (match-only). Default `"osm"`.
#' @param max_dist `int` Maximum edit distance for an approximate match on the
#'   finest level. `0` (default) requires an exact normalized match.
#' @param status_col `chr` Name of the status column added to the result.
#'   Default `"reconcile_status"`; values are `"matched"`, `"geocoded"`,
#'   `"geocoded_review"` (geocoded but low-confidence or parent-inconsistent --
#'   verify before use), or `"unresolved"`.
#' @param coord_cols `chr` length-2 names for the longitude and latitude columns
#'   added to the result. Default `c("longitude", "latitude")`. Populated for any
#'   row sent to the geocoder, regardless of its final status (so geocoded points
#'   that fall outside every polygon still record their coordinates).
#' @param ... Passed to [tidygeocoder::geocode()] (e.g. `min_time`, `api_options`).
#' @returns A tibble: `data` with `loc_cols` replaced by their canonical values
#'   where confidently reconciled (originals kept where unresolved or flagged
#'   `"geocoded_review"`), plus the two `coord_cols` and `status_col`.
#' @examples
#' \dontrun{
#' dr_loc <- eri_spatial_load("dr", level = 4, cache = TRUE)
#' incidence <- eri_spatial_reconcile(
#'   incidence,
#'   loc_cols     = c("loc", "mun", "prov"),
#'   shapefile    = dr_loc,
#'   admin_cols   = c("adm4_name", "adm3_name", "adm2_name"),
#'   country_name = "Dominican Republic",
#'   method       = "google",  # needs GOOGLEGEOCODE_API_KEY
#'   max_dist     = 1
#' )
#' table(incidence$reconcile_status)
#' }
#' @export
eri_spatial_reconcile <- function(data,
                                  loc_cols,
                                  shapefile,
                                  admin_cols,
                                  country_name = NULL,
                                  method       = "osm",
                                  max_dist     = 0L,
                                  status_col   = "reconcile_status",
                                  coord_cols   = c("longitude", "latitude"),
                                  ...) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} must be installed to use {.fn eri_spatial_reconcile}.")
  }

  data <- tibble::as_tibble(data)

  if (length(loc_cols) == 0L || length(admin_cols) == 0L) {
    cli::cli_abort("{.arg loc_cols} and {.arg admin_cols} must be non-empty.")
  }
  if (length(loc_cols) != length(admin_cols)) {
    cli::cli_abort(c(
      "{.arg loc_cols} and {.arg admin_cols} must be the same length (parallel mapping).",
      "i" = "{.arg loc_cols} has {length(loc_cols)}, {.arg admin_cols} has {length(admin_cols)}."
    ))
  }
  missing_loc <- setdiff(loc_cols, names(data))
  if (length(missing_loc) > 0L) {
    cli::cli_abort("Column{?s} {.val {missing_loc}} not found in {.arg data}.")
  }
  shp_names   <- setdiff(names(shapefile), attr(shapefile, "sf_column"))
  missing_adm <- setdiff(admin_cols, shp_names)
  if (length(missing_adm) > 0L) {
    cli::cli_abort("Column{?s} {.val {missing_adm}} not found in {.arg shapefile}.")
  }
  if (length(coord_cols) != 2L) {
    cli::cli_abort("{.arg coord_cols} must be a length-2 character vector (longitude, latitude).")
  }
  reserved <- c(coord_cols, status_col)
  clash    <- intersect(reserved, names(data))
  if (length(clash) > 0L) {
    cli::cli_abort(c(
      "Output column{?s} {.val {clash}} already exist{?s/} in {.arg data}.",
      "i" = "Rename them, or pass different {.arg coord_cols}/{.arg status_col}."
    ))
  }
  max_dist <- suppressWarnings(as.integer(max_dist))
  if (is.na(max_dist) || max_dist < 0L) {
    cli::cli_abort("{.arg max_dist} must be a non-negative integer.")
  }

  # Work on the distinct free-text tuples to minimise matching and geocoding work.
  keys <- dplyr::distinct(data[, loc_cols, drop = FALSE])

  canon      <- sf::st_drop_geometry(shapefile)[, admin_cols, drop = FALSE]
  canon      <- dplyr::distinct(tibble::as_tibble(canon))
  key_norm   <- lapply(loc_cols,   function(col) .eri_normalize_name(keys[[col]]))
  canon_norm <- lapply(admin_cols, function(col) .eri_normalize_name(canon[[col]]))
  n_lvl      <- length(loc_cols)

  # Pass 1 -- match free-text tuples to canonical units.
  match_idx <- vapply(seq_len(nrow(keys)), function(i) {
    cand <- rep(TRUE, nrow(canon))
    if (n_lvl > 1L) {
      for (j in 2:n_lvl) cand <- cand & (canon_norm[[j]] == key_norm[[j]][i])
    }
    cand[is.na(cand)] <- FALSE
    if (!any(cand) || is.na(key_norm[[1L]][i])) return(NA_integer_)
    cw <- which(cand)
    d  <- as.integer(utils::adist(key_norm[[1L]][i], canon_norm[[1L]][cw]))
    ok <- which(d <= max_dist)
    if (length(ok) == 0L) return(NA_integer_)
    cw[ok[which.min(d[ok])]]
  }, integer(1L))

  # Per-key result, keyed by the original free-text tuple. Canonical values go in
  # prefixed columns so the join back to `data` never collides with `loc_cols`.
  canon_out <- paste0(".canon_", loc_cols)
  res <- keys
  for (k in seq_len(n_lvl)) res[[canon_out[k]]] <- NA_character_
  res$.lon     <- NA_real_
  res$.lat     <- NA_real_
  res$.status  <- NA_character_
  res$.partial <- NA

  matched <- !is.na(match_idx)
  for (k in seq_len(n_lvl)) {
    res[[canon_out[k]]][matched] <- as.character(canon[[admin_cols[k]]][match_idx[matched]])
  }
  res$.status[matched] <- "matched"

  # Pass 2 -- geocode the residual, then assign admin units by point-in-polygon.
  todo <- which(!matched)
  if (length(todo) > 0L && !is.null(method)) {
    addr <- vapply(todo, function(i) {
      parts <- vapply(loc_cols, function(col) as.character(keys[[col]][i]), character(1L))
      parts <- parts[!is.na(parts) & nzchar(parts)]
      paste(c(parts, country_name), collapse = ", ")
    }, character(1L))

    # Skip rows with no usable place name -- nothing to geocode (and no billed call).
    to_geo <- todo[nzchar(addr)]
    if (length(to_geo) > 0L) {
      cli::cli_alert_info("Geocoding {length(to_geo)} unmatched localit{?y/ies} via {.val {method}}...")
      geo <- .eri_geocode(addr[nzchar(addr)], method = method, ...)
      if (nrow(geo) != length(to_geo)) {
        cli::cli_abort(
          "Geocoder returned {nrow(geo)} row{?s} for {length(to_geo)} address{?es} (expected one per address)."
        )
      }
      res$.lon[to_geo]     <- geo$longitude
      res$.lat[to_geo]     <- geo$latitude
      res$.partial[to_geo] <- if ("partial" %in% names(geo)) geo$partial else NA

      has_coords <- to_geo[!is.na(geo$longitude) & !is.na(geo$latitude)]
      if (length(has_coords) > 0L) {
        jf <- tibble::tibble(
          .rid      = has_coords,
          longitude = res$.lon[has_coords],
          latitude  = res$.lat[has_coords]
        )
        jr <- eri_spatial_join(
          jf, lat_col = "latitude", lon_col = "longitude",
          shapefile = shapefile, admin_cols = admin_cols
        )
        # A point on a shared boundary (or in overlapping polygons) can match more
        # than one unit; keep the first (shapefile order) so each input row resolves
        # to exactly one admin unit.
        jr  <- dplyr::distinct(jr, .rid, .keep_all = TRUE)
        ord <- match(has_coords, jr$.rid)

        # A geocode is trusted only if the service did not flag a partial match AND
        # the assigned coarser admin units agree with the parent levels the analyst
        # supplied. Trusted -> "geocoded" and names assigned; otherwise
        # "geocoded_review" -> coordinates kept for inspection, names left untouched.
        for (i in seq_along(has_coords)) {
          rk   <- has_coords[i]
          jrow <- ord[i]
          if (is.na(jrow) || is.na(jr[[admin_cols[1L]]][jrow])) next  # outside all polygons

          # Any coarser level disagreeing with the analyst's claim flags the row.
          consistent <- TRUE
          if (n_lvl > 1L) {
            for (j in 2:n_lvl) {
              claimed  <- key_norm[[j]][rk]
              assigned <- .eri_normalize_name(jr[[admin_cols[j]]][jrow])
              if (!is.na(claimed) && !is.na(assigned) && !identical(claimed, assigned)) {
                consistent <- FALSE
                break
              }
            }
          }

          if (isTRUE(res$.partial[rk]) || !consistent) {
            res$.status[rk] <- "geocoded_review"
          } else {
            for (k in seq_len(n_lvl)) {
              res[[canon_out[k]]][rk] <- as.character(jr[[admin_cols[k]]][jrow])
            }
            res$.status[rk] <- "geocoded"
          }
        }
      }
    }
  }
  res$.status[is.na(res$.status)] <- "unresolved"

  # Join per-key results back to the full data and coalesce names in place.
  out <- dplyr::left_join(data, res, by = loc_cols)
  for (k in seq_len(n_lvl)) {
    canonical <- out[[canon_out[k]]]
    out[[loc_cols[k]]] <- ifelse(is.na(canonical), out[[loc_cols[k]]], canonical)
  }
  out[[coord_cols[1L]]] <- out$.lon
  out[[coord_cols[2L]]] <- out$.lat
  out[[status_col]]     <- out$.status
  out <- out[, setdiff(names(out), c(canon_out, ".lon", ".lat", ".status", ".partial")), drop = FALSE]

  n_keys <- nrow(keys)
  n_m    <- sum(res$.status == "matched")
  n_g    <- sum(res$.status == "geocoded")
  n_r    <- sum(res$.status == "geocoded_review")
  n_u    <- sum(res$.status == "unresolved")
  cli::cli_alert_success(
    "Reconciled {n_keys} distinct localit{?y/ies}: {n_m} matched, {n_g} geocoded, {n_r} need review, {n_u} unresolved."
  )
  if (n_r > 0L) {
    cli::cli_alert_warning(
      "{n_r} geocode{?s} flagged {.val geocoded_review} (low-confidence or parent mismatch) -- verify before use."
    )
  }
  tibble::as_tibble(out)
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
      # A missing directory just means nothing has been uploaded yet -- return empty quietly;
      # only warn on a genuine error.
      if (!grepl("does not exist|not found|404", conditionMessage(e), ignore.case = TRUE)) {
        cli::cli_warn("Could not list Azure LandScan directory: {conditionMessage(e)}")
      }
      tibble::tibble(name = character(), size = integer(),
                     isdir = logical(), lastModified = as.POSIXct(character()))
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

  # Cache the raster in the project and reuse it, so repeated calls (e.g. adm3 then adm4) don't
  # re-download ~100 MB each time; record provenance when in a research project. Outside a project,
  # fall back to a session tempdir cache. (issue #148)
  in_project <- file.exists(file.path(getwd(), "research.yaml"))
  cache_dir  <- if (in_project) file.path(getwd(), "data") else tempdir()
  tif_path   <- file.path(cache_dir, basename(blob_path))

  if (file.exists(tif_path)) {
    cli::cli_alert_info("Using cached LandScan {year} ({.path {tif_path}}).")
  } else {
    cli::cli_alert_info("Downloading LandScan {year} (~100 MB) from Azure...")
    if (in_project) {
      eri_research_pull(path = blob_path, dest = cache_dir, data_con = con, progress = TRUE)
    } else {
      .eri_blob_read(con, blob_path, tif_path, progress = TRUE)
    }
  }

  cli::cli_alert_info("Extracting population for {nrow(shapefile)} feature{?s}...")
  rast_obj <- terra::rast(tif_path)
  shapefile$pop <- exactextractr::exact_extract(rast_obj, shapefile, fun = fun)

  cli::cli_alert_success(
    "Population extracted using LandScan {year}. Column {.val pop} added to shapefile."
  )
  shapefile
}
