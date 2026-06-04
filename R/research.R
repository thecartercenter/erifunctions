#### Research project scaffolding ####

.ERI_RESEARCH_AZURE_ROOT <- "research"

#' @keywords internal
.eri_research_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#' @keywords internal
.eri_research_yaml_path <- function(path) file.path(path, "research.yaml")

#' @keywords internal
.eri_research_read_manifest <- function(path) {
  yaml_path <- .eri_research_yaml_path(path)
  if (!file.exists(yaml_path)) {
    cli::cli_abort("No {.file research.yaml} found in {.path {path}}. Run {.fn eri_research_init} first.")
  }
  yaml::read_yaml(yaml_path)
}

#' @keywords internal
.eri_research_write_manifest <- function(manifest, path) {
  yaml::write_yaml(manifest, .eri_research_yaml_path(path))
}

#### eri_research_init ####

#' Initialise a new research project
#'
#' Creates the local project scaffold (`data/`, `figs/`, `outputs/` directories plus a
#' `research.yaml` manifest) and the corresponding `research/{project_name}/` directory
#' in the `data/` Azure blob. Run once at the start of a new study.
#'
#' @param project_name `chr` Short identifier for the project (e.g. `"dr_irs_2024"`).
#'   Used as the Azure directory name and the primary key in the manifest.
#' @param country `chr` Country code (e.g. `"dr"`).
#' @param disease `chr` Disease name (e.g. `"malaria"`).
#' @param description `chr` Human-readable description of the research question.
#' @param path `chr` Local directory in which to scaffold the project. Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @param dry_run `lgl` If `TRUE`, print what would be created without writing anything. Default `FALSE`.
#' @returns Path to the `research.yaml` file (invisibly), or `NULL` for `dry_run`.
#' @examples
#' \dontrun{
#' eri_research_init(
#'   project_name = "dr_irs_2024",
#'   country      = "dr",
#'   disease      = "malaria",
#'   description  = "ITS analysis of IRS impact on malaria incidence in Dominican Republic"
#' )
#' }
#' @export
eri_research_init <- function(
    project_name,
    country,
    disease,
    description,
    path     = getwd(),
    data_con = NULL,
    dry_run  = FALSE
) {
  yaml_path <- .eri_research_yaml_path(path)

  if (file.exists(yaml_path)) {
    existing <- yaml::read_yaml(yaml_path)
    if (identical(existing$project_name, project_name)) {
      cli::cli_abort(
        "Project {.val {project_name}} already exists at {.path {path}}. \\
         Use {.fn eri_research_resume} to reconnect."
      )
    }
  }

  azure_path <- paste0(.ERI_RESEARCH_AZURE_ROOT, "/", project_name, "/")
  local_dirs <- file.path(path, c("data", "figs", "outputs"))

  if (dry_run) {
    cli::cli_inform(c(
      "i" = "Dry run — nothing written.",
      " " = "Would create local dirs: {.path {local_dirs}}",
      " " = "Would write: {.path {yaml_path}}",
      " " = "Would create Azure dir: {.path {azure_path}}"
    ))
    return(invisible(NULL))
  }

  for (d in local_dirs) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  }

  analyst <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
  manifest <- list(
    project_name   = project_name,
    country        = country,
    disease        = disease,
    description    = description,
    created_at     = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    created_by     = analyst,
    azure_path     = azure_path,
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list()
  )
  .eri_research_write_manifest(manifest, path)

  data_con <- .eri_research_con(data_con)
  if (!AzureStor::storage_dir_exists(data_con, azure_path)) {
    AzureStor::create_storage_dir(data_con, azure_path)
  }

  cli::cli_alert_success(
    "Research project {.val {project_name}} initialised at {.path {path}}."
  )
  cli::cli_inform(c(
    " " = "Local dirs: {.path data/}, {.path figs/}, {.path outputs/}",
    " " = "Manifest:   {.path research.yaml}",
    " " = "Azure:      {.path {azure_path}}"
  ))
  invisible(yaml_path)
}

#### eri_research_resume ####

#' Resume a research project session
#'
#' Reads `research.yaml` from the project root, re-establishes the Azure connection,
#' and prints a session summary (last pull, last log entry, snapshot count). Call this
#' at the top of each work session instead of re-typing project context.
#'
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The manifest list (invisibly).
#' @examples
#' \dontrun{
#' eri_research_resume()
#' }
#' @export
eri_research_resume <- function(path = getwd(), data_con = NULL) {
  manifest <- .eri_research_read_manifest(path)
  data_con <- .eri_research_con(data_con)

  last_pull <- if (length(manifest$pulled_data) > 0L) {
    pulls <- manifest$pulled_data
    tail(vapply(pulls, function(p) rlang::`%||%`(p$pulled_at, ""), character(1L)), 1L)
  } else {
    "none"
  }

  last_log <- if (length(manifest$log) > 0L) {
    entries <- manifest$log
    last    <- entries[[length(entries)]]
    paste0("[", last$timestamp, "] ", last$note)
  } else {
    "no entries"
  }

  n_snapshots <- length(manifest$snapshots)

  cli::cli_inform(c(
    "v" = "Project: {.val {manifest$project_name}} ({manifest$country} / {manifest$disease})",
    " " = "Azure:      {.path {manifest$azure_path}}",
    " " = "Last pull:  {last_pull}",
    " " = "Last log:   {last_log}",
    " " = "Snapshots:  {n_snapshots}"
  ))

  invisible(manifest)
}

#### eri_research_log ####

#' Add an entry to the research lab notebook
#'
#' Appends a timestamped free-text note to the `log` section of `research.yaml`.
#' Use this to record decisions, observations, or status updates during analysis.
#'
#' @param note `chr` The text to log.
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @returns `NULL` invisibly.
#' @examples
#' \dontrun{
#' eri_research_log("Ran ITS model — negative binomial converged. Saving output.")
#' }
#' @export
eri_research_log <- function(note, path = getwd()) {
  manifest <- .eri_research_read_manifest(path)

  entry <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    note      = note
  )

  manifest$log <- c(manifest$log, list(entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success("Log entry added.")
  invisible(NULL)
}

#### eri_research_list ####

#' List all research projects in Azure
#'
#' Returns a tibble of projects under `research/` in the `data/` Azure blob.
#' Each row reflects what was recorded in the project's `research.yaml` at last upload.
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns: `project_name`, `azure_path`.
#' @examples
#' \dontrun{
#' eri_research_list()
#' }
#' @export
eri_research_list <- function(data_con = NULL) {
  data_con <- .eri_research_con(data_con)

  empty_result <- tibble::tibble(
    project_name = character(),
    azure_path   = character()
  )

  all_files <- tryCatch(
    AzureStor::list_storage_files(data_con, .ERI_RESEARCH_AZURE_ROOT, info = "name"),
    error = function(e) character(0L)
  )

  if (length(all_files) == 0L) {
    cli::cli_inform("No research projects found in Azure.")
    return(empty_result)
  }

  # Each project sits one level deep: research/{project_name}/
  project_dirs <- unique(
    sub(paste0("^", .ERI_RESEARCH_AZURE_ROOT, "/([^/]+).*$"), "\\1", all_files)
  )
  project_dirs <- project_dirs[nchar(project_dirs) > 0L]

  if (length(project_dirs) == 0L) {
    cli::cli_inform("No research projects found in Azure.")
    return(empty_result)
  }

  tibble::tibble(
    project_name = project_dirs,
    azure_path   = paste0(.ERI_RESEARCH_AZURE_ROOT, "/", project_dirs, "/")
  )
}

#### eri_research_pull ####

#' Pull data from Azure into a research project
#'
#' Downloads files from Azure into a local destination and records every pull in
#' `research.yaml` for provenance. Two modes:
#'
#' - **Canonical**: supply `country`, `disease`, and `data_type` to pull from the
#'   standard processed layer (`{country}/{disease}/{data_type}/processed/`).
#' - **Path**: supply `path` to pull any Azure location (e.g. `"data/spatial/dom_admin_boundaries/"`).
#'
#' For non-standard external files not yet in Azure, upload them first with
#' [eri_artifact_upload()], then pull with [eri_artifact_pull()].
#'
#' @param country `chr` or `NULL` Country code (e.g. `"dr"`). Used with `disease` and `data_type`.
#' @param disease `chr` or `NULL` Disease name (e.g. `"malaria"`). Used with `country` and `data_type`.
#' @param data_type `chr` or `NULL` Data type (`"surveillance"`, `"cmr"`, `"odk"`). Used with `country` and `disease`.
#' @param path `chr` or `NULL` Explicit Azure blob path to download from. Mutually exclusive with canonical args.
#' @param dest `chr` or `NULL` Local directory to download files into. Defaults to `data/` inside `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Character vector of local file paths downloaded (invisibly).
#' @examples
#' \dontrun{
#' # Pull canonical processed surveillance data
#' eri_research_pull(country = "dr", disease = "malaria", data_type = "surveillance")
#'
#' # Pull standard spatial reference files
#' eri_research_pull(path = "spatial/dom_admin_boundaries")
#' }
#' @export
eri_research_pull <- function(
    country   = NULL,
    disease   = NULL,
    data_type = NULL,
    path      = NULL,
    dest      = NULL,
    data_con  = NULL
) {
  has_canonical <- !is.null(country) && !is.null(disease) && !is.null(data_type)
  has_path      <- !is.null(path)

  if (!has_canonical && !has_path) {
    cli::cli_abort(
      "Supply either {.arg country} + {.arg disease} + {.arg data_type}, or {.arg path}."
    )
  }
  if (has_canonical && has_path) {
    cli::cli_abort(
      "Supply either canonical args ({.arg country}/{.arg disease}/{.arg data_type}) or {.arg path}, not both."
    )
  }

  azure_path <- if (has_canonical) {
    paste(country, disease, data_type, "processed", sep = "/")
  } else {
    path
  }

  data_con   <- .eri_research_con(data_con)
  local_dest <- if (!is.null(dest)) dest else file.path(getwd(), "data")
  if (!dir.exists(local_dest)) dir.create(local_dest, recursive = TRUE)

  all_names <- tryCatch(
    AzureStor::list_storage_files(data_con, azure_path, info = "name"),
    error = function(e) {
      cli::cli_abort("Could not list {.path {azure_path}}: {conditionMessage(e)}")
    }
  )

  # Keep only files (no trailing slash / no directory entries)
  file_names <- all_names[!grepl("/$", all_names) & nchar(basename(all_names)) > 0L]

  if (length(file_names) == 0L) {
    cli::cli_warn("No files found at {.path {azure_path}}.")
    return(invisible(character(0L)))
  }

  local_paths <- vapply(file_names, function(f) {
    lpath <- file.path(local_dest, basename(f))
    AzureStor::storage_download(data_con, f, lpath, overwrite = TRUE)
    lpath
  }, character(1L), USE.NAMES = FALSE)

  research_yaml <- file.path(getwd(), "research.yaml")
  if (file.exists(research_yaml)) {
    .eri_research_record_pull(azure_path, local_paths, local_dest, research_yaml)
  }

  cli::cli_alert_success(
    "Pulled {length(local_paths)} file{?s} from {.path {azure_path}} to {.path {local_dest}}."
  )
  invisible(local_paths)
}

#' @keywords internal
.eri_research_record_pull <- function(azure_path, local_paths, local_dest, yaml_path) {
  tryCatch({
    manifest <- yaml::read_yaml(yaml_path)
    if (is.null(manifest$pulled_data)) manifest$pulled_data <- list()

    entry <- list(
      azure_path = azure_path,
      files      = as.list(basename(local_paths)),
      local_dest = local_dest,
      pulled_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )

    manifest$pulled_data <- c(manifest$pulled_data, list(entry))
    yaml::write_yaml(manifest, yaml_path)
  }, error = function(e) {
    cli::cli_warn("Could not update research.yaml: {conditionMessage(e)}")
  })
}

#### eri_research_upload_figure ####

#' Upload a figure to the research project outputs in Azure
#'
#' Uploads a local figure file to `research/{project_name}/outputs/figs/` in the
#' `data/` Azure blob and records the upload in `research.yaml`.
#'
#' @param local_path `chr` Path to the local figure file (e.g. `"figs/its_model.png"`).
#' @param caption `chr` or `NULL` Optional caption describing the figure.
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Azure path the figure was uploaded to (invisibly).
#' @examples
#' \dontrun{
#' eri_research_upload_figure("figs/its_model.png", caption = "ITS model — DR malaria 2024")
#' }
#' @export
eri_research_upload_figure <- function(
    local_path,
    caption  = NULL,
    path     = getwd(),
    data_con = NULL
) {
  if (!file.exists(local_path)) {
    cli::cli_abort("File not found: {.path {local_path}}")
  }
  manifest  <- .eri_research_read_manifest(path)
  data_con  <- .eri_research_con(data_con)
  analyst   <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  filename   <- basename(local_path)
  azure_path <- paste0(manifest$azure_path, "outputs/figs/", filename)

  dir_path <- paste0(manifest$azure_path, "outputs/figs")
  if (!AzureStor::storage_dir_exists(data_con, dir_path)) {
    AzureStor::create_storage_dir(data_con, dir_path)
  }
  AzureStor::storage_upload(data_con, local_path, azure_path)

  entry <- list(
    type        = "figure",
    filename    = filename,
    azure_path  = azure_path,
    caption     = if (is.null(caption)) NA_character_ else caption,
    uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    uploaded_by = analyst
  )
  if (is.null(manifest$outputs)) manifest$outputs <- list()
  manifest$outputs <- c(manifest$outputs, list(entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success("Figure {.file {filename}} uploaded to {.path {azure_path}}.")
  invisible(azure_path)
}

#### eri_research_upload_output ####

#' Upload an R object to the research project outputs in Azure
#'
#' Serializes an R object to a `.qs2` file and uploads it to
#' `research/{project_name}/outputs/` in the `data/` Azure blob. Records the upload
#' in `research.yaml`.
#'
#' @param obj R object to serialize and upload.
#' @param filename `chr` Name for the output file (include `.qs2` extension, e.g. `"its_model.qs2"`).
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Azure path the object was uploaded to (invisibly).
#' @examples
#' \dontrun{
#' eri_research_upload_output(model_fit, "its_model.qs2")
#' }
#' @export
eri_research_upload_output <- function(
    obj,
    filename,
    path     = getwd(),
    data_con = NULL
) {
  manifest  <- .eri_research_read_manifest(path)
  data_con  <- .eri_research_con(data_con)
  analyst   <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  tmp <- tempfile(fileext = ".qs2")
  withr::defer(unlink(tmp))
  qs2::qs_save(obj, tmp)

  azure_path <- paste0(manifest$azure_path, "outputs/", filename)
  dir_path   <- paste0(manifest$azure_path, "outputs")
  if (!AzureStor::storage_dir_exists(data_con, dir_path)) {
    AzureStor::create_storage_dir(data_con, dir_path)
  }
  AzureStor::storage_upload(data_con, tmp, azure_path)

  entry <- list(
    type        = "object",
    filename    = filename,
    azure_path  = azure_path,
    uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    uploaded_by = analyst
  )
  if (is.null(manifest$outputs)) manifest$outputs <- list()
  manifest$outputs <- c(manifest$outputs, list(entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success("Output {.file {filename}} uploaded to {.path {azure_path}}.")
  invisible(azure_path)
}

#### eri_research_snapshot ####

#' Snapshot the full research project data directory to Azure
#'
#' Uploads every file in the local `data/` directory to
#' `research/{project_name}/snapshots/{timestamp}/` in the `data/` Azure blob,
#' writes a `_manifest.yaml` alongside listing what was included, and records
#' the snapshot in `research.yaml`.
#'
#' Use this to freeze a reproducible checkpoint of all input data before a major
#' analysis run or before sharing results.
#'
#' @param label `chr` or `NULL` Optional short label for this snapshot (e.g. `"pre-ITS-run"`).
#' @param path `chr` Local project root (must contain `research.yaml` and `data/`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Azure snapshot path (invisibly).
#' @examples
#' \dontrun{
#' eri_research_snapshot(label = "pre-ITS-run")
#' }
#' @export
eri_research_snapshot <- function(label = NULL, path = getwd(), data_con = NULL) {
  manifest <- .eri_research_read_manifest(path)
  data_con <- .eri_research_con(data_con)
  analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  data_dir <- file.path(path, "data")
  if (!dir.exists(data_dir)) {
    cli::cli_abort("No {.path data/} directory found in {.path {path}}. Nothing to snapshot.")
  }

  local_files <- list.files(data_dir, recursive = TRUE, full.names = TRUE)
  if (length(local_files) == 0L) {
    cli::cli_warn("The {.path data/} directory is empty — snapshot skipped.")
    return(invisible(NULL))
  }

  timestamp    <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  snap_path    <- paste0(manifest$azure_path, "snapshots/", timestamp, "/")

  # Upload each file preserving relative path under data/
  rel_paths <- character(length(local_files))
  for (i in seq_along(local_files)) {
    rel      <- sub(paste0("^", normalizePath(data_dir, winslash = "/"), "/?"), "",
                    normalizePath(local_files[[i]], winslash = "/"))
    az_dest  <- paste0(snap_path, rel)
    AzureStor::storage_upload(data_con, local_files[[i]], az_dest)
    rel_paths[[i]] <- rel
  }

  # Write snapshot manifest to Azure
  snap_manifest <- list(
    project_name  = manifest$project_name,
    snapshot_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    created_by    = analyst,
    label         = if (is.null(label)) NA_character_ else label,
    files         = as.list(rel_paths)
  )
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(snap_manifest, tmp)
  AzureStor::storage_upload(data_con, tmp, paste0(snap_path, "_manifest.yaml"))

  # Record in research.yaml
  snap_entry <- list(
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    label      = if (is.null(label)) NA_character_ else label,
    azure_path = snap_path,
    file_count = length(local_files)
  )
  if (is.null(manifest$snapshots)) manifest$snapshots <- list()
  manifest$snapshots <- c(manifest$snapshots, list(snap_entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success(
    "Snapshot of {length(local_files)} file{?s} saved to {.path {snap_path}}."
  )
  invisible(snap_path)
}

