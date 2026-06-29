#### Artifact registry for non-standard reference files ####

.ERI_ARTIFACT_REGISTRY_PATH <- "artifacts/_registry.yaml"
.ERI_ARTIFACT_TYPES <- c("spatial", "population", "study_data", "reference", "other")

#' @keywords internal
.eri_artifact_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#' @keywords internal
.eri_artifact_registry_read <- function(data_con) {
  if (!AzureStor::storage_file_exists(data_con, .ERI_ARTIFACT_REGISTRY_PATH)) {
    return(list(entries = list()))
  }
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  .eri_blob_read(data_con, .ERI_ARTIFACT_REGISTRY_PATH, tmp)
  reg <- yaml::read_yaml(tmp)
  if (is.null(reg$entries)) reg$entries <- list()
  reg
}

#' @keywords internal
.eri_artifact_registry_write <- function(registry, data_con) {
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(registry, tmp)
  dir_path <- dirname(.ERI_ARTIFACT_REGISTRY_PATH)
  .eri_create_azure_dir(data_con, dir_path)
  .eri_blob_write(data_con, tmp, .ERI_ARTIFACT_REGISTRY_PATH)
}

#### eri_artifact_upload ####

#' Upload a non-standard reference file to the artifact registry
#'
#' Uploads a local file to `artifacts/{type}/{name}/` in the `data/` Azure blob and
#' registers it in `artifacts/_registry.yaml`. Use this for files that don't go through
#' the standard DQ pipeline — external study data, population grids, project-specific inputs.
#'
#' Standard spatial files already in `data/spatial/` do not need to go through this function;
#' pull them directly via [eri_research_pull()].
#'
#' @param local_path `chr` Path to the local file to upload.
#' @param name `chr` Short identifier for this artifact (e.g. `"dr_irs_2024"`). Must be
#'   unique in the registry; re-uploading the same name updates the entry (upsert).
#' @param type `chr` Artifact type. One of `"spatial"`, `"population"`, `"study_data"`,
#'   `"reference"`, `"other"`.
#' @param description `chr` Human-readable description of what this file contains.
#' @param version `chr` or `NULL` Optional version string (e.g. `"1.0"`, `"2024-05"`).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The registered entry (invisibly).
#' @examples
#' \dontrun{
#' eri_artifact_upload(
#'   local_path  = "data/raw/dr_irs_campaign_2024.xlsx",
#'   name        = "dr_irs_2024",
#'   type        = "study_data",
#'   description = "IRS campaign data from MoH for Dominican Republic 2024"
#' )
#' }
#' @export
eri_artifact_upload <- function(
    local_path,
    name,
    type,
    description,
    version  = NULL,
    data_con = NULL
) {
  if (!file.exists(local_path)) {
    cli::cli_abort("Local file not found: {.path {local_path}}")
  }
  type <- match.arg(type, .ERI_ARTIFACT_TYPES)

  data_con <- .eri_artifact_con(data_con)
  analyst  <- .eri_analyst_id(data_con)

  filename   <- basename(local_path)
  azure_path <- paste0("artifacts/", type, "/", name, "/", filename)

  dir_path <- paste0("artifacts/", type, "/", name)
  .eri_create_azure_dir(data_con, dir_path)
  .eri_blob_write(data_con, local_path, azure_path)

  entry <- list(
    name        = name,
    type        = type,
    description = description,
    version     = if (is.null(version)) NA_character_ else version,
    azure_path  = azure_path,
    filename    = filename,
    file_format = tools::file_ext(filename),
    uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    uploaded_by = analyst,
    archived    = FALSE
  )

  registry <- .eri_artifact_registry_read(data_con)
  existing <- vapply(registry$entries, function(e) identical(e$name, name), logical(1L))
  if (any(existing)) {
    registry$entries[[which(existing)[[1L]]]] <- entry
  } else {
    registry$entries <- c(registry$entries, list(entry))
  }
  .eri_artifact_registry_write(registry, data_con)

  cli::cli_alert_success(
    "Artifact {.val {name}} ({type}) uploaded to {.path {azure_path}}."
  )
  invisible(entry)
}

#### eri_artifact_list ####

#' List registered artifacts
#'
#' Returns a tibble of entries from `artifacts/_registry.yaml` in the `data/` Azure blob.
#' Archived artifacts are excluded by default.
#'
#' @param type `chr` or `NULL` Filter to a specific artifact type (`"spatial"`, `"population"`,
#'   `"study_data"`, `"reference"`, `"other"`). `NULL` returns all types.
#' @param include_archived `lgl` If `TRUE`, include archived entries. Default `FALSE`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns: `name`, `type`, `description`, `version`, `azure_path`,
#'   `filename`, `file_format`, `uploaded_at`, `uploaded_by`, `archived`.
#' @examples
#' \dontrun{
#' # All active artifacts
#' eri_artifact_list()
#'
#' # Only study data
#' eri_artifact_list(type = "study_data")
#' }
#' @export
eri_artifact_list <- function(type = NULL, include_archived = FALSE, data_con = NULL) {
  if (!is.null(type)) type <- match.arg(type, .ERI_ARTIFACT_TYPES)

  data_con <- .eri_artifact_con(data_con)
  registry <- .eri_artifact_registry_read(data_con)

  empty_result <- tibble::tibble(
    name        = character(),
    type        = character(),
    description = character(),
    version     = character(),
    azure_path  = character(),
    filename    = character(),
    file_format = character(),
    uploaded_at = character(),
    uploaded_by = character(),
    archived    = logical()
  )

  if (length(registry$entries) == 0L) {
    cli::cli_inform("Artifact registry is empty.")
    return(empty_result)
  }

  entries <- registry$entries
  if (!include_archived) {
    entries <- Filter(function(e) !isTRUE(e$archived), entries)
  }
  if (!is.null(type)) {
    entries <- Filter(function(e) identical(e$type, type), entries)
  }

  if (length(entries) == 0L) {
    cli::cli_inform("No artifacts match the specified filters.")
    return(empty_result)
  }

  .na_chr <- function(x) if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x)

  tibble::tibble(
    name        = vapply(entries, function(e) .na_chr(e$name),        character(1L)),
    type        = vapply(entries, function(e) .na_chr(e$type),        character(1L)),
    description = vapply(entries, function(e) .na_chr(e$description), character(1L)),
    version     = vapply(entries, function(e) .na_chr(e$version),     character(1L)),
    azure_path  = vapply(entries, function(e) .na_chr(e$azure_path),  character(1L)),
    filename    = vapply(entries, function(e) .na_chr(e$filename),    character(1L)),
    file_format = vapply(entries, function(e) .na_chr(e$file_format), character(1L)),
    uploaded_at = vapply(entries, function(e) .na_chr(e$uploaded_at), character(1L)),
    uploaded_by = vapply(entries, function(e) .na_chr(e$uploaded_by), character(1L)),
    archived    = vapply(entries, function(e) isTRUE(e$archived),     logical(1L))
  )
}

#### eri_artifact_pull ####

#' Download an artifact from the registry to a local destination
#'
#' Downloads the registered artifact file to `dest`. If a `research.yaml` is found
#' in the current working directory (placed there by [eri_research_init()]), the pull
#' is recorded in the manifest's `artifacts_used` list.
#'
#' @param name `chr` Artifact name as registered (e.g. `"dr_irs_2024"`).
#' @param dest `chr` Local directory to download the file into. Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Local path to the downloaded file (invisibly).
#' @examples
#' \dontrun{
#' eri_artifact_pull("dr_irs_2024", dest = "data/raw")
#' }
#' @export
eri_artifact_pull <- function(name, dest = getwd(), data_con = NULL) {
  data_con <- .eri_artifact_con(data_con)
  registry <- .eri_artifact_registry_read(data_con)

  entries  <- registry$entries
  idx      <- which(vapply(entries, function(e) identical(e$name, name), logical(1L)))

  if (length(idx) == 0L) {
    cli::cli_abort("Artifact {.val {name}} not found in registry.")
  }

  entry <- entries[[idx[[1L]]]]
  if (isTRUE(entry$archived)) {
    cli::cli_abort(
      "Artifact {.val {name}} is archived. Use {.fn eri_artifact_list}(include_archived = TRUE) to inspect."
    )
  }

  if (!dir.exists(dest)) dir.create(dest, recursive = TRUE)
  local_path <- file.path(dest, entry$filename)
  .eri_blob_read(data_con, entry$azure_path, local_path)

  research_yaml_path <- file.path(getwd(), "research.yaml")
  if (file.exists(research_yaml_path)) {
    .eri_artifact_record_usage(name, entry, research_yaml_path)
  }

  cli::cli_alert_success(
    "Artifact {.val {name}} downloaded to {.path {local_path}}."
  )
  invisible(local_path)
}

#' @keywords internal
.eri_artifact_record_usage <- function(name, entry, research_yaml_path) {
  tryCatch({
    manifest <- yaml::read_yaml(research_yaml_path)
    if (is.null(manifest$artifacts_used)) manifest$artifacts_used <- list()

    usage_entry <- list(
      name       = name,
      azure_path = entry$azure_path,
      pulled_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )

    already <- vapply(
      manifest$artifacts_used,
      function(u) identical(u$name, name),
      logical(1L)
    )
    if (any(already)) {
      manifest$artifacts_used[[which(already)[[1L]]]] <- usage_entry
    } else {
      manifest$artifacts_used <- c(manifest$artifacts_used, list(usage_entry))
    }

    yaml::write_yaml(manifest, research_yaml_path)
  }, error = function(e) {
    cli::cli_warn("Could not update research.yaml: {conditionMessage(e)}")
  })
}

#### eri_artifact_archive ####

#' Archive an artifact (soft-delete)
#'
#' Sets `archived: true` on the registry entry. The file is preserved in Azure but
#' will no longer appear in [eri_artifact_list()] by default and cannot be pulled.
#'
#' @param name `chr` Artifact name to archive.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns `NULL` invisibly.
#' @examples
#' \dontrun{
#' eri_artifact_archive("dr_irs_2022")
#' }
#' @export
eri_artifact_archive <- function(name, data_con = NULL) {
  data_con <- .eri_artifact_con(data_con)
  registry <- .eri_artifact_registry_read(data_con)

  idx <- which(vapply(registry$entries, function(e) identical(e$name, name), logical(1L)))
  if (length(idx) == 0L) {
    cli::cli_abort("Artifact {.val {name}} not found in registry.")
  }

  if (isTRUE(registry$entries[[idx[[1L]]]]$archived)) {
    cli::cli_inform("Artifact {.val {name}} is already archived.")
    return(invisible(NULL))
  }

  registry$entries[[idx[[1L]]]]$archived <- TRUE
  .eri_artifact_registry_write(registry, data_con)

  cli::cli_alert_success("Artifact {.val {name}} archived (file preserved in Azure).")
  invisible(NULL)
}
