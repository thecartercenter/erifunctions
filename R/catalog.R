#### Data catalog for processed-layer Azure objects ####

.ERI_CATALOG_PATH <- "_catalog/data_catalog.yaml"

# Read catalog from Azure; returns list with $entries element (may be empty).
#' @keywords internal
.eri_catalog_read <- function(data_con) {
  if (!AzureStor::storage_file_exists(data_con, .ERI_CATALOG_PATH)) {
    return(list(entries = list()))
  }
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  .eri_blob_read(data_con, .ERI_CATALOG_PATH, tmp)
  cat <- yaml::read_yaml(tmp)
  if (is.null(cat$entries)) cat$entries <- list()
  cat
}

# Write catalog list back to Azure.
#' @keywords internal
.eri_catalog_write <- function(catalog, data_con) {
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(catalog, tmp)
  dir_path <- dirname(.ERI_CATALOG_PATH)
  .eri_create_azure_dir(data_con, dir_path)
  .eri_blob_write(data_con, tmp, .ERI_CATALOG_PATH)
}

# Resolve data container from arg or env vars.
#' @keywords internal
.eri_catalog_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

# Build a single catalog entry list from its components.
#' @keywords internal
.eri_catalog_entry <- function(path, country, disease, data_type, layer,
                                period, row_count, analyst) {
  list(
    path             = path,
    country          = country,
    disease          = disease,
    data_type        = data_type,
    layer            = layer,
    period           = if (is.null(period)) NA_character_ else period,
    file_format      = tools::file_ext(path),
    row_count        = if (is.null(row_count)) NA_integer_ else as.integer(row_count),
    size_bytes       = NA_integer_,
    registered_at    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    registered_by    = analyst,
    last_verified_at = NA_character_,
    checksum         = NA_character_
  )
}

#### eri_catalog_register ####

#' Register a processed-layer file in the data catalog
#'
#' Adds or updates an entry for the given blob path in `_catalog/data_catalog.yaml`
#' in the `data/` Azure blob. Existing entries are matched by `path` (upsert semantics).
#'
#' @param path `chr` Blob path of the file (e.g. `"dr/malaria/surveillance/processed/2024_W01.parquet"`).
#' @param country `chr` Country code (e.g. `"uga"`).
#' @param disease `chr` Disease name (e.g. `"oncho"`).
#' @param data_type `chr` Data type (e.g. `"surveillance"`, `"cmr"`, `"odk"`).
#' @param layer `chr` Storage layer (`"raw"`, `"staged"`, or `"processed"`).
#' @param period `chr` or `NULL` Data period string (e.g. `"2024-W01"`, `"202405"`).
#' @param row_count `int` or `NULL` Number of rows in the file, if known.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The registered entry (invisibly).
#' @examples
#' \dontrun{
#' eri_catalog_register(
#'   path      = "uga/oncho/surveillance/processed/2024_W01.parquet",
#'   country   = "uga",
#'   disease   = "oncho",
#'   data_type = "surveillance",
#'   layer     = "processed",
#'   period    = "2024-W01"
#' )
#' }
#' @export
eri_catalog_register <- function(
    path,
    country,
    disease,
    data_type,
    layer,
    period    = NULL,
    row_count = NULL,
    data_con  = NULL
) {
  data_con <- .eri_catalog_con(data_con)
  analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
  catalog  <- .eri_catalog_read(data_con)

  entry    <- .eri_catalog_entry(path, country, disease, data_type, layer,
                                  period, row_count, analyst)

  existing <- vapply(catalog$entries, function(e) identical(e$path, path), logical(1L))
  if (any(existing)) {
    catalog$entries[[which(existing)[[1L]]]] <- entry
  } else {
    catalog$entries <- c(catalog$entries, list(entry))
  }

  .eri_catalog_write(catalog, data_con)
  cli::cli_alert_success("Catalog: registered {.path {basename(path)}}.")
  invisible(entry)
}

#### eri_catalog_remove ####

#' Remove a file's entry from the data catalog
#'
#' Deletes the catalog entry whose `path` matches, from `_catalog/data_catalog.yaml`
#' in the `data/` Azure blob. This is the inverse of [eri_catalog_register()] — use
#' it when a processed file has been deleted or superseded and should no longer
#' appear in the catalog. Removing the catalog entry does **not** delete the
#' underlying blob.
#'
#' @param path `chr` Blob path of the entry to remove (e.g.
#'   `"dr/malaria/surveillance/processed/2024_W01.parquet"`).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns `TRUE` if an entry was removed, `FALSE` if no entry matched (invisibly).
#' @examples
#' \dontrun{
#' eri_catalog_remove("atlantis/malaria/surveillance/processed/2024-W01.parquet")
#' }
#' @export
eri_catalog_remove <- function(path, data_con = NULL) {
  data_con <- .eri_catalog_con(data_con)
  catalog  <- .eri_catalog_read(data_con)

  if (length(catalog$entries) == 0L) {
    cli::cli_inform("Catalog is empty -- nothing to remove.")
    return(invisible(FALSE))
  }

  matches <- vapply(catalog$entries, function(e) identical(e$path, path), logical(1L))
  if (!any(matches)) {
    cli::cli_warn("No catalog entry found for {.path {path}}.")
    return(invisible(FALSE))
  }

  catalog$entries <- catalog$entries[!matches]
  .eri_catalog_write(catalog, data_con)
  cli::cli_alert_success("Catalog: removed {.path {basename(path)}}.")
  invisible(TRUE)
}

#### eri_catalog_query ####

#' Query the data catalog
#'
#' Returns a filtered tibble of catalog entries from `_catalog/data_catalog.yaml`
#' in the `data/` Azure blob. All filter arguments are optional; `NULL` means no
#' filter on that dimension.
#'
#' @param country `chr` or `NULL` Filter by country code.
#' @param disease `chr` or `NULL` Filter by disease name.
#' @param data_type `chr` or `NULL` Filter by data type.
#' @param layer `chr` or `NULL` Filter by storage layer.
#' @param period `chr` or `NULL` Filter by period string (exact match).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns: `path`, `country`, `disease`, `data_type`, `layer`,
#'   `period`, `file_format`, `row_count`, `size_bytes`, `registered_at`, `registered_by`,
#'   `last_verified_at`.
#' @examples
#' \dontrun{
#' # All processed Uganda oncho data
#' eri_catalog_query(country = "uga", disease = "oncho", layer = "processed")
#'
#' # Everything in the catalog
#' eri_catalog_query()
#' }
#' @export
eri_catalog_query <- function(
    country   = NULL,
    disease   = NULL,
    data_type = NULL,
    layer     = NULL,
    period    = NULL,
    data_con  = NULL
) {
  data_con <- .eri_catalog_con(data_con)
  catalog  <- .eri_catalog_read(data_con)

  empty_result <- tibble::tibble(
    path             = character(),
    country          = character(),
    disease          = character(),
    data_type        = character(),
    layer            = character(),
    period           = character(),
    file_format      = character(),
    row_count        = integer(),
    size_bytes       = integer(),
    registered_at    = character(),
    registered_by    = character(),
    last_verified_at = character()
  )

  if (length(catalog$entries) == 0L) {
    cli::cli_inform("Catalog is empty.")
    return(empty_result)
  }

  entries <- catalog$entries

  if (!is.null(country))
    entries <- Filter(function(e) identical(e$country, country), entries)
  if (!is.null(disease))
    entries <- Filter(function(e) identical(e$disease, disease), entries)
  if (!is.null(data_type))
    entries <- Filter(function(e) identical(e$data_type, data_type), entries)
  if (!is.null(layer))
    entries <- Filter(function(e) identical(e$layer, layer), entries)
  if (!is.null(period))
    entries <- Filter(function(e) identical(e$period, period), entries)

  if (length(entries) == 0L) {
    cli::cli_inform("No catalog entries match the specified filters.")
    return(empty_result)
  }

  .na_chr <- function(x) if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x)
  .na_int <- function(x) if (is.null(x) || length(x) == 0L) NA_integer_  else as.integer(x)

  tibble::tibble(
    path             = vapply(entries, function(e) .na_chr(e$path),             character(1L)),
    country          = vapply(entries, function(e) .na_chr(e$country),          character(1L)),
    disease          = vapply(entries, function(e) .na_chr(e$disease),          character(1L)),
    data_type        = vapply(entries, function(e) .na_chr(e$data_type),        character(1L)),
    layer            = vapply(entries, function(e) .na_chr(e$layer),            character(1L)),
    period           = vapply(entries, function(e) .na_chr(e$period),           character(1L)),
    file_format      = vapply(entries, function(e) .na_chr(e$file_format),      character(1L)),
    row_count        = vapply(entries, function(e) .na_int(e$row_count),        integer(1L)),
    size_bytes       = vapply(entries, function(e) .na_int(e$size_bytes),       integer(1L)),
    registered_at    = vapply(entries, function(e) .na_chr(e$registered_at),    character(1L)),
    registered_by    = vapply(entries, function(e) .na_chr(e$registered_by),    character(1L)),
    last_verified_at = vapply(entries, function(e) .na_chr(e$last_verified_at), character(1L))
  )
}

#### eri_catalog_verify ####

#' Verify that catalog entries still exist in Azure
#'
#' Checks each entry in the data catalog against the live `data/` blob. Returns a
#' tibble with an `exists` column. Updates `last_verified_at` for entries that are
#' found. Missing entries are flagged but not removed.
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble (the result of [eri_catalog_query()]) with an added `exists` column.
#' @examples
#' \dontrun{
#' result <- eri_catalog_verify()
#' result[!result$exists, ]   # see what is missing
#' }
#' @export
eri_catalog_verify <- function(data_con = NULL) {
  data_con <- .eri_catalog_con(data_con)
  catalog  <- .eri_catalog_read(data_con)

  if (length(catalog$entries) == 0L) {
    cli::cli_inform("Catalog is empty -- nothing to verify.")
    return(eri_catalog_query(data_con = data_con))
  }

  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  exists_vec <- logical(length(catalog$entries))

  for (i in seq_along(catalog$entries)) {
    e      <- catalog$entries[[i]]
    exists <- tryCatch(
      AzureStor::storage_file_exists(data_con, e$path),
      error = function(err) FALSE
    )
    exists_vec[[i]] <- exists
    if (exists) catalog$entries[[i]]$last_verified_at <- now
  }

  .eri_catalog_write(catalog, data_con)

  n_ok      <- sum(exists_vec)
  n_missing <- sum(!exists_vec)
  if (n_missing > 0L) {
    cli::cli_warn(
      "{n_missing} catalog entr{?y/ies} not found in Azure. Check the {.field exists} column."
    )
  } else {
    cli::cli_alert_success("All {n_ok} catalog entr{?y/ies} verified.")
  }

  .na_chr <- function(x) if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x)
  .na_int <- function(x) if (is.null(x) || length(x) == 0L) NA_integer_  else as.integer(x)
  entries <- catalog$entries

  tibble::tibble(
    path             = vapply(entries, function(e) .na_chr(e$path),             character(1L)),
    country          = vapply(entries, function(e) .na_chr(e$country),          character(1L)),
    disease          = vapply(entries, function(e) .na_chr(e$disease),          character(1L)),
    data_type        = vapply(entries, function(e) .na_chr(e$data_type),        character(1L)),
    layer            = vapply(entries, function(e) .na_chr(e$layer),            character(1L)),
    period           = vapply(entries, function(e) .na_chr(e$period),           character(1L)),
    file_format      = vapply(entries, function(e) .na_chr(e$file_format),      character(1L)),
    row_count        = vapply(entries, function(e) .na_int(e$row_count),        integer(1L)),
    size_bytes       = vapply(entries, function(e) .na_int(e$size_bytes),       integer(1L)),
    registered_at    = vapply(entries, function(e) .na_chr(e$registered_at),    character(1L)),
    registered_by    = vapply(entries, function(e) .na_chr(e$registered_by),    character(1L)),
    last_verified_at = vapply(entries, function(e) .na_chr(e$last_verified_at), character(1L)),
    exists           = exists_vec
  )
}
